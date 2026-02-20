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
  bool _obscurePassword = true;

  Future<void> seConnecter() async {
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) return;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.message}"), backgroundColor: Colors.red));
    }
  }

  Future<void> motDePasseOublie() async {
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tape ton Email puis clique ici."), backgroundColor: Colors.orange));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email envoyé !"), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur email."), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(image: DecorationImage(image: const NetworkImage('https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=2070'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken))),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videogame_asset, size: 80, color: Colors.cyanAccent),
              const SizedBox(height: 10),
              const Text("SHADOWLINK", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)),
              const SizedBox(height: 30),
              TextField(controller: emailController, decoration: InputDecoration(labelText: 'Email', filled: true, fillColor: Colors.black54, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
              const SizedBox(height: 16),
              TextField(controller: passwordController, obscureText: _obscurePassword, decoration: InputDecoration(labelText: 'Mot de passe', filled: true, fillColor: Colors.black54, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.cyanAccent), onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); }))),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: motDePasseOublie, child: const Text("Mot de passe oublié ?", style: TextStyle(color: Colors.grey)))),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: seConnecter, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text('CONNEXION', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
              TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())), child: const Text("Créer un profil", style: TextStyle(color: Colors.cyanAccent))),
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
  bool _obscurePassword = true;

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
      for (var jeu in listeJeux) { if (jeuxCoches[jeu] == true && pseudosJeux[jeu]!.text.trim().isNotEmpty) tousMesPseudos[jeu] = pseudosJeux[jeu]!.text.trim(); }
      await FirebaseFirestore.instance.collection('utilisateurs').doc(userCred.user!.uid).set({'email': emailController.text.trim(), 'pseudos': tousMesPseudos, 'amis': [], 'discord': '', 'dateCreation': FieldValue.serverTimestamp()});
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainScreen()), (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur"), backgroundColor: Colors.red));
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
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: passwordController, obscureText: _obscurePassword, decoration: InputDecoration(labelText: 'Mot de passe', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.cyanAccent), onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); }))),
            const SizedBox(height: 10),
            TextField(controller: pseudoGeneralController, decoration: const InputDecoration(labelText: 'Pseudo Principal', border: OutlineInputBorder())),
            const SizedBox(height: 30),
            ...listeJeux.map((jeu) => Column(children: [CheckboxListTile(title: Text(jeu), activeColor: Colors.cyanAccent, value: jeuxCoches[jeu], onChanged: (bool? val) => setState(() => jeuxCoches[jeu] = val ?? false)), if (jeuxCoches[jeu] == true) Padding(padding: const EdgeInsets.only(left: 40.0, right: 16.0, bottom: 10.0), child: TextField(controller: pseudosJeux[jeu], decoration: InputDecoration(labelText: 'Pseudo sur $jeu', border: const OutlineInputBorder())))]).toList()),
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
  
  final Map<String, String> fondsEcrans = {
    "Général": "https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1080",
    "Call of Duty": "https://images.unsplash.com/photo-1506469717960-433cebe3f181?q=80&w=1080", // Soldat / Militaire plus clair
    "Minecraft": "https://images.unsplash.com/photo-1607513746994-51f730a44832?q=80&w=1080", 
    "Roblox": "https://images.unsplash.com/photo-1610041321420-a596dd14ebc9?q=80&w=1080", 
    "Fortnite": "https://images.unsplash.com/photo-1589241062272-c0a000072dfa?q=80&w=1080", 
    "Clash Royale": "https://images.unsplash.com/photo-1628260412297-a3377e45006f?q=80&w=1080", 
    "Ea FC": "https://images.unsplash.com/photo-1508344928928-7165b67de128?q=80&w=1080", 
    "Valorant": "https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=1080", 
  };

  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    salonActuel = widget.salonInitial;
    if (!tousLesSalons.contains(salonActuel) && !salonActuel.startsWith("Privé")) tousLesSalons.add(salonActuel);
  }

  void _afficherRegles() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("📜 Règles du Serveur", style: TextStyle(color: Colors.cyanAccent)),
      content: const Text("Bienvenue sur ShadowLink !\n\n1. Respectez les autres joueurs.\n2. Pas de triche ni de liens frauduleux.\n3. Utilisez la commande 'Admin' en cas de problème.\n\nAmusez-vous bien !"),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Compris !"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
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
            const DrawerHeader(
              decoration: BoxDecoration(image: DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=2071'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken))),
              child: Center(child: Text('SHADOWLINK', style: TextStyle(color: Colors.cyanAccent, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 3))),
            ),
            ListTile(leading: const Icon(Icons.group, color: Colors.cyanAccent), title: const Text("👥 Mes Amis", style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsPage())); }),
            ListTile(leading: const Icon(Icons.rule, color: Colors.amberAccent), title: const Text("📜 Règles de l'App", style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); _afficherRegles(); }),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: tousLesSalons.map((jeu) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: jeu == salonActuel ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent, border: Border.all(color: jeu == salonActuel ? Colors.cyanAccent : Colors.transparent), borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: Icon(jeu.startsWith("Privé") ? Icons.lock : Icons.tag, color: jeu == salonActuel ? Colors.cyanAccent : Colors.grey),
                    title: Text(jeu, style: TextStyle(fontWeight: jeu == salonActuel ? FontWeight.bold : FontWeight.normal, color: jeu == salonActuel ? Colors.cyanAccent : Colors.white70)),
                    onTap: () { setState(() => salonActuel = jeu); Navigator.pop(context); }
                  ),
                )).toList()
              )
            ),
            SafeArea(top: false, bottom: true, child: ListTile(leading: const Icon(Icons.settings, color: Colors.grey), title: const Text("Profil & Paramètres"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ParametresPage()))))
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(fondEgal),
            fit: BoxFit.cover,
            // OPACITÉ RÉDUITE POUR MIEUX VOIR L'IMAGE !
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
          ),
        ),
        // On passe une fonction au ChatWidget pour qu'il puisse changer le salon si la commande vocale le demande
        child: ChatWidget(nomDuJeu: salonActuel, onChangeSalon: (nouveauSalon) {
          setState(() { salonActuel = nouveauSalon; if (!tousLesSalons.contains(salonActuel)) tousLesSalons.add(salonActuel); });
        }),
      ),
    );
  }
}

