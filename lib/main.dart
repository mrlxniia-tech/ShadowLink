import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
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
      home: FirebaseAuth.instance.currentUser == null ? const LoginPage() : const LoadingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- ECRAN DE CHARGEMENT (Vérifie le Ban avant de laisser entrer) ---
class LoadingScreen extends StatefulWidget { const LoadingScreen({super.key}); @override State<LoadingScreen> createState() => _LoadingScreenState(); }
class _LoadingScreenState extends State<LoadingScreen> {
  @override void initState() { super.initState(); _verifierStatut(); }
  
  Future<void> _verifierStatut() async {
    final user = FirebaseAuth.instance.currentUser; if (user == null) return;
    var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      // AUTO-ADMIN POUR JUN ET MRLX
      String p = data['pseudos']?['Général'] ?? '';
      if ((p.toLowerCase() == 'jun' || p.toLowerCase() == 'mrlx') && data['role'] != 'admin') {
        await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).update({'role': 'admin'});
      }

      // VERIFICATION DU BAN
      if (data['banni'] == true) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TribunalPage(donneesUtilisateur: data, uid: user.uid)));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
      }
    }
  }
  @override Widget build(BuildContext context) { return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent))); }
}

// --- PAGE DU TRIBUNAL (POUR LES BANNIS) ---
class TribunalPage extends StatefulWidget { 
  final Map<String, dynamic> donneesUtilisateur; final String uid;
  const TribunalPage({super.key, required this.donneesUtilisateur, required this.uid}); 
  @override State<TribunalPage> createState() => _TribunalPageState(); 
}
class _TribunalPageState extends State<TribunalPage> {
  final TextEditingController appelController = TextEditingController();

  Future<void> envoyerAppel() async {
    if (appelController.text.trim().isEmpty) return;
    await FirebaseFirestore.instance.collection('utilisateurs').doc(widget.uid).update({'messageAppel': appelController.text.trim()});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ton message a été envoyé aux Administrateurs."), backgroundColor: Colors.green));
  }

