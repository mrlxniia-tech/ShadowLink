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
      theme: ThemeData(primarySwatch: Colors.deepPurple, brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0D0D12), appBarTheme: const AppBarTheme(backgroundColor: Colors.black87, elevation: 0)),
      home: FirebaseAuth.instance.currentUser == null ? const LoginPage() : const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- PAGE DE CONNEXION ---
class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState() => _LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;

  Future<void> seConnecter() async {
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) return;
    try {
      UserCredential userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(userCred.user!.uid).get();
      if (doc.data()?['banni'] == true) {
        await FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Ton compte a été restreint par un Administrateur."), backgroundColor: Colors.red));
        return;
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.message}"), backgroundColor: Colors.red));
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(image: DecorationImage(image: const NetworkImage('https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=2070'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken))),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videogame_asset, size: 80, color: Colors.cyanAccent), const SizedBox(height: 10),
              const Text("SHADOWLINK", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)), const SizedBox(height: 30),
              TextField(controller: emailController, decoration: InputDecoration(labelText: 'Email', filled: true, fillColor: Colors.black54, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))), const SizedBox(height: 16),
              TextField(controller: passwordController, obscureText: _obscurePassword, decoration: InputDecoration(labelText: 'Mot de passe', filled: true, fillColor: Colors.black54, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.cyanAccent), onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); }))),
              const SizedBox(height: 20),
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
class RegisterPage extends StatefulWidget { const RegisterPage({super.key}); @override State<RegisterPage> createState() => _RegisterPageState(); }
class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController pseudoGeneralController = TextEditingController();
  final List<String> listeJeux = ["Call of Duty", "Minecraft", "Roblox", "Fortnite", "Clash Royale", "Ea FC", "Valorant"];
  final Map<String, bool> jeuxCoches = {}; final Map<String, TextEditingController> pseudosJeux = {};
  bool isChargement = false; bool _obscurePassword = true;

  @override void initState() { super.initState(); for (var jeu in listeJeux) { jeuxCoches[jeu] = false; pseudosJeux[jeu] = TextEditingController(); } }

  Future<void> creerCompte() async {
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty || pseudoGeneralController.text.trim().isEmpty) return;
    setState(() => isChargement = true);
    try {
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      Map<String, String> tousMesPseudos = {"Général": pseudoGeneralController.text.trim()};
      for (var jeu in listeJeux) { if (jeuxCoches[jeu] == true && pseudosJeux[jeu]!.text.trim().isNotEmpty) tousMesPseudos[jeu] = pseudosJeux[jeu]!.text.trim(); }
      
      await FirebaseFirestore.instance.collection('utilisateurs').doc(userCred.user!.uid).set({
        'email': emailController.text.trim(),
        'pseudos': tousMesPseudos,
        'amis': [],
        'discord': '',
        'avatar': '', 
        'role': 'user', 
        'banni': false,
        'dateCreation': FieldValue.serverTimestamp()
      });
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainScreen()), (route) => false);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur"), backgroundColor: Colors.red)); } 
    finally { setState(() => isChargement = false); }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Créer ton Profil", style: TextStyle(color: Colors.cyanAccent))),
      body: isChargement ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)) : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())), const SizedBox(height: 10),
            TextField(controller: passwordController, obscureText: _obscurePassword, decoration: InputDecoration(labelText: 'Mot de passe', border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.cyanAccent), onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); }))), const SizedBox(height: 10),
            TextField(controller: pseudoGeneralController, decoration: const InputDecoration(labelText: 'Pseudo Principal', border: OutlineInputBorder())), const SizedBox(height: 30),
            
            // LA CORRECTION DU BUG DE PARENTHÈSE EST ICI ! On aère le code.
            ...listeJeux.map((jeu) {
              return Column(
                children: [
                  CheckboxListTile(
                    title: Text(jeu), 
                    activeColor: Colors.cyanAccent, 
                    value: jeuxCoches[jeu], 
                    onChanged: (bool? val) => setState(() => jeuxCoches[jeu] = val ?? false)
                  ),
                  if (jeuxCoches[jeu] == true) 
                    Padding(
                      padding: const EdgeInsets.only(left: 40.0, right: 16.0, bottom: 10.0), 
                      child: TextField(
                        controller: pseudosJeux[jeu], 
                        decoration: InputDecoration(labelText: 'Pseudo sur $jeu', border: const OutlineInputBorder())
                      )
                    )
                ]
              );
            }).toList(), // Le .toList() avec sa parenthèse propre !
            
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
  final String salonInitial; const MainScreen({super.key, this.salonInitial = "Général"});
  @override State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late String salonActuel;
  final List<String> tousLesSalons = ["Général", "Call of Duty", "Minecraft", "Roblox", "Fortnite", "Clash Royale", "Ea FC", "Valorant"];
  String myRole = 'user'; 
  
  final Map<String, String> fondsEcrans = {
    "Général": "https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1080",
    "Call of Duty": "https://images.igdb.com/igdb/image/upload/t_1080p/co2v04.jpg", 
    "Minecraft": "https://images.igdb.com/igdb/image/upload/t_1080p/co49x5.jpg", 
    "Roblox": "https://images.igdb.com/igdb/image/upload/t_1080p/co1t2a.jpg", 
    "Fortnite": "https://images.igdb.com/igdb/image/upload/t_1080p/co2ve0.jpg", 
    "Clash Royale": "https://images.igdb.com/igdb/image/upload/t_1080p/co21z9.jpg", 
    "Ea FC": "https://images.igdb.com/igdb/image/upload/t_1080p/co6i9n.jpg", 
    "Valorant": "https://images.igdb.com/igdb/image/upload/t_1080p/co2mvt.jpg", 
  };

  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  @override void initState() {
    super.initState();
    salonActuel = widget.salonInitial;
    if (!tousLesSalons.contains(salonActuel) && !salonActuel.startsWith("Privé")) tousLesSalons.add(salonActuel);
    _chargerRole();
  }

  Future<void> _chargerRole() async {
    var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).get();
    if (doc.exists) setState(() => myRole = doc.data()?['role'] ?? 'user');
  }

  @override Widget build(BuildContext context) {
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
              return IconButton(icon: Badge(isLabelVisible: notifCount > 0, label: Text(notifCount.toString()), child: const Icon(Icons.notifications, color: Colors.white)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage())));
            },
          )
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1A1A24),
        child: Column(
          children: [
            const DrawerHeader(decoration: BoxDecoration(image: DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=2071'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken))), child: Center(child: Text('SHADOWLINK', style: TextStyle(color: Colors.cyanAccent, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 3)))),
            ListTile(leading: const Icon(Icons.group, color: Colors.cyanAccent), title: const Text("👥 Mes Amis", style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsPage())); }),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: tousLesSalons.map((jeu) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: jeu == salonActuel ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent, border: Border.all(color: jeu == salonActuel ? Colors.cyanAccent : Colors.transparent), borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: jeu.startsWith("Privé") ? const CircleAvatar(backgroundColor: Colors.deepPurple, child: Icon(Icons.lock, color: Colors.white, size: 18)) : CircleAvatar(backgroundImage: NetworkImage(fondsEcrans[jeu] ?? fondsEcrans["Général"]!), radius: 18),
                    title: Text(jeu, style: TextStyle(fontWeight: jeu == salonActuel ? FontWeight.bold : FontWeight.normal, color: jeu == salonActuel ? Colors.cyanAccent : Colors.white70)),
                    onTap: () { setState(() => salonActuel = jeu); Navigator.pop(context); }
                  ),
                )).toList()
              )
            ),
            SafeArea(top: false, bottom: true, child: ListTile(leading: const Icon(Icons.settings, color: Colors.grey), title: const Text("Profil & Paramètres"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ParametresPage(monRole: myRole)))))
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(fondEgal), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken))),
        child: ChatWidget(nomDuJeu: salonActuel, onChangeSalon: (nouveauSalon) { setState(() { salonActuel = nouveauSalon; if (!tousLesSalons.contains(salonActuel)) tousLesSalons.add(salonActuel); }); }),
      ),
    );
  }
}