// --- WIDGET CHAT (AVEC MICROPHONE INTÉGRÉ ET SUPPRESSION) ---
class ChatWidget extends StatefulWidget { 
  final String nomDuJeu; 
  final Function(String) onChangeSalon;
  const ChatWidget({super.key, required this.nomDuJeu, required this.onChangeSalon}); 
  @override State<ChatWidget> createState() => _ChatWidgetState(); 
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController messageController = TextEditingController();
  
  // Assistant Vocal
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _ecouterAssistant() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Micro refusé"))); return; }
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: 'fr_FR',
          onResult: (val) {
            String texteEcoute = val.recognizedWords.toLowerCase();
            if (texteEcoute.contains("fin") || texteEcoute.contains("mute")) {
              _speech.stop(); setState(() => _isListening = false); return;
            }
            if (texteEcoute.contains("shadow fait une conversation privée avec")) {
              List<String> mots = texteEcoute.split("avec");
              if (mots.length > 1) {
                String pseudoJoueur = mots.last.trim();
                _speech.stop(); setState(() => _isListening = false);
                widget.onChangeSalon("Privé : $pseudoJoueur"); // Téléportation magique
              }
            }
          },
        );
      }
    } else { setState(() => _isListening = false); _speech.stop(); }
  }

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

  // NOUVEAU: SUPPRESSION DE SES PROPRES MESSAGES (Façon Discord)
  void confirmerSuppression(String messageId) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Supprimer le message ?"),
      content: const Text("Es-tu sûr de vouloir effacer ce message ?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
        TextButton(onPressed: () async {
          await FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').doc(messageId).delete();
          Navigator.pop(context);
        }, child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
      ],
    ));
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
                  final msgDoc = snapshot.data!.docs[index];
                  final msg = msgDoc.data() as Map<String, dynamic>; 
                  final bool isMe = msg['email'] == user?.email;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: GestureDetector(
                      onLongPress: isMe ? () => confirmerSuppression(msgDoc.id) : null, // CLIC LONG POUR SUPPRIMER
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: isMe ? Colors.cyanAccent.withOpacity(0.2) : Colors.black87, border: Border.all(color: isMe ? Colors.cyanAccent.withOpacity(0.5) : Colors.transparent), borderRadius: BorderRadius.circular(15)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (!isMe) Text(msg['expediteur'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent, fontSize: 12)),
                          Text(msg['texte'] ?? "", style: const TextStyle(fontSize: 16, color: Colors.white)),
                        ]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false, 
          child: Padding(
            padding: const EdgeInsets.all(8.0), 
            child: Row(
              children: [ 
                Expanded(child: TextField(controller: messageController, decoration: InputDecoration(hintText: "Message...", filled: true, fillColor: Colors.black87, border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)))), 
                const SizedBox(width: 8), 
                // BOUTON MICROPHONE REPOSITIONNÉ ICI !
                CircleAvatar(backgroundColor: _isListening ? Colors.redAccent : Colors.black54, child: IconButton(icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white), onPressed: _ecouterAssistant)),
                const SizedBox(width: 8), 
                CircleAvatar(backgroundColor: Colors.cyanAccent, child: IconButton(icon: const Icon(Icons.send, color: Colors.black), onPressed: envoyerMessage)) 
              ]
            )
          )
        )
      ],
    );
  }
}