  @override Widget build(BuildContext context) {
    String cause = widget.donneesUtilisateur['causeBan'] ?? "Violation des règles.";
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gavel, size: 80, color: Colors.redAccent), const SizedBox(height: 20),
              const Text("COMPTE RESTREINT", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.redAccent)), const SizedBox(height: 20),
              Text("Cause : $cause", style: const TextStyle(fontSize: 18, color: Colors.white, fontStyle: FontStyle.italic), textAlign: TextAlign.center), const SizedBox(height: 40),
              const Text("Si tu penses qu'il s'agit d'une erreur, laisse un message aux modérateurs :", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center), const SizedBox(height: 10),
              TextField(controller: appelController, maxLines: 3, decoration: const InputDecoration(hintText: "Je m'excuse pour...", border: OutlineInputBorder(), filled: true, fillColor: Colors.black54)), const SizedBox(height: 20),
              ElevatedButton(onPressed: envoyerAppel, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("ENVOYER MON APPEL", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))), const SizedBox(height: 20),
              TextButton(onPressed: () async { await FirebaseAuth.instance.signOut(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage())); }, child: const Text("Se déconnecter", style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ),
      ),
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
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoadingScreen()));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.message}"), backgroundColor: Colors.red));
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity, width: double.infinity,
        decoration: BoxDecoration(image: DecorationImage(image: const NetworkImage('https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=2070'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken))),
        child: Center(
          child: SingleChildScrollView(
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
                const SizedBox(height: 10),
                TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())), child: const Text("Pas de compte ? Créer un profil", style: TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- PAGE D'INSCRIPTION ---
class RegisterPage extends StatefulWidget { const RegisterPage({super.key}); @override State<RegisterPage> createState() => _RegisterPageState(); }
class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController(); final TextEditingController passwordController = TextEditingController(); final TextEditingController pseudoGeneralController = TextEditingController();
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
      String p = pseudoGeneralController.text.trim().toLowerCase(); String r = (p == 'jun' || p == 'mrlx') ? 'admin' : 'user';

      await FirebaseFirestore.instance.collection('utilisateurs').doc(userCred.user!.uid).set({
        'email': emailController.text.trim(), 'pseudos': tousMesPseudos, 'amis': [], 'discord': '', 'avatar': '', 'bio': '', 
        'role': r, 'banni': false, 'causeBan': '', 'messageAppel': '', 'isMuted': false, 'dateCreation': FieldValue.serverTimestamp()
      });
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoadingScreen()), (route) => false);
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur"), backgroundColor: Colors.red)); } finally { setState(() => isChargement = false); }
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
            ...listeJeux.map((jeu) { return Column(children: [CheckboxListTile(title: Text(jeu), activeColor: Colors.cyanAccent, value: jeuxCoches[jeu], onChanged: (bool? val) => setState(() => jeuxCoches[jeu] = val ?? false)), if (jeuxCoches[jeu] == true) Padding(padding: const EdgeInsets.only(left: 40.0, right: 16.0, bottom: 10.0), child: TextField(controller: pseudosJeux[jeu], decoration: InputDecoration(labelText: 'Pseudo sur $jeu', border: const OutlineInputBorder())))]); }).toList(),
            const SizedBox(height: 20), ElevatedButton(onPressed: creerCompte, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, minimumSize: const Size(double.infinity, 50)), child: const Text('VALIDER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}

// --- ECRAN PRINCIPAL ---
class MainScreen extends StatefulWidget { final String salonInitial; const MainScreen({super.key, this.salonInitial = "Général"}); @override State<MainScreen> createState() => _MainScreenState(); }
class _MainScreenState extends State<MainScreen> {
  late String salonActuel; final List<String> tousLesSalons = ["Général", "Call of Duty", "Minecraft", "Roblox", "Fortnite", "Clash Royale", "Ea FC", "Valorant"];
  String myRole = 'user'; String myAvatarUrl = ''; final String myUid = FirebaseAuth.instance.currentUser!.uid;
  final String defaultCommunityBg = "https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=1080"; 
  final Map<String, String> fondsEcrans = { "Général": "https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1080", "Call of Duty": "https://images.igdb.com/igdb/image/upload/t_1080p/co2v04.jpg", "Minecraft": "https://images.igdb.com/igdb/image/upload/t_1080p/co49x5.jpg", "Roblox": "https://images.igdb.com/igdb/image/upload/t_1080p/co1t2a.jpg", "Fortnite": "https://images.igdb.com/igdb/image/upload/t_1080p/co2ve0.jpg", "Clash Royale": "https://images.igdb.com/igdb/image/upload/t_1080p/co21z9.jpg", "Ea FC": "https://images.igdb.com/igdb/image/upload/t_1080p/co6i9n.jpg", "Valorant": "https://images.igdb.com/igdb/image/upload/t_1080p/co2mvt.jpg" };

  @override void initState() { super.initState(); salonActuel = widget.salonInitial; if (!tousLesSalons.contains(salonActuel) && !salonActuel.startsWith("Privé")) tousLesSalons.add(salonActuel); _chargerInfos(); }
  Future<void> _chargerInfos() async { var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).get(); if (doc.exists) { setState(() { myRole = doc.data()?['role'] ?? 'user'; myAvatarUrl = doc.data()?['avatar'] ?? ''; }); } }

  void _afficherCreationSalon() {
    final TextEditingController nomSalonController = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Créer un Salon", style: TextStyle(color: Colors.cyanAccent)), content: TextField(controller: nomSalonController, maxLength: 25, decoration: const InputDecoration(hintText: "Nom du salon...", border: OutlineInputBorder())), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler", style: TextStyle(color: Colors.grey))), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent), onPressed: () async { String nomCustom = nomSalonController.text.trim(); if (nomCustom.isNotEmpty && !tousLesSalons.contains(nomCustom)) { await FirebaseFirestore.instance.collection('salons_custom').doc(nomCustom).set({'nom': nomCustom, 'createur': myUid, 'timestamp': FieldValue.serverTimestamp()}); Navigator.pop(context); setState(() => salonActuel = nomCustom); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🚀 Salon créé !"))); } }, child: const Text("CRÉER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))]));
  }

  @override Widget build(BuildContext context) {
    String fondEgal = fondsEcrans[salonActuel] ?? defaultCommunityBg;
    return Scaffold(
      appBar: AppBar(title: Text(salonActuel.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.cyanAccent)), centerTitle: true),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1A1A24),
        child: Column(
          children: [
            DrawerHeader(decoration: const BoxDecoration(image: DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=2071'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken))), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 30, backgroundColor: Colors.cyanAccent, backgroundImage: myAvatarUrl.isNotEmpty ? NetworkImage(myAvatarUrl) : const NetworkImage('https://i.ibb.co/tP5c32d/logo.png')), const SizedBox(height: 10), const Text('SHADOWLINK', style: TextStyle(color: Colors.cyanAccent, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3))]))),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(leading: const Icon(Icons.group, color: Colors.blueAccent), title: const Text("👥 Mes Amis", style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsPage())); }), const Divider(color: Colors.white24),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Text("🎮 JEUX OFFICIELS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
                  ...tousLesSalons.map((jeu) => Container(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: jeu == salonActuel ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent, border: Border.all(color: jeu == salonActuel ? Colors.cyanAccent : Colors.transparent), borderRadius: BorderRadius.circular(10)), child: ListTile(leading: jeu.startsWith("Privé") ? const CircleAvatar(backgroundColor: Colors.deepPurple, child: Icon(Icons.lock, color: Colors.white, size: 18)) : CircleAvatar(backgroundImage: NetworkImage(fondsEcrans[jeu] ?? fondsEcrans["Général"]!), radius: 18), title: Text(jeu, style: TextStyle(fontWeight: jeu == salonActuel ? FontWeight.bold : FontWeight.normal, color: jeu == salonActuel ? Colors.cyanAccent : Colors.white70)), onTap: () { setState(() => salonActuel = jeu); Navigator.pop(context); }))).toList(),
                  const Divider(color: Colors.white24, height: 30),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("🌐 COMMUNAUTÉ", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)), IconButton(icon: const Icon(Icons.add_circle, color: Colors.greenAccent, size: 20), onPressed: _afficherCreationSalon, tooltip: "Créer un salon")])),
                  StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('salons_custom').orderBy('timestamp', descending: true).snapshots(), builder: (context, snapshot) { if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.cyanAccent))); final customRooms = snapshot.data!.docs; if (customRooms.isEmpty) return const Padding(padding: EdgeInsets.only(left: 16.0), child: Text("Aucun salon créé. Sois le premier !", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic))); return Column(children: customRooms.map((doc) { Map<String, dynamic> data = doc.data() as Map<String, dynamic>; String nomCustom = data['nom'] ?? 'Salon Inconnu'; return Container(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: nomCustom == salonActuel ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent, border: Border.all(color: nomCustom == salonActuel ? Colors.cyanAccent : Colors.transparent), borderRadius: BorderRadius.circular(10)), child: ListTile(leading: const CircleAvatar(backgroundImage: NetworkImage('https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=200'), radius: 18), title: Text(nomCustom, style: TextStyle(fontWeight: nomCustom == salonActuel ? FontWeight.bold : FontWeight.normal, color: nomCustom == salonActuel ? Colors.cyanAccent : Colors.white70)), onTap: () { setState(() => salonActuel = nomCustom); Navigator.pop(context); })); }).toList()); }), const SizedBox(height: 20), 
                ],
              )
            ),
            SafeArea(top: false, bottom: true, child: ListTile(leading: const Icon(Icons.settings, color: Colors.grey), title: const Text("Profil & Paramètres"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ParametresPage(monRole: myRole)))))
          ],
        ),
      ),
      body: Container(decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(fondEgal), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken))), child: ChatWidget(nomDuJeu: salonActuel, onChangeSalon: (nouveauSalon) { setState(() { salonActuel = nouveauSalon; if (!tousLesSalons.contains(salonActuel)) tousLesSalons.add(salonActuel); }); })),
    );
  }
}