// --- WIDGET CHAT ---
class ChatWidget extends StatefulWidget { 
  final String nomDuJeu; final Function(String) onChangeSalon;
  const ChatWidget({super.key, required this.nomDuJeu, required this.onChangeSalon}); 
  @override State<ChatWidget> createState() => _ChatWidgetState(); 
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController messageController = TextEditingController();
  late stt.SpeechToText _speech; bool _isListening = false;
  String myAvatarUrl = '';

  @override void initState() {
    super.initState(); _speech = stt.SpeechToText(); _chargerMonAvatar();
  }

  Future<void> _chargerMonAvatar() async {
    final user = FirebaseAuth.instance.currentUser; if (user == null) return;
    var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
    if (doc.exists) setState(() => myAvatarUrl = doc.data()?['avatar'] ?? '');
  }

  void _ecouterAssistant() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status.isPermanentlyDenied) { 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Micro bloqué. Ouvre les Paramètres de ton tel pour autoriser l'appli.")));
        await openAppSettings(); 
        return; 
      }
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: 'fr_FR',
          onResult: (val) {
            String texteEcoute = val.recognizedWords.toLowerCase();
            if (texteEcoute.contains("fin") || texteEcoute.contains("mute")) { _speech.stop(); setState(() => _isListening = false); return; }
            if (texteEcoute.contains("shadow fait une conversation privée avec")) {
              List<String> mots = texteEcoute.split("avec");
              if (mots.length > 1) { _speech.stop(); setState(() => _isListening = false); widget.onChangeSalon("Privé : ${mots.last.trim()}"); }
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
      if (docUtilisateur.exists) monPseudoActuel = docUtilisateur.data()!['pseudos']?[widget.nomDuJeu] ?? docUtilisateur.data()!['pseudos']?['Général'] ?? "Joueur";
    } catch (e) { }
    await FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').add({'texte': texte, 'expediteur': monPseudoActuel, 'avatar': myAvatarUrl, 'email': user.email, 'timestamp': FieldValue.serverTimestamp()});
    messageController.clear();
  }

  void confirmerSuppression(String messageId) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Supprimer ?"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")), TextButton(onPressed: () async { await FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').doc(messageId).delete(); Navigator.pop(context); }, child: const Text("Supprimer", style: TextStyle(color: Colors.red)))]));
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
                  final msgDoc = snapshot.data!.docs[index]; final msg = msgDoc.data() as Map<String, dynamic>; final bool isMe = msg['email'] == user?.email;
                  String avatarMsg = msg['avatar'] ?? '';
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: GestureDetector(
                      onLongPress: isMe ? () => confirmerSuppression(msgDoc.id) : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: isMe ? Colors.cyanAccent.withOpacity(0.2) : Colors.black87, border: Border.all(color: isMe ? Colors.cyanAccent.withOpacity(0.5) : Colors.transparent), borderRadius: BorderRadius.circular(15)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isMe && avatarMsg.isNotEmpty) ...[CircleAvatar(backgroundImage: NetworkImage(avatarMsg), radius: 15), const SizedBox(width: 8)],
                            if (!isMe && avatarMsg.isEmpty) ...[const CircleAvatar(backgroundColor: Colors.grey, radius: 15, child: Icon(Icons.person, size: 15, color: Colors.white)), const SizedBox(width: 8)],
                            Flexible(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (!isMe) Text(msg['expediteur'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent, fontSize: 12)),
                                Text(msg['texte'] ?? "", style: const TextStyle(fontSize: 16, color: Colors.white)),
                              ]),
                            ),
                            if (isMe && avatarMsg.isNotEmpty) ...[const SizedBox(width: 8), CircleAvatar(backgroundImage: NetworkImage(avatarMsg), radius: 15)],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [ Expanded(child: TextField(controller: messageController, decoration: InputDecoration(hintText: "Message...", filled: true, fillColor: Colors.black87, border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)))), const SizedBox(width: 8), CircleAvatar(backgroundColor: _isListening ? Colors.redAccent : Colors.black54, child: IconButton(icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white), onPressed: _ecouterAssistant)), const SizedBox(width: 8), CircleAvatar(backgroundColor: Colors.cyanAccent, child: IconButton(icon: const Icon(Icons.send, color: Colors.black), onPressed: envoyerMessage)) ])))
      ],
    );
  }
}

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
                      subtitle: const Text("🟢 En ligne", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
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

// --- PARAMÈTRES (PROFIL + BOUTON ADMIN) ---
class ParametresPage extends StatefulWidget { 
  final String monRole;
  const ParametresPage({super.key, required this.monRole}); 
  @override State<ParametresPage> createState() => _ParametresPageState(); 
}

class _ParametresPageState extends State<ParametresPage> {
  final TextEditingController discordController = TextEditingController();
  final TextEditingController avatarController = TextEditingController(); 
  final user = FirebaseAuth.instance.currentUser;

  Future<void> sauvegarderProfil() async {
    if (user != null) {
      await FirebaseFirestore.instance.collection('utilisateurs').doc(user!.uid).update({'discord': discordController.text.trim(), 'avatar': avatarController.text.trim()});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil mis à jour ! ✅"), backgroundColor: Colors.green));
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
          if (discordController.text.isEmpty) discordController.text = data?['discord'] ?? "";
          if (avatarController.text.isEmpty) avatarController.text = data?['avatar'] ?? "";
          String roleAffichage = widget.monRole == 'admin' ? "👑 ADMINISTRATEUR" : "Gamer";

          return ListView(
            children: [
              Container(
                color: Colors.black26, padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(radius: 40, backgroundColor: Colors.cyanAccent, backgroundImage: avatarController.text.isNotEmpty ? NetworkImage(avatarController.text) : null, child: avatarController.text.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.black) : null),
                    const SizedBox(height: 10),
                    Text(pseudo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(roleAffichage, style: TextStyle(color: widget.monRole == 'admin' ? Colors.amber : Colors.cyanAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextField(controller: avatarController, decoration: const InputDecoration(labelText: 'URL de ta photo (Lien image)', prefixIcon: Icon(Icons.image))),
                    const SizedBox(height: 10),
                    TextField(controller: discordController, decoration: const InputDecoration(labelText: 'Lien/Pseudo Discord', prefixIcon: Icon(Icons.discord))),
                    const SizedBox(height: 10),
                    ElevatedButton(onPressed: sauvegarderProfil, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent), child: const Text("SAUVEGARDER LE PROFIL", style: TextStyle(color: Colors.black))),
                  ],
                ),
              ),
              if (widget.monRole == 'admin') ...[
                const Divider(color: Colors.amber),
                ListTile(leading: const Icon(Icons.gavel, color: Colors.amber), title: const Text('Panneau Administrateur', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPage()))),
              ],
              const Divider(color: Colors.white24),
              ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent), title: const Text('Se déconnecter', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)), onTap: () async { await FirebaseAuth.instance.signOut(); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false); }),
            ],
          );
        }
      ),
    );
  }
}