// --- PAGE DES AMIS (TOTALEMENT RESTAURÉE) ---
class FriendsPage extends StatefulWidget { const FriendsPage({super.key}); @override State<FriendsPage> createState() => _FriendsPageState(); }
class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController searchController = TextEditingController();
  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> envoyerDemandeAmi() async {
    String search = searchController.text.trim(); if (search.isEmpty) return;
    var query = await FirebaseFirestore.instance.collection('utilisateurs').where('pseudos.Général', isEqualTo: search).get();
    if (query.docs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joueur introuvable !"), backgroundColor: Colors.red)); } 
    else {
      String targetUid = query.docs.first.id;
      if (targetUid == myUid) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tu ne peux pas t'ajouter toi-même !"), backgroundColor: Colors.orange)); return; }
      var myDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).get();
      String monPseudo = myDoc.data()?['pseudos']?['Général'] ?? 'Joueur';
      await FirebaseFirestore.instance.collection('utilisateurs').doc(targetUid).collection('notifications').add({'type': 'ami', 'de': monPseudo, 'uidExpediteur': myUid, 'lu': false, 'timestamp': FieldValue.serverTimestamp()});
      searchController.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Demande envoyée à $search ! 🚀"), backgroundColor: Colors.green));
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mes Amis")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(children: [ Expanded(child: TextField(controller: searchController, decoration: const InputDecoration(hintText: "Ajouter un pseudo...", border: OutlineInputBorder()))), const SizedBox(width: 8), ElevatedButton(onPressed: envoyerDemandeAmi, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, padding: const EdgeInsets.symmetric(vertical: 15)), child: const Text("Ajouter", style: TextStyle(color: Colors.black)))]),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var data = snapshot.data!.data() as Map<String, dynamic>?;
                List<dynamic> mesAmis = data?['amis'] ?? [];
                if (mesAmis.isEmpty) return const Center(child: Text("Tu n'as pas encore d'amis. Cherche en haut !"));
                return ListView.builder(
                  itemCount: mesAmis.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.cyanAccent, child: Icon(Icons.person, color: Colors.black)),
                      title: Text(mesAmis[index], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text("🟢 En ligne", style: TextStyle(color: Colors.greenAccent, fontSize: 12)), // DISCORD STYLE
                      trailing: const Icon(Icons.chat_bubble, color: Colors.grey),
                      onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => MainScreen(salonInitial: "Privé : ${mesAmis[index]}")), (route) => false),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- PAGE DES NOTIFICATIONS (TOTALEMENT RESTAURÉE) ---
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  Future<void> accepterAmi(String myUid, String notifId, String uidDemandeur, String pseudoDemandeur) async {
    await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'amis': FieldValue.arrayUnion([pseudoDemandeur])});
    var myDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).get();
    String monPseudo = myDoc.data()?['pseudos']?['Général'] ?? 'Joueur';
    await FirebaseFirestore.instance.collection('utilisateurs').doc(uidDemandeur).update({'amis': FieldValue.arrayUnion([monPseudo])});
    await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).collection('notifications').doc(notifId).delete();
  }
  Future<void> refuserAmi(String myUid, String notifId) async { await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).collection('notifications').doc(notifId).delete(); }

  @override Widget build(BuildContext context) {
    final String myUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).collection('notifications').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final notifs = snapshot.data!.docs;
          if (notifs.isEmpty) return const Center(child: Text("Aucune notification."));
          return ListView.builder(
            itemCount: notifs.length,
            itemBuilder: (context, index) {
              var notif = notifs[index].data() as Map<String, dynamic>; String notifId = notifs[index].id;
              if (notif['type'] == 'ami') {
                return Card(child: ListTile(leading: const Icon(Icons.person_add, color: Colors.cyanAccent), title: Text("Demande d'ami de ${notif['de']}"), subtitle: Row(children: [TextButton(onPressed: () => accepterAmi(myUid, notifId, notif['uidExpediteur'], notif['de']), child: const Text("Accepter", style: TextStyle(color: Colors.green))), TextButton(onPressed: () => refuserAmi(myUid, notifId), child: const Text("Refuser", style: TextStyle(color: Colors.red)))])));
              }
              return const SizedBox();
            },
          );
        },
      ),
    );
  }
}