// --- WIDGET CHAT ---
class ChatWidget extends StatefulWidget { final String nomDuJeu; final Function(String) onChangeSalon; const ChatWidget({super.key, required this.nomDuJeu, required this.onChangeSalon}); @override State<ChatWidget> createState() => _ChatWidgetState(); }
class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController messageController = TextEditingController();
  String myAvatarUrl = ''; String myRole = 'user'; bool isMuted = false;

  @override void initState() { super.initState(); _chargerMesInfos(); }
  Future<void> _chargerMesInfos() async {
    final user = FirebaseAuth.instance.currentUser; if (user == null) return;
    var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
    if (doc.exists) setState(() { myAvatarUrl = doc.data()?['avatar'] ?? ''; myRole = doc.data()?['role'] ?? 'user'; isMuted = doc.data()?['isMuted'] ?? false; });
  }

  Future<void> envoyerMessage() async {
    if (isMuted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🔇 Tu as été rendu muet par un modérateur."), backgroundColor: Colors.red)); return; }
    String texte = messageController.text.trim(); if (texte.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser; if (user == null) return; String monPseudoActuel = "Joueur";
    try { var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get(); if (doc.exists) monPseudoActuel = doc.data()!['pseudos']?[widget.nomDuJeu] ?? doc.data()!['pseudos']?['Général'] ?? "Joueur"; } catch (e) { }
    await FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').add({'texte': texte, 'expediteur': monPseudoActuel, 'avatar': myAvatarUrl, 'role': myRole, 'email': user.email, 'timestamp': FieldValue.serverTimestamp()}); messageController.clear();
  }

  void actionMessage(String messageId, String texte, bool isMe) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Action"), content: Text('"$texte"'), actions: [TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: texte)); Navigator.pop(context); }, child: const Text("Copier")), if (isMe || myRole == 'admin' || myRole == 'modo') TextButton(onPressed: () async { await FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').doc(messageId).delete(); Navigator.pop(context); }, child: const Text("Supprimer", style: TextStyle(color: Colors.red))), TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler"))]));
  }

  @override Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Aucun message ici.", style: TextStyle(color: Colors.white54)));
              return ListView.builder(
                reverse: true, itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final msgDoc = snapshot.data!.docs[index]; final msg = msgDoc.data() as Map<String, dynamic>; final bool isMe = msg['email'] == user?.email;
                  String avatarMsg = msg['avatar'] ?? ''; String roleMsg = msg['role'] ?? 'user'; String timeString = "";
                  if (msg['timestamp'] != null) { DateTime dt = (msg['timestamp'] as Timestamp).toDate(); timeString = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}"; }

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: GestureDetector(
                      onLongPress: () => actionMessage(msgDoc.id, msg['texte'] ?? "", isMe),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: isMe ? Colors.cyanAccent.withOpacity(0.2) : Colors.black87, borderRadius: BorderRadius.circular(15)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe && avatarMsg.isNotEmpty) ...[CircleAvatar(backgroundImage: NetworkImage(avatarMsg), radius: 15), const SizedBox(width: 8)],
                            if (!isMe && avatarMsg.isEmpty) ...[const CircleAvatar(backgroundColor: Colors.grey, radius: 15, child: Icon(Icons.person, size: 15, color: Colors.white)), const SizedBox(width: 8)],
                            Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (!isMe) Row(mainAxisSize: MainAxisSize.min, children: [Text(msg['expediteur'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent, fontSize: 12)), if (roleMsg == 'admin') const Text(" 👑", style: TextStyle(fontSize: 12)), if (roleMsg == 'modo') const Text(" 🛡️", style: TextStyle(fontSize: 12))]), Text(msg['texte'] ?? "", style: const TextStyle(fontSize: 16, color: Colors.white))])), const SizedBox(width: 8), Text(timeString, style: const TextStyle(fontSize: 10, color: Colors.white54)), if (isMe && avatarMsg.isNotEmpty) ...[const SizedBox(width: 8), CircleAvatar(backgroundImage: NetworkImage(avatarMsg), radius: 15)],
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
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [ Expanded(child: TextField(controller: messageController, decoration: InputDecoration(hintText: isMuted ? "🔇 Tu es rendu muet..." : "Message...", filled: true, fillColor: Colors.black87, border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)), enabled: !isMuted)), const SizedBox(width: 8), CircleAvatar(backgroundColor: isMuted ? Colors.grey : Colors.cyanAccent, child: IconButton(icon: const Icon(Icons.send, color: Colors.black), onPressed: envoyerMessage)) ])))
      ],
    );
  }
}