// --- LA PAGE D'ADMINISTRATION SECRÈTE ---
class AdminPage extends StatefulWidget { const AdminPage({super.key}); @override State<AdminPage> createState() => _AdminPageState(); }
class _AdminPageState extends State<AdminPage> {
  final TextEditingController rechercheController = TextEditingController();

  Future<void> bannirJoueur(String uid, bool statutBanni) async {
    await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'banni': statutBanni});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(statutBanni ? "🔨 Joueur banni !" : "✅ Joueur débanni !")));
    setState((){}); 
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modération', style: TextStyle(color: Colors.amber))),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(16.0), child: TextField(controller: rechercheController, decoration: InputDecoration(labelText: "Rechercher un pseudo (Général)...", suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() {}))))),
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('utilisateurs').where('pseudos.Général', isEqualTo: rechercheController.text.trim()).get(),
              builder: (context, snapshot) {
                if (rechercheController.text.isEmpty) return const Center(child: Text("Cherche un joueur à sanctionner."));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Joueur introuvable."));
                
                var doc = snapshot.data!.docs.first;
                bool isBanni = doc.data().toString().contains('banni') ? doc['banni'] : false;
                
                return ListTile(
                  title: Text(doc['pseudos']['Général'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  subtitle: Text("Email : ${doc['email']}"),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: isBanni ? Colors.green : Colors.red),
                    onPressed: () => bannirJoueur(doc.id, !isBanni),
                    child: Text(isBanni ? "Débannir" : "BANNIR", style: const TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
