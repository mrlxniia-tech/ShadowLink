import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShadowLink',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black87, elevation: 0),
      ),
      home: FirebaseAuth.instance.currentUser == null ? const LoginPage() : const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- PAGE DE CONNEXION ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true; // Pour cacher/afficher le mdp

  Future<void> seConnecter() async {
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) return;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.message}"), backgroundColor: Colors.red));
    }
  }

  // NOUVEAU : Fonction Mot de passe oublié (Sécurisé par Firebase)
  Future<void> motDePasseOublie() async {
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tape ton adresse Email en haut puis clique ici."), backgroundColor: Colors.orange));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✉️ Email de réinitialisation envoyé ! Vérifie tes spams."), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur : Email introuvable ou invalide."), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: const NetworkImage('https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=2070&auto=format&fit=crop'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.darken)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videogame_asset, size: 80, color: Colors.cyanAccent),
              const SizedBox(height: 10),
              const Text("SHADOWLINK", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)),
              const SizedBox(height: 30),
              TextField(controller: emailController, decoration: InputDecoration(labelText: 'Email', filled: true, fillColor: Colors.black54, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              
              // NOUVEAU : Champ Mot de passe avec l'œil
              TextField(
                controller: passwordController, 
                obscureText: _obscurePassword, 
                decoration: InputDecoration(
                  labelText: 'Mot de passe', 
                  filled: true, 
                  fillColor: Colors.black54, 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.cyanAccent),
                    onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); },
                  )
                )
              ),
              
              const SizedBox(height: 10),
              // NOUVEAU : Bouton Mot de Passe Oublié
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: motDePasseOublie, child: const Text("Mot de passe oublié ?", style: TextStyle(color: Colors.grey))),
              ),

              const SizedBox(height: 10),
              ElevatedButton(onPressed: seConnecter, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text('CONNEXION', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 2))),
              TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())), child: const Text("Créer un profil Gamer", style: TextStyle(color: Colors.cyanAccent))),
            ],
          ),
        ),
      ),
    );
  }
}