// ... FriendsPage & NotificationsPage cachées pour l'espace (elles restent identiques)
class FriendsPage extends StatelessWidget { const FriendsPage({super.key}); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Mes Amis")), body: const Center(child: Text("Page d'amis (Code intact)"))); } }
class NotificationsPage extends StatelessWidget { const NotificationsPage({super.key}); @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Notifications")), body: const Center(child: Text("Notifications (Code intact)"))); } }

// --- PARAMÈTRES (AJOUT DU BOUTON PHOTO) ---
class ParametresPage extends StatefulWidget { final String monRole; const ParametresPage({super.key, required this.monRole}); @override State<ParametresPage> createState() => _ParametresPageState(); }
class _ParametresPageState extends State<ParametresPage> {
  final TextEditingController discordController = TextEditingController(); final TextEditingController avatarController = TextEditingController(); final TextEditingController bioController = TextEditingController(); 
  final user = FirebaseAuth.instance.currentUser;

  Future<void> sauvegarderProfil() async {
    if (user != null) {
      await FirebaseFirestore.instance.collection('utilisateurs').doc(user!.uid).update({'discord': discordController.text.trim(), 'avatar': avatarController.text.trim(), 'bio': bioController.text.trim()});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil mis à jour ! ✅"), backgroundColor: Colors.green));
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil & Paramètres')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('utilisateurs').doc(user!.uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var data = snapshot.data!.data() as Map<String, dynamic>?; String pseudo = data?['pseudos']?['Général'] ?? "Joueur";
          if (discordController.text.isEmpty) discordController.text = data?['discord'] ?? ""; if (avatarController.text.isEmpty) avatarController.text = data?['avatar'] ?? ""; if (bioController.text.isEmpty) bioController.text = data?['bio'] ?? "";
          String roleAffichage = widget.monRole == 'admin' ? "👑 ADMINISTRATEUR" : (widget.monRole == 'modo' ? "🛡️ MODÉRATEUR" : "Gamer");

          return ListView(
            children: [
              Container(
                color: Colors.black26, padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(radius: 40, backgroundColor: Colors.cyanAccent, backgroundImage: avatarController.text.isNotEmpty ? NetworkImage(avatarController.text) : null, child: avatarController.text.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.black) : null), const SizedBox(height: 10),
                    Text(pseudo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)), Text(roleAffichage, style: TextStyle(color: widget.monRole == 'admin' ? Colors.amber : (widget.monRole == 'modo' ? Colors.blue : Colors.cyanAccent), fontWeight: FontWeight.bold)), const SizedBox(height: 20),
                    TextField(controller: bioController, maxLength: 50, decoration: const InputDecoration(labelText: 'Ma Bio (ex: Cherche team...)', prefixIcon: Icon(Icons.edit))), const SizedBox(height: 10),
                    // BOUTON PREPARATOIRE POUR LA GALERIE PHOTO (PC REQUIS PLUS TARD)
                    TextField(controller: avatarController, decoration: InputDecoration(labelText: 'URL de ta photo (Lien image)', prefixIcon: const Icon(Icons.image), suffixIcon: IconButton(icon: const Icon(Icons.camera_alt, color: Colors.amber), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bientôt dispo ! (Nécessite Firebase Storage)"))); }))), const SizedBox(height: 10),
                    TextField(controller: discordController, decoration: const InputDecoration(labelText: 'Lien/Pseudo Discord', prefixIcon: Icon(Icons.discord))), const SizedBox(height: 10),
                    ElevatedButton(onPressed: sauvegarderProfil, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent), child: const Text("SAUVEGARDER LE PROFIL", style: TextStyle(color: Colors.black))),
                  ],
                ),
              ),
              if (widget.monRole == 'admin' || widget.monRole == 'modo') ...[const Divider(color: Colors.amber), ListTile(leading: const Icon(Icons.gavel, color: Colors.amber), title: const Text('Panneau de Modération', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdminPage(monRole: widget.monRole))))],
              const Divider(color: Colors.white24), ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent), title: const Text('Se déconnecter', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)), onTap: () async { await FirebaseAuth.instance.signOut(); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false); }),
            ],
          );
        }
      ),
    );
  }
}