// --- PARAMÈTRES (AVEC LE PROFIL) ---
class ParametresPage extends StatefulWidget { const ParametresPage({super.key}); @override State<ParametresPage> createState() => _ParametresPageState(); }
class _ParametresPageState extends State<ParametresPage> {
  final TextEditingController discordController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  Future<void> sauvegarderDiscord() async {
    if (user != null) {
      await FirebaseFirestore.instance.collection('utilisateurs').doc(user!.uid).update({'discord': discordController.text.trim()});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lien Discord mis à jour ! ✅"), backgroundColor: Colors.green));
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil & Paramètres', style: TextStyle(color: Colors.cyanAccent))),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('utilisateurs').doc(user!.uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var data = snapshot.data!.data() as Map<String, dynamic>?;
          String pseudo = data?['pseudos']?['Général'] ?? "Joueur";
          String email = data?['email'] ?? "Email inconnu";
          if (discordController.text.isEmpty) discordController.text = data?['discord'] ?? "";

          return ListView(
            children: [
              // NOUVEAU: SECTION PROFIL
              Container(
                color: Colors.black26, padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const CircleAvatar(radius: 40, backgroundColor: Colors.cyanAccent, child: Icon(Icons.person, size: 50, color: Colors.black)),
                    const SizedBox(height: 10),
                    Text(pseudo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(email, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    TextField(controller: discordController, decoration: InputDecoration(labelText: 'Lien/Pseudo Discord', prefixIcon: const Icon(Icons.discord), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), suffixIcon: IconButton(icon: const Icon(Icons.save, color: Colors.cyanAccent), onPressed: sauvegarderDiscord))),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              const Padding(padding: EdgeInsets.all(16.0), child: Text("SUPPORT", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
              ListTile(leading: const Icon(Icons.admin_panel_settings, color: Colors.amberAccent), title: const Text('Contacter un Admin'), onTap: () { Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainScreen(salonInitial: "Privé : Admin")), (route) => false); }),
              const Divider(color: Colors.white24),
              ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent), title: const Text('Se déconnecter', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)), onTap: () async { await FirebaseAuth.instance.signOut(); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false); }),
            ],
          );
        }
      ),
    );
  }
}