// --- PAGE D'INSCRIPTION ---
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController pseudoGeneralController = TextEditingController();
  final List<String> listeJeux = ["Call of Duty", "Minecraft", "Roblox", "Fortnite", "Clash Royale", "Ea FC", "Valorant"];
  final Map<String, bool> jeuxCoches = {};
  final Map<String, TextEditingController> pseudosJeux = {};
  bool isChargement = false;
  bool _obscurePassword = true; // Pour l'inscription aussi !

  @override
  void initState() {
    super.initState();
    for (var jeu in listeJeux) { jeuxCoches[jeu] = false; pseudosJeux[jeu] = TextEditingController(); }
  }

  Future<void> creerCompte() async {
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty || pseudoGeneralController.text.trim().isEmpty) return;
    setState(() => isChargement = true);
    try {
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      Map<String, String> tousMesPseudos = {"Général": pseudoGeneralController.text.trim()};
      for (var jeu in listeJeux) { if (jeuxCoches[jeu] == true && pseudosJeux[jeu]!.text.trim().isNotEmpty) { tousMesPseudos[jeu] = pseudosJeux[jeu]!.text.trim(); } }
      await FirebaseFirestore.instance.collection('utilisateurs').doc(userCred.user!.uid).set({'email': emailController.text.trim(), 'pseudos': tousMesPseudos, 'amis': [], 'dateCreation': FieldValue.serverTimestamp()});
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainScreen()), (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur de création"), backgroundColor: Colors.red));
    } finally { setState(() => isChargement = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Créer ton Profil", style: TextStyle(color: Colors.cyanAccent))),
      body: isChargement ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)) : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController, 
              obscureText: _obscurePassword, 
              decoration: InputDecoration(
                labelText: 'Mot de passe', 
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.cyanAccent), onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); })
              )
            ),
            const SizedBox(height: 10),
            TextField(controller: pseudoGeneralController, decoration: const InputDecoration(labelText: 'Pseudo Principal', border: OutlineInputBorder())),
            const SizedBox(height: 30),
            ...listeJeux.map((jeu) => Column(
              children: [
                CheckboxListTile(title: Text(jeu), activeColor: Colors.cyanAccent, value: jeuxCoches[jeu], onChanged: (bool? val) => setState(() => jeuxCoches[jeu] = val ?? false)),
                if (jeuxCoches[jeu] == true) Padding(padding: const EdgeInsets.only(left: 40.0, right: 16.0, bottom: 10.0), child: TextField(controller: pseudosJeux[jeu], decoration: InputDecoration(labelText: 'Pseudo sur $jeu', border: const OutlineInputBorder())))
              ],
            )).toList(),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: creerCompte, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, minimumSize: const Size(double.infinity, 50)), child: const Text('VALIDER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}

// --- ECRAN PRINCIPAL ---
class MainScreen extends StatefulWidget {
  final String salonInitial;
  const MainScreen({super.key, this.salonInitial = "Général"});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late String salonActuel;
  final List<String> tousLesSalons = ["Général", "Call of Duty", "Minecraft", "Roblox", "Fortnite", "Clash Royale", "Ea FC", "Valorant"];
  
  final Map<String, String> imagesJeux = {
    "Général": "https://images.unsplash.com/photo-1552820728-8b83bb6b773f?q=80&w=200&auto=format&fit=crop",
    "Call of Duty": "https://images.unsplash.com/photo-1605901309584-818e25960b8f?q=80&w=200&auto=format&fit=crop",
    "Minecraft": "https://images.unsplash.com/photo-1607513746994-51f730a44832?q=80&w=200&auto=format&fit=crop",
    "Roblox": "https://images.unsplash.com/photo-1610041321420-a596dd14ebc9?q=80&w=200&auto=format&fit=crop",
    "Fortnite": "https://images.unsplash.com/photo-1589241062272-c0a000072dfa?q=80&w=200&auto=format&fit=crop",
    "Clash Royale": "https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=200&auto=format&fit=crop",
    "Ea FC": "https://images.unsplash.com/photo-1508344928928-7165b67de128?q=80&w=200&auto=format&fit=crop",
    "Valorant": "https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=200&auto=format&fit=crop",
  };

  // NOUVEAU : Dictionnaire des Fonds d'écran dynamiques !!
  final Map<String, String> fondsEcrans = {
    "Général": "https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1080&auto=format&fit=crop",
    "Call of Duty": "https://images.unsplash.com/photo-1605901309584-818e25960b8f?q=80&w=1080&auto=format&fit=crop", // Militaire
    "Minecraft": "https://images.unsplash.com/photo-1607513746994-51f730a44832?q=80&w=1080&auto=format&fit=crop", // Cubes
    "Roblox": "https://images.unsplash.com/photo-1610041321420-a596dd14ebc9?q=80&w=1080&auto=format&fit=crop", // Jouets
    "Fortnite": "https://images.unsplash.com/photo-1589241062272-c0a000072dfa?q=80&w=1080&auto=format&fit=crop", // Couleurs vives
    "Clash Royale": "https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=1080&auto=format&fit=crop", 
    "Ea FC": "https://images.unsplash.com/photo-1508344928928-7165b67de128?q=80&w=1080&auto=format&fit=crop", // Stade de foot
    "Valorant": "https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=1080&auto=format&fit=crop", // Néon et armes
  };

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _texteEcoute = "";
  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    salonActuel = widget.salonInitial;
    if (!tousLesSalons.contains(salonActuel) && !salonActuel.startsWith("Privé")) tousLesSalons.add(salonActuel);
    _speech = stt.SpeechToText();
  }

  void _ecouterAssistant() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) return;
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: 'fr_FR',
          onResult: (val) {
            setState(() => _texteEcoute = val.recognizedWords.toLowerCase());
            if (_texteEcoute.contains("fin") || _texteEcoute.contains("mute")) {
              _speech.stop(); setState(() => _isListening = false); return;
            }
            if (_texteEcoute.contains("shadow fait une conversation privée avec")) {
              List<String> mots = _texteEcoute.split("avec");
              if (mots.length > 1) {
                String pseudoJoueur = mots.last.trim();
                _speech.stop(); setState(() => _isListening = false);
                setState(() { salonActuel = "Privé : $pseudoJoueur"; if (!tousLesSalons.contains(salonActuel)) tousLesSalons.add(salonActuel); });
              }
            }
          },
        );
      }
    } else { setState(() => _isListening = false); _speech.stop(); }
  }

  @override
  Widget build(BuildContext context) {
    // Si c'est un salon privé, on utilise le fond du "Général" par défaut.
    String fondEgal = fondsEcrans[salonActuel] ?? fondsEcrans["Général"]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(salonActuel.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.cyanAccent)),
        centerTitle: true,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).collection('notifications').where('lu', isEqualTo: false).snapshots(),
            builder: (context, snapshot) {
              int notifCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return IconButton(
                icon: Badge(isLabelVisible: notifCount > 0, label: Text(notifCount.toString()), child: const Icon(Icons.notifications, color: Colors.white)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage())),
              );
            },
          )
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1A1A24),
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(image: DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=2071&auto=format&fit=crop'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken))),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircleAvatar(radius: 20, backgroundImage: NetworkImage('https://i.ibb.co/tP5c32d/logo.png'), backgroundColor: Colors.transparent),
                    SizedBox(width: 15),
                    Text('SHADOWLINK', style: TextStyle(color: Colors.cyanAccent, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3)),
                  ],
                ),
              ),
            ),
            ListTile(leading: const Icon(Icons.group, color: Colors.cyanAccent), title: const Text("👥 Mes Amis", style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsPage())); }),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: tousLesSalons.map((jeu) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: jeu == salonActuel ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent, border: Border.all(color: jeu == salonActuel ? Colors.cyanAccent : Colors.transparent), borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: jeu.startsWith("Privé") ? const CircleAvatar(backgroundColor: Colors.deepPurple, child: Icon(Icons.lock, color: Colors.white, size: 18)) : CircleAvatar(backgroundImage: NetworkImage(imagesJeux[jeu] ?? imagesJeux["Général"]!), radius: 18),
                    title: Text(jeu, style: TextStyle(fontWeight: jeu == salonActuel ? FontWeight.bold : FontWeight.normal, color: jeu == salonActuel ? Colors.cyanAccent : Colors.white70)),
                    onTap: () { setState(() => salonActuel = jeu); Navigator.pop(context); }
                  ),
                )).toList()
              )
            ),
            // CORRECTION DU BUG DE LA BARRE ANDROID : On protège le bouton paramètres !
            SafeArea(
              top: false,
              bottom: true,
              child: ListTile(leading: const Icon(Icons.settings, color: Colors.grey), title: const Text("Paramètres"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ParametresPage()))),
            )
          ],
        ),
      ),
      // NOUVEAU : LE FOND D'ECRAN EST DYNAMIQUE SELON LE JEU !
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(fondEgal),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.85), BlendMode.darken),
          ),
        ),
        child: ChatWidget(nomDuJeu: salonActuel),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _ecouterAssistant, backgroundColor: _isListening ? Colors.redAccent : Colors.cyanAccent, elevation: 10, child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.black)),
    );
  }
}