// --- LE SUPER PANNEAU DE MODERATION ---
class AdminPage extends StatefulWidget { final String monRole; const AdminPage({super.key, required this.monRole}); @override State<AdminPage> createState() => _AdminPageState(); }
class _AdminPageState extends State<AdminPage> {
  final TextEditingController rechercheController = TextEditingController();

  void gererJoueur(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String uid = doc.id; String pseudo = data['pseudos']?['Général'] ?? 'Inconnu'; String roleJoueur = data['role'] ?? 'user';
    bool isBanni = data['banni'] ?? false; bool isMuted = data['isMuted'] ?? false; String appel = data['messageAppel'] ?? '';

    showModalBottomSheet(context: context, builder: (context) {
      return Container(
        padding: const EdgeInsets.all(20), color: Colors.black87,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Gérer $pseudo", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)),
            if (appel.isNotEmpty && isBanni) ...[const SizedBox(height: 10), Container(padding: const EdgeInsets.all(10), color: Colors.red.withOpacity(0.2), child: Text("📜 Appel reçu : \"$appel\"", style: const TextStyle(fontStyle: FontStyle.italic)))],
            const Divider(),
            
            // ACTION 1 : MUTER / DEMUTER
            ListTile(leading: Icon(isMuted ? Icons.volume_up : Icons.volume_off, color: Colors.blueAccent), title: Text(isMuted ? "Enlever le Mute" : "Rendre Muet (Restreindre)"), onTap: () async { await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'isMuted': !isMuted}); Navigator.pop(context); setState((){}); }),
            
            // ACTION 2 : BANNIR / DEBANNIR (Avec motif)
            ListTile(leading: Icon(isBanni ? Icons.check_circle : Icons.block, color: isBanni ? Colors.green : Colors.red), title: Text(isBanni ? "Débannir et pardonner" : "Bannir ce joueur"), onTap: () {
              Navigator.pop(context);
              if (isBanni) { FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'banni': false, 'causeBan': '', 'messageAppel': ''}); setState((){}); return; }
              final causeController = TextEditingController();
              showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Motif du Ban"), content: TextField(controller: causeController, decoration: const InputDecoration(hintText: "Ex: Insultes, Cheat...")), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'banni': true, 'causeBan': causeController.text.trim()}); Navigator.pop(context); setState((){}); }, child: const Text("BANNIR"))]));
            }),