// --- WIDGET CHAT ---
class ChatWidget extends StatefulWidget { final String nomDuJeu; const ChatWidget({super.key, required this.nomDuJeu}); @override State<ChatWidget> createState() => _ChatWidgetState(); }
class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController messageController = TextEditingController();
  Future<void> envoyerMessage() async {
    String texte = messageController.text.trim(); if (texte.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser; if (user == null) return;
    String monPseudoActuel = "Joueur";
    try {
      final docUtilisateur = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
      if (docUtilisateur.exists) { monPseudoActuel = docUtilisateur.data()!['pseudos']?[widget.nomDuJeu] ?? docUtilisateur.data()!['pseudos']?['Général'] ?? "Joueur"; }
    } catch (e) { }
    await FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').add({'texte': texte, 'expediteur': monPseudoActuel, 'email': user.email, 'timestamp': FieldValue.serverTimestamp()});
    messageController.clear();
  }
  @override Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
              return ListView.builder(
                reverse: true, itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final msg = snapshot.data!.docs[index].data() as Map<String, dynamic>; final bool isMe = msg['email'] == user?.email;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: isMe ? Colors.cyanAccent.withOpacity(0.2) : Colors.white10, border: Border.all(color: isMe ? Colors.cyanAccent.withOpacity(0.5) : Colors.transparent), borderRadius: BorderRadius.circular(15)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (!isMe) Text(msg['expediteur'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent, fontSize: 12)),
                        Text(msg['texte'] ?? "", style: const TextStyle(fontSize: 16, color: Colors.white)),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [ Expanded(child: TextField(controller: messageController, decoration: InputDecoration(hintText: "Message...", filled: true, fillColor: Colors.black54, border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)))), const SizedBox(width: 8), CircleAvatar(backgroundColor: Colors.cyanAccent, child: IconButton(icon: const Icon(Icons.send, color: Colors.black), onPressed: envoyerMessage)) ])))
      ],
    );
  }
}

class NotificationsPage extends StatelessWidget { const NotificationsPage({super.key}); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Notifications")), body: const Center(child: Text("Notifications (Code inchangé)"))); } }
class FriendsPage extends StatefulWidget { const FriendsPage({super.key}); @override State<FriendsPage> createState() => _FriendsPageState(); }
class _FriendsPageState extends State<FriendsPage> { @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Mes Amis")), body: const Center(child: Text("Amis (Code inchangé)"))); } }

// --- PARAMÈTRES (AVEC SUPPORT & ADMIN) ---
class ParametresPage extends StatelessWidget {
  const ParametresPage({super.key});
  Future<void> contacterSupport() async {
    final Uri emailLaunchUri = Uri(scheme: 'mailto', path: 'support@shadowlink.com', queryParameters: {'subject': 'Rapport de Bug / Demande d\'aide'});
    if (!await launchUrl(emailLaunchUri)) {}
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres', style: TextStyle(color: Colors.cyanAccent))),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(16.0), child: Text("AIDE ET MODÉRATION", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ListTile(leading: const Icon(Icons.bug_report, color: Colors.greenAccent), title: const Text('Signaler un bug / Support technique'), onTap: contacterSupport),
          ListTile(leading: const Icon(Icons.admin_panel_settings, color: Colors.amberAccent), title: const Text('Contacter un Admin'), subtitle: const Text('Signaler un comportement'), onTap: () { Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainScreen(salonInitial: "Privé : Admin")), (route) => false); }),
          const Divider(color: Colors.white24),
          const Padding(padding: EdgeInsets.all(16.0), child: Text("APPLICATION", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ListTile(leading: const Icon(Icons.system_update, color: Colors.blueAccent), title: const Text('Mise à jour (Nouvel APK)'), onTap: () async { final Uri url = Uri.parse('https://github.com/mrlxniia-tech/ShadowLink/actions'); launchUrl(url, mode: LaunchMode.externalApplication); }),
          const Divider(color: Colors.white24),
          ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent), title: const Text('Se déconnecter', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)), onTap: () async { await FirebaseAuth.instance.signOut(); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false); }),
        ],
      ),
    );
  }
}