            // ACTION 3 : PROMOUVOIR MODERATEUR (Seul l'Admin peut le faire)
            if (widget.monRole == 'admin' && roleJoueur != 'admin')
              ListTile(leading: const Icon(Icons.shield, color: Colors.amber), title: Text(roleJoueur == 'modo' ? "Rétrograder en Joueur" : "Promouvoir Modérateur"), onTap: () async { await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'role': roleJoueur == 'modo' ? 'user' : 'modo'}); Navigator.pop(context); setState((){}); }),
          ],
        )
      );
    });
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modération & Conflits', style: TextStyle(color: Colors.amber))),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(16.0), child: TextField(controller: rechercheController, decoration: InputDecoration(labelText: "Rechercher un pseudo (Général)...", suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() {}))))),
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('utilisateurs').where('pseudos.Général', isEqualTo: rechercheController.text.trim()).get(),
              builder: (context, snapshot) {
                if (rechercheController.text.isEmpty) return const Center(child: Text("Cherche un joueur à gérer."));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Joueur introuvable."));
                var doc = snapshot.data!.docs.first; Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                String role = data['role'] ?? 'user';
                return Card(margin: const EdgeInsets.all(10), child: ListTile(title: Text(data['pseudos']['Général'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), subtitle: Text("Rôle : $role\nMute : ${data['isMuted'] == true ? 'Oui' : 'Non'} | Banni : ${data['banni'] == true ? 'Oui' : 'Non'}"), trailing: const Icon(Icons.settings, color: Colors.cyanAccent), onTap: () => gererJoueur(doc)));
              },
            ),
          )
        ],
      ),
    );
  }
}
