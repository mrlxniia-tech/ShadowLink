import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

void main() async { WidgetsFlutterBinding.ensureInitialized(); await Firebase.initializeApp(); runApp(const MyApp()); }

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShadowLink',
      theme: ThemeData(primarySwatch: Colors.deepPurple, brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0D0D12), appBarTheme: const AppBarTheme(backgroundColor: Colors.black87, elevation: 0)),
      home: FirebaseAuth.instance.currentUser == null ? const LoginPage() : const LoadingScreen(), debugShowCheckedModeBanner: false,
    );
  }
}

// --- OUTILS ---
Color getCouleurPseudo(String col) { switch(col) { case 'Rouge': return Colors.redAccent; case 'Vert': return Colors.greenAccent; case 'Violet': return Colors.purpleAccent; case 'Or': return Colors.amber; default: return Colors.cyanAccent; } }
String getTitreNiveau(int lvl) { if(lvl >= 50) return "Légende"; if(lvl >= 30) return "Élite"; if(lvl >= 10) return "Vétéran"; if(lvl >= 5) return "Habitué"; return "Recrue"; }

// --- CHARGEMENT & ROLES (CREATEUR) ---
class LoadingScreen extends StatefulWidget { const LoadingScreen({super.key}); @override State<LoadingScreen> createState() => _LoadingScreenState(); }
class _LoadingScreenState extends State<LoadingScreen> {
  @override void initState() { super.initState(); _verifierStatut(); }
  Future<void> _verifierStatut() async {
    final user = FirebaseAuth.instance.currentUser; if (user == null) return;
    var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
    if (doc.exists) {
      Map<String, dynamic> d = doc.data() as Map<String, dynamic>;
      String p = (d['pseudos']?['Général'] ?? '').toString().trim().toLowerCase();
      
      // AUTO-ROLES : MRLX = CREATEUR | JUN = ADMIN
      if (p == 'mrlx' && d['role'] != 'createur') { await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).update({'role': 'createur'}); d['role'] = 'createur'; }
      else if (p == 'jun' && d['role'] != 'admin' && d['role'] != 'createur') { await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).update({'role': 'admin'}); d['role'] = 'admin'; }
      
      if (d['banni'] == true) {
        if (d['finBan'] != null) {
          DateTime finDuBan = (d['finBan'] as Timestamp).toDate();
          if (finDuBan.isBefore(DateTime.now())) {
            await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).update({'banni': false, 'causeBan': FieldValue.delete(), 'finBan': FieldValue.delete(), 'warnings': 0});
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen())); return;
          }
        }
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TribunalPage(donneesUtilisateur: d, uid: user.uid))); 
      } else { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen())); }
    }
  }
  @override Widget build(BuildContext context) { return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent))); }
}

class TribunalPage extends StatefulWidget { final Map<String, dynamic> donneesUtilisateur; final String uid; const TribunalPage({super.key, required this.donneesUtilisateur, required this.uid}); @override State<TribunalPage> createState() => _TribunalPageState(); }
class _TribunalPageState extends State<TribunalPage> {
  final TextEditingController appelController = TextEditingController();
  Future<void> envoyerAppel() async { if (appelController.text.trim().isEmpty) return; await FirebaseFirestore.instance.collection('utilisateurs').doc(widget.uid).update({'messageAppel': appelController.text.trim()}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appel envoyé aux modérateurs."))); }
  @override Widget build(BuildContext context) {
    String cause = widget.donneesUtilisateur['causeBan'] ?? "Violation des règles."; bool isTemp = widget.donneesUtilisateur['finBan'] != null;
    return Scaffold(backgroundColor: Colors.black87, body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.gavel, size: 80, color: Colors.redAccent), const SizedBox(height: 20), const Text("COMPTE RESTREINT", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.redAccent)), const SizedBox(height: 20), Text("Cause : $cause", style: const TextStyle(fontSize: 18, color: Colors.white, fontStyle: FontStyle.italic)), const SizedBox(height: 10), if(isTemp) const Text("⏳ Ban Temporaire (Attends l'expiration)", style: TextStyle(color: Colors.orange)), const SizedBox(height: 40), TextField(controller: appelController, decoration: const InputDecoration(hintText: "Contester ou s'excuser...", filled: true, fillColor: Colors.black54)), const SizedBox(height: 20), ElevatedButton(onPressed: envoyerAppel, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("ENVOYER MON APPEL", style: TextStyle(color: Colors.black))), const SizedBox(height: 20), TextButton(onPressed: () async { await FirebaseAuth.instance.signOut(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage())); }, child: const Text("Se déconnecter", style: TextStyle(color: Colors.redAccent))),])))));
  }
}

// --- CONNEXION & INSCRIPTION ---
class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState() => _LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController(); final TextEditingController passwordController = TextEditingController(); bool _obscurePassword = true;
  Future<void> seConnecter() async { if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) return; try { await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim()); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoadingScreen())); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur de connexion"))); } }
  @override Widget build(BuildContext context) { return Scaffold(body: Container(decoration: BoxDecoration(image: DecorationImage(image: const NetworkImage('https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=2070'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken))), child: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.videogame_asset, size: 80, color: Colors.cyanAccent), const SizedBox(height: 10), const Text("SHADOWLINK", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)), const SizedBox(height: 30), TextField(controller: emailController, decoration: InputDecoration(labelText: 'Email', filled: true, fillColor: Colors.black54, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))), const SizedBox(height: 16), TextField(controller: passwordController, obscureText: _obscurePassword, decoration: InputDecoration(labelText: 'Mot de passe', filled: true, fillColor: Colors.black54, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.cyanAccent), onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); }))), const SizedBox(height: 20), ElevatedButton(onPressed: seConnecter, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, minimumSize: const Size(double.infinity, 50)), child: const Text('CONNEXION', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))), TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())), child: const Text("Créer un profil", style: TextStyle(color: Colors.cyanAccent)))])))))); }
}

class RegisterPage extends StatefulWidget { const RegisterPage({super.key}); @override State<RegisterPage> createState() => _RegisterPageState(); }
class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController(); final TextEditingController passwordController = TextEditingController(); final TextEditingController pseudoGeneralController = TextEditingController();
  final List<String> listeJeux = ["Call of Duty", "Minecraft", "Roblox", "Fortnite", "Clash Royale", "Ea FC", "Valorant"]; final Map<String, bool> jeuxCoches = {}; final Map<String, TextEditingController> pseudosJeux = {}; bool isChargement = false;
  @override void initState() { super.initState(); for (var jeu in listeJeux) { jeuxCoches[jeu] = false; pseudosJeux[jeu] = TextEditingController(); } }
  Future<void> creerCompte() async {
    setState(() => isChargement = true);
    try {
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      Map<String, String> tousMesPseudos = {"Général": pseudoGeneralController.text.trim()};
      for (var jeu in listeJeux) { if (jeuxCoches[jeu] == true && pseudosJeux[jeu]!.text.trim().isNotEmpty) tousMesPseudos[jeu] = pseudosJeux[jeu]!.text.trim(); }
      String p = pseudoGeneralController.text.trim().toLowerCase(); 
      String r = 'user'; if (p == 'mrlx') r = 'createur'; else if (p == 'jun') r = 'admin';
      
      await FirebaseFirestore.instance.collection('utilisateurs').doc(userCred.user!.uid).set({ 'email': emailController.text.trim(), 'pseudos': tousMesPseudos, 'amis': [], 'xp': 0, 'coins': 100, 'couleur': 'Cyan', 'enLigne': true, 'role': r, 'banni': false, 'warnings': 0, 'badge': '', 'filtreInsultes': true, 'isLFG': false, 'isAFK': false, 'statut': 'Nouveau !', 'dateCreation': FieldValue.serverTimestamp() });
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoadingScreen()), (route) => false);
    } catch (e) { } finally { setState(() => isChargement = false); }
  }
  @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Créer ton Profil")), body: SafeArea(child: isChargement ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: Column(children: [TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: pseudoGeneralController, decoration: const InputDecoration(labelText: 'Pseudo Principal', border: OutlineInputBorder())), const SizedBox(height: 30), ...listeJeux.map((jeu) { return Column(children: [CheckboxListTile(title: Text(jeu), activeColor: Colors.cyanAccent, value: jeuxCoches[jeu], onChanged: (bool? val) => setState(() => jeuxCoches[jeu] = val ?? false)), if (jeuxCoches[jeu] == true) Padding(padding: const EdgeInsets.only(left: 40.0, right: 16.0, bottom: 10.0), child: TextField(controller: pseudosJeux[jeu], decoration: InputDecoration(labelText: 'Pseudo sur $jeu', border: const OutlineInputBorder())))]); }).toList(), const SizedBox(height: 20), ElevatedButton(onPressed: creerCompte, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, minimumSize: const Size(double.infinity, 50)), child: const Text('VALIDER', style: TextStyle(color: Colors.black)))])))); }
}

// --- ECRAN PRINCIPAL ---
class MainScreen extends StatefulWidget { final String salonInitial; const MainScreen({super.key, this.salonInitial = "Général"}); @override State<MainScreen> createState() => _MainScreenState(); }
class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late String salonActuel; final List<String> tousLesSalons = ["Général", "Call of Duty", "Minecraft", "Roblox", "Fortnite", "Clash Royale", "Ea FC", "Valorant"];
  String myRole = 'user'; String myAvatarUrl = ''; final String myUid = FirebaseAuth.instance.currentUser!.uid; String monPseudoGeneral = '';
  final Map<String, String> fondsEcrans = { "Général": "https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1080", "Call of Duty": "https://images.igdb.com/igdb/image/upload/t_1080p/co2v04.jpg", "Minecraft": "https://images.igdb.com/igdb/image/upload/t_1080p/co49x5.jpg", "Roblox": "https://images.igdb.com/igdb/image/upload/t_1080p/co1t2a.jpg", "Fortnite": "https://images.igdb.com/igdb/image/upload/t_1080p/co2ve0.jpg", "Clash Royale": "https://images.igdb.com/igdb/image/upload/t_1080p/co21z9.jpg", "Ea FC": "https://images.igdb.com/igdb/image/upload/t_1080p/co6i9n.jpg", "Valorant": "https://images.igdb.com/igdb/image/upload/t_1080p/co2mvt.jpg" };
  String customBg = "";

  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'enLigne': true}); salonActuel = widget.salonInitial; if (!tousLesSalons.contains(salonActuel) && !salonActuel.startsWith("Privé")) tousLesSalons.add(salonActuel); _chargerInfos(); }
  @override void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) { FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'enLigne': true}); } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) { FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'enLigne': false}); } }
  @override void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  Future<void> _chargerInfos() async { var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).get(); if (doc.exists) { setState(() { myRole = doc.data()?['role'] ?? 'user'; myAvatarUrl = doc.data()?['avatar'] ?? ''; monPseudoGeneral = doc.data()?['pseudos']?['Général'] ?? ''; }); } }

  void _afficherCreationSalon() {
    final TextEditingController nomSalonController = TextEditingController(); final TextEditingController bgUrlController = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Créer un Salon"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nomSalonController, maxLength: 25, decoration: const InputDecoration(hintText: "Nom du salon...", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: bgUrlController, decoration: const InputDecoration(hintText: "URL Image de Fond (Optionnel)", prefixIcon: Icon(Icons.image), border: OutlineInputBorder()))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")), ElevatedButton(onPressed: () async { String nomCustom = nomSalonController.text.trim(); if (nomCustom.isNotEmpty && !tousLesSalons.contains(nomCustom)) { await FirebaseFirestore.instance.collection('salons_custom').doc(nomCustom).set({'nom': nomCustom, 'bgUrl': bgUrlController.text.trim(), 'createur': myUid, 'timestamp': FieldValue.serverTimestamp()}); Navigator.pop(context); setState(() { salonActuel = nomCustom; customBg = bgUrlController.text.trim(); }); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent), child: const Text("CRÉER", style: TextStyle(color: Colors.black)))]));
  }
  void _supprimerSalonAdmin(String nomSalon) {
    if (myRole != 'admin' && myRole != 'createur') return;
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Supprimer le salon ?"), content: Text("Es-tu sûr de vouloir détruire '$nomSalon' ?"), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Annuler")), TextButton(onPressed: () async { await FirebaseFirestore.instance.collection('salons_custom').doc(nomSalon).delete(); Navigator.pop(context); setState((){ salonActuel = "Général"; customBg = ""; }); }, child: const Text("DÉTRUIRE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))]));
  }

  @override Widget build(BuildContext context) {
    String fondEgal = (customBg.isNotEmpty && !tousLesSalons.contains(salonActuel)) ? customBg : (fondsEcrans[salonActuel] ?? "https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=1080");
    return Scaffold(
      appBar: AppBar(title: Text(salonActuel.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.cyanAccent)), centerTitle: true),
      drawer: Drawer(backgroundColor: const Color(0xFF1A1A24), child: SafeArea(child: Column(children: [DrawerHeader(decoration: const BoxDecoration(image: DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=2071'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken))), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 30, backgroundColor: Colors.cyanAccent, backgroundImage: myAvatarUrl.isNotEmpty ? NetworkImage(myAvatarUrl) : const NetworkImage('https://i.ibb.co/tP5c32d/logo.png')), const SizedBox(height: 10), const Text('SHADOWLINK', style: TextStyle(color: Colors.cyanAccent, fontSize: 22, fontWeight: FontWeight.bold))]))), Expanded(child: ListView(padding: EdgeInsets.zero, children: [ListTile(leading: const Icon(Icons.group, color: Colors.blueAccent), title: const Text("👥 Mes Amis", style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsPage())); }), const Divider(color: Colors.white24), const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Text("🎮 JEUX OFFICIELS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))), ...tousLesSalons.map((jeu) => Container(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: jeu == salonActuel ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: ListTile(leading: CircleAvatar(backgroundImage: NetworkImage(fondsEcrans[jeu] ?? fondsEcrans["Général"]!), radius: 18), title: Text(jeu, style: TextStyle(color: jeu == salonActuel ? Colors.cyanAccent : Colors.white70)), onTap: () { setState((){ salonActuel = jeu; customBg = ""; }); Navigator.pop(context); }))).toList(), const Divider(color: Colors.white24, height: 30), Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("🌐 COMMUNAUTÉ", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.add_circle, color: Colors.greenAccent), onPressed: _afficherCreationSalon)])), StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('salons_custom').orderBy('timestamp', descending: true).snapshots(), builder: (context, snapshot) { if (!snapshot.hasData) return const SizedBox(); return Column(children: snapshot.data!.docs.map((doc) { Map d = doc.data() as Map; String nomCustom = d['nom'] ?? ''; String bgCustom = d['bgUrl'] ?? ''; return Container(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: nomCustom == salonActuel ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: ListTile(leading: CircleAvatar(backgroundImage: NetworkImage(bgCustom.isNotEmpty ? bgCustom : 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=200'), radius: 18), title: Text(nomCustom, style: TextStyle(color: nomCustom == salonActuel ? Colors.cyanAccent : Colors.white70)), onLongPress: () => _supprimerSalonAdmin(nomCustom), onTap: () { setState(() { salonActuel = nomCustom; customBg = bgCustom; }); Navigator.pop(context); })); }).toList()); })])), ListTile(leading: const Icon(Icons.settings, color: Colors.grey), title: const Text("Profil & Paramètres"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ParametresPage(monRole: myRole))))]))),
      body: Container(decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(fondEgal), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken))), child: ChatWidget(nomDuJeu: salonActuel, onChangeSalon: (nouveauSalon) { setState(() { salonActuel = nouveauSalon; customBg = ""; if (!tousLesSalons.contains(salonActuel)) tousLesSalons.add(salonActuel); }); }, monPseudoGeneral: monPseudoGeneral)),
    );
  }
}

// --- WIDGET CHAT ---
class ChatWidget extends StatefulWidget { final String nomDuJeu; final String monPseudoGeneral; final Function(String) onChangeSalon; const ChatWidget({super.key, required this.nomDuJeu, required this.onChangeSalon, required this.monPseudoGeneral}); @override State<ChatWidget> createState() => _ChatWidgetState(); }
class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController messageController = TextEditingController(); late stt.SpeechToText _speech; bool _isListening = false;
  String myAvatarUrl = ''; String myRole = 'user'; bool isMuted = false; int myXp = 0; int myCoins = 0; String myColor = 'Cyan'; String myBadge = ''; String? reponseA;
  bool filtreInsultesActif = true; bool isAFK = false; bool isLFG = false; final String myUid = FirebaseAuth.instance.currentUser!.uid;

  @override void initState() { super.initState(); _speech = stt.SpeechToText(); _chargerMesInfos(); }
  Future<void> _chargerMesInfos() async { var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).get(); if (doc.exists) { var d = doc.data()!; setState(() { myAvatarUrl = d['avatar'] ?? ''; myRole = d['role'] ?? 'user'; isMuted = d['isMuted'] ?? false; myXp = d['xp'] ?? 0; myCoins = d['coins'] ?? 0; myColor = d['couleur'] ?? 'Cyan'; myBadge = d['badge'] ?? ''; filtreInsultesActif = d['filtreInsultes'] ?? true; isAFK = d['isAFK'] ?? false; isLFG = d['isLFG'] ?? false; }); } }

  Future<void> envoyerMessage() async {
    if (isMuted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🔇 Tu es muet."))); return; }
    String texte = messageController.text.trim(); if (texte.isEmpty) return; String cmd = texte.toLowerCase(); 
    
    if (cmd == '/help' || cmd == '/commandes') {
      showDialog(context: context, builder: (context) => AlertDialog(title: const Text("📜 Commandes", style: TextStyle(color: Colors.amber)), backgroundColor: Colors.black87, content: const SingleChildScrollView(child: Text("🤖 IA:\n@Shadow [question]\n\n💸 ECONOMIE:\n/daily - Gagne 100 Coins\n/shop - Voir la boutique\n/buy [item]\n/slots [mise]\n/donner @pseudo [x]\n\n💬 FUN:\n/roll - Lancer de dés\n/pileouface\n/sondage [Question]\n/slap @pseudo\n/hug @pseudo\n/sneak [msg]\n/afk [raison]\n\n👑 ADMIN/CREATEUR:\n/annonce [msg]\n/clear", style: TextStyle(color: Colors.white))), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Fermer", style: TextStyle(color: Colors.cyanAccent)))])); messageController.clear(); return;
    }
    if (cmd == '/shop') { showDialog(context: context, builder: (context) => AlertDialog(title: const Text("🛒 Boutique VIP", style: TextStyle(color: Colors.amber)), backgroundColor: Colors.black87, content: const Text("Utilise tes ShadowCoins !\n\n🌈 Couleur 'Rainbow' : 1000 Coins\n(Tape : /buy rainbow)\n\n💎 Badge Diamant VIP : 500 Coins\n(Tape : /buy vip)", style: TextStyle(color: Colors.white)), actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Fermer", style: TextStyle(color: Colors.cyanAccent)))])); messageController.clear(); return; }
    if (cmd == '/buy rainbow') { if (myCoins >= 1000) { myCoins -= 1000; myColor = 'Rainbow'; await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'coins': myCoins, 'couleur': 'Rainbow'}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🌈 Couleur Rainbow débloquée !"))); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fonds insuffisants."))); } messageController.clear(); return; }
    if (cmd == '/buy vip') { if (myCoins >= 500) { myCoins -= 500; myBadge = '💎'; await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'coins': myCoins, 'badge': '💎'}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("💎 Badge VIP débloqué !"))); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fonds insuffisants."))); } messageController.clear(); return; }
    
    var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).get();
    if (cmd == '/daily') {
      Timestamp? lastD = doc.data()!['lastDaily'];
      if (lastD == null || DateTime.now().difference(lastD.toDate()).inHours >= 24) { await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'coins': FieldValue.increment(100), 'lastDaily': FieldValue.serverTimestamp()}); texte = "🎁 A réclamé sa récompense quotidienne de 100 Coins !"; myCoins += 100; } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tu as déjà récupéré ton daily ! Reviens demain."))); return; }
    }

    String pseudoAffiche = widget.monPseudoGeneral; bool isSneak = false;
    if (isAFK && !cmd.startsWith('/afk')) { await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'isAFK': false}); setState(() => isAFK = false); texte = "👋 Est de retour !\n$texte"; }

    if (cmd.startsWith('@shadow ')) { String repBot = "Bip boop... L'IA arrive bientôt. 📦"; if (cmd.contains("fortnite")) repBot = "Astuce Fortnite : Ne néglige jamais la hauteur ! 🏰"; else if (cmd.contains("minecraft")) repBot = "Règle n°1 : Ne jamais creuser droit vers le bas ! 🌋"; Future.delayed(const Duration(seconds: 2), () async { await FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').add({'texte': repBot, 'expediteur': 'ShadowBot 🤖', 'avatar': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/04/ChatGPT_logo.svg/1024px-ChatGPT_logo.svg.png', 'role': 'bot', 'email': 'bot@shadow.local', 'xp': 99999, 'couleur': 'Or', 'likes': [], 'isLFG': false, 'isSneak': false, 'timestamp': FieldValue.serverTimestamp()}); }); }

    // CORRECTION DES COMMANDES MAJUSCULES (En utilisant cmd au lieu de texte)
    if (cmd.startsWith('/sondage ')) { texte = "📊 SONDAGE :\n\n${texte.substring(9).trim()}\n\n(Double-cliquez pour liker si vous êtes d'accord !)"; }
    else if (cmd == '/roulette') { if (Random().nextInt(6) == 0) { texte = "💥 PAN ! S'est pris la balle et est muet pour 1 minute !"; FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'isMuted': true}); setState(() => isMuted = true); Future.delayed(const Duration(minutes: 1), () { FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'isMuted': false}); if(mounted) setState(() => isMuted = false); }); } else { texte = "💨 Clic... A survécu à la roulette russe."; } }
    else if (cmd.startsWith('/slots ')) { int mise = int.tryParse(cmd.substring(7).trim()) ?? 0; if (mise <= 0 || mise > myCoins) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fonds invalides."))); return; } List<String> items = ['🍒', '🍋', '🔔', '💎', '7️⃣']; String r1 = items[Random().nextInt(items.length)]; String r2 = items[Random().nextInt(items.length)]; String r3 = items[Random().nextInt(items.length)]; if (r1 == r2 && r2 == r3) { texte = "🎰 [$r1 $r2 $r3] JACKPOT ! Remporte ${mise*10} Coins !"; myCoins += (mise*10); } else if (r1 == r2 || r2 == r3 || r1 == r3) { texte = "🎰 [$r1 $r2 $r3] Gagne ${mise*2} Coins !"; myCoins += (mise*2); } else { texte = "🎰 [$r1 $r2 $r3] A perdu sa mise."; myCoins -= mise; } await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'coins': myCoins}); }
    else if (cmd.startsWith('/donner ')) { List<String> args = cmd.split(' '); if (args.length == 3 && args[1].startsWith('@')) { int montant = int.tryParse(args[2]) ?? 0; String cible = args[1].substring(1); if (montant > 0 && montant <= myCoins) { var targetSnap = await FirebaseFirestore.instance.collection('utilisateurs').where('pseudos.Général', isEqualTo: cible).get(); if (targetSnap.docs.isNotEmpty) { await FirebaseFirestore.instance.collection('utilisateurs').doc(targetSnap.docs.first.id).update({'coins': FieldValue.increment(montant)}); myCoins -= montant; await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'coins': myCoins}); texte = "💸 A donné $montant Coins à $cible !"; } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joueur introuvable."))); return; } } else { return; } } }
    else if (cmd.startsWith('/')) {
      if (cmd == '/tableflip') { texte = "(╯°□°）╯︵ ┻━┻"; } 
      else if (cmd == '/shrug') { texte = "¯\\_(ツ)_/¯"; }
      else if (cmd == '/roll') { texte = "🎲 A lancé les dés et a fait un ${Random().nextInt(100) + 1} !"; } // REPARE
      else if (cmd == '/pileouface') { texte = "🪙 La pièce tombe sur ${Random().nextBool() ? 'Pile' : 'Face'} !"; } // REPARE
      else if (cmd.startsWith('/sneak ')) { texte = texte.substring(7); isSneak = true; pseudoAffiche = "🕵️ Inconnu"; }
      else if (cmd.startsWith('/me ')) { texte = "🎭 $pseudoAffiche ${texte.substring(4)}"; }
      else if (cmd.startsWith('/8ball ')) { List<String> reps = ["C'est certain.", "Sans aucun doute.", "Très probable.", "Demande plus tard.", "Ne compte pas dessus.", "Ma source dit non.", "Très douteux."]; texte = "🎱 ${reps[Random().nextInt(reps.length)]}"; }
      else if (cmd.startsWith('/slap ')) { texte = "💥 a giflé violemment ${texte.substring(6).trim()} !"; }
      else if (cmd == '/clear' && (myRole == 'admin' || myRole == 'createur')) { texte = "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n🧹 LE CHAT A ÉTÉ NETTOYÉ PAR LA MODÉRATION 🧹"; }
      else if (cmd.startsWith('/annonce ') && (myRole == 'admin' || myRole == 'createur')) { texte = "📢 ANNONCE : ${texte.substring(9).trim()}"; }
      else if (!cmd.startsWith('/afk') && cmd != '/daily') { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Commande inconnue."))); return; }
    }

    if (doc.exists && !isSneak) pseudoAffiche = doc.data()!['pseudos']?[widget.nomDuJeu] ?? widget.monPseudoGeneral;
    await FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').add({'texte': texte, 'expediteur': pseudoAffiche, 'avatar': isSneak ? '' : myAvatarUrl, 'role': isSneak ? 'user' : myRole, 'email': FirebaseAuth.instance.currentUser!.email, 'xp': isSneak ? 0 : myXp, 'couleur': myColor, 'badge': myBadge, 'replyTo': reponseA, 'likes': [], 'isLFG': isLFG, 'isSneak': isSneak, 'timestamp': FieldValue.serverTimestamp()});
    await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'xp': FieldValue.increment(10), 'coins': FieldValue.increment(5)});
    setState(() { reponseA = null; myXp += 10; myCoins += 5; }); messageController.clear();
  }

  void likerMessage(String msgId, List currentLikes) { if (currentLikes.contains(myUid)) currentLikes.remove(myUid); else currentLikes.add(myUid); FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').doc(msgId).update({'likes': currentLikes}); }
  void actionMessage(String msgId, String texte, bool isMe, String auteur) { showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Action"), actions: [TextButton(onPressed: () { setState(() => reponseA = "$auteur : $texte"); Navigator.pop(context); }, child: const Text("Répondre 💬", style: TextStyle(color: Colors.blue))), TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: texte)); Navigator.pop(context); }, child: const Text("Copier", style: TextStyle(color: Colors.white))), if (isMe || myRole == 'admin' || myRole == 'createur' || myRole == 'modo') TextButton(onPressed: () async { await FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').doc(msgId).delete(); Navigator.pop(context); }, child: const Text("Supprimer", style: TextStyle(color: Colors.red))),])); }

  Widget buildPseudo(String pseudo, String couleur) {
    if (couleur == 'Rainbow') { return ShaderMask(shaderCallback: (bounds) => const LinearGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple]).createShader(bounds), child: Text(pseudo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13))); }
    return Text(pseudo, style: TextStyle(fontWeight: FontWeight.bold, color: getCouleurPseudo(couleur), fontSize: 13));
  }

  Widget buildFormattedText(String text, bool isAction) {
    RegExp imgRegex = RegExp(r'(https?:\/\/[^\s]+(?:\.jpg|\.jpeg|\.png|\.gif))', caseSensitive: false);
    if (imgRegex.hasMatch(text)) { String url = imgRegex.firstMatch(text)!.group(0)!; String cleanText = text.replaceAll(url, '').trim(); return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (cleanText.isNotEmpty) Text(cleanText, style: const TextStyle(fontSize: 16, color: Colors.white)), const SizedBox(height: 5), ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(url, height: 150, fit: BoxFit.cover))]); }
    Color tColor = isAction ? Colors.orangeAccent : Colors.white; 
    if (text.startsWith('> ')) { tColor = Colors.lightGreenAccent; }
    if (text.startsWith('📊 SONDAGE')) { return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.3), borderRadius: BorderRadius.circular(10)), child: Text(text, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold))); }
    return Text(text, style: TextStyle(fontSize: 16, color: tColor, fontStyle: isAction ? FontStyle.italic : FontStyle.normal));
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
              int totalItems = snapshot.data!.docs.length + 1; 

              return ListView.builder(
                reverse: true, itemCount: totalItems,
                itemBuilder: (context, index) {
                  if (index == snapshot.data!.docs.length) {
                    return Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.black87, border: Border.all(color: Colors.cyanAccent), borderRadius: BorderRadius.circular(15)), child: Column(children: [const Icon(Icons.shield, color: Colors.cyanAccent, size: 40), const SizedBox(height: 10), Text("Bienvenue sur ${widget.nomDuJeu.toUpperCase()}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 10), const Text("📝 Règles : Respect, entraide et bon jeu. Pas d'insultes graves ni de spam.", style: TextStyle(color: Colors.white70), textAlign: TextAlign.center), const SizedBox(height: 5), const Text("💡 Info : Tape /help pour voir les commandes secrètes. Chaque message rapporte de l'XP !", style: TextStyle(color: Colors.amber, fontSize: 12), textAlign: TextAlign.center)]));
                  }

                  final msgDoc = snapshot.data!.docs[index]; final msg = msgDoc.data() as Map<String, dynamic>; final bool isMe = msg['email'] == user?.email;
                  String avatarMsg = msg['avatar'] ?? ''; String roleMsg = msg['role'] ?? 'user'; String badgeMsg = msg['badge'] ?? '';
                  int msgXp = msg['xp'] ?? 0; int lvl = (msgXp / 100).floor() + 1; String titreRPG = getTitreNiveau(lvl); 
                  List likes = msg['likes'] ?? []; bool userLFG = msg['isLFG'] ?? false; bool isSneak = msg['isSneak'] ?? false;
                  String timeString = ""; if (msg['timestamp'] != null) { DateTime dt = (msg['timestamp'] as Timestamp).toDate(); timeString = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}"; }

                  String textAAfficher = msg['texte'] ?? "";
                  bool isAction = textAAfficher.startsWith('📢') || textAAfficher.startsWith('🎲') || textAAfficher.startsWith('🪙') || textAAfficher.startsWith('💥') || textAAfficher.startsWith('🫂') || textAAfficher.startsWith('🎭') || textAAfficher.startsWith('💸') || textAAfficher.startsWith('🎰') || textAAfficher.startsWith('🎱') || textAAfficher.startsWith('🎁');
                  if (filtreInsultesActif && !isAction) { textAAfficher = textAAfficher.replaceAll(RegExp(r'(merde|putain|connard|con|salope|fdp|bâtard|tg|gueule)', caseSensitive: false), '***'); }
                  if (textAAfficher.contains('||')) { textAAfficher = textAAfficher.replaceAll(RegExp(r'\|\|(.*?)\|\|'), '[SPOILER CACHÉ]'); }

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: GestureDetector(
                      onLongPress: () => actionMessage(msgDoc.id, msg['texte'] ?? "", isMe, msg['expediteur']), onDoubleTap: () => likerMessage(msgDoc.id, likes), 
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: (isMe && !isSneak) ? Colors.cyanAccent.withOpacity(0.2) : Colors.black87, borderRadius: BorderRadius.circular(15)),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (msg['replyTo'] != null) Container(margin: const EdgeInsets.only(bottom: 5), padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white10, border: const Border(left: BorderSide(color: Colors.cyanAccent, width: 3)), borderRadius: BorderRadius.circular(5)), child: Text(msg['replyTo'], style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if(!isSneak && msg['role'] != 'bot') Text("[Lvl $lvl] ", style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)), 
                                buildPseudo(msg['expediteur'] ?? "", msg['couleur'] ?? 'Cyan'), 
                                if (badgeMsg.isNotEmpty) Text(" $badgeMsg", style: const TextStyle(fontSize: 12)),
                                if (roleMsg == 'createur') const Text(" 🌌", style: TextStyle(fontSize: 12)), 
                                if (roleMsg == 'admin') const Text(" 👑", style: TextStyle(fontSize: 12)), 
                                if (roleMsg == 'modo') const Text(" 🛡️", style: TextStyle(fontSize: 12)), 
                                if(userLFG) const Text(" 🎯", style: TextStyle(fontSize: 12))
                              ]
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isMe && avatarMsg.isNotEmpty) ...[CircleAvatar(backgroundImage: NetworkImage(avatarMsg), radius: 15), const SizedBox(width: 8)],
                                if (!isMe && avatarMsg.isEmpty) ...[const CircleAvatar(backgroundColor: Colors.grey, radius: 15, child: Icon(Icons.person, size: 15, color: Colors.white)), const SizedBox(width: 8)],
                                Flexible(child: buildFormattedText(isAction ? (textAAfficher.startsWith('💥') || textAAfficher.startsWith('🫂') ? "${msg['expediteur']} $textAAfficher" : textAAfficher) : textAAfficher, isAction)),
                                const SizedBox(width: 8), Text(timeString, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                                if (isMe && avatarMsg.isNotEmpty && !isSneak) ...[const SizedBox(width: 8), CircleAvatar(backgroundImage: NetworkImage(avatarMsg), radius: 15)],
                              ],
                            ),
                            if (likes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)), child: Text("❤️ ${likes.length}", style: const TextStyle(fontSize: 12))))
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
        if (reponseA != null) Container(color: Colors.black87, padding: const EdgeInsets.all(8), child: Row(children: [Expanded(child: Text("Réponse à : $reponseA", style: const TextStyle(color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => reponseA = null))])),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [ Expanded(child: TextField(controller: messageController, decoration: InputDecoration(hintText: isMuted ? "🔇 Muet..." : "Message...", filled: true, fillColor: Colors.black87, border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)), enabled: !isMuted)), const SizedBox(width: 8), CircleAvatar(backgroundColor: Colors.cyanAccent, child: IconButton(icon: const Icon(Icons.send, color: Colors.black), onPressed: envoyerMessage)) ])))
      ],
    );
  }
}

// --- RESTAURATION TOTALE DE L'ONGLET AMIS ---
class FriendsPage extends StatefulWidget { const FriendsPage({super.key}); @override State<FriendsPage> createState() => _FriendsPageState(); }
class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController searchController = TextEditingController(); final String myUid = FirebaseAuth.instance.currentUser!.uid;
  Future<void> envoyerDemande() async {
    String search = searchController.text.trim(); if (search.isEmpty) return;
    var query = await FirebaseFirestore.instance.collection('utilisateurs').where('pseudos.Général', isEqualTo: search).get();
    if (query.docs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joueur introuvable !"), backgroundColor: Colors.red)); } 
    else {
      String targetUid = query.docs.first.id;
      if (targetUid == myUid) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tu ne peux pas t'ajouter toi-même !"), backgroundColor: Colors.orange)); return; }
      var myDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).get();
      String monPseudo = myDoc.data()?['pseudos']?['Général'] ?? 'Joueur';
      await FirebaseFirestore.instance.collection('utilisateurs').doc(targetUid).collection('notifications').add({'type': 'ami', 'de': monPseudo, 'uidExpediteur': myUid, 'lu': false, 'timestamp': FieldValue.serverTimestamp()});
      searchController.clear(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Demande envoyée à $search ! 🚀"), backgroundColor: Colors.green));
    }
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mes Amis")),
      body: SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [ Expanded(child: TextField(controller: searchController, decoration: const InputDecoration(hintText: "Pseudo...", border: OutlineInputBorder()))), const SizedBox(width: 8), ElevatedButton(onPressed: envoyerDemande, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, padding: const EdgeInsets.symmetric(vertical: 15)), child: const Text("Ajouter", style: TextStyle(color: Colors.black)))]),),
          const Divider(),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                List<dynamic> mesAmis = (snapshot.data!.data() as Map?)?['amis'] ?? [];
                if (mesAmis.isEmpty) return const Center(child: Text("Aucun ami pour le moment."));
                return ListView.builder(
                  itemCount: mesAmis.length,
                  itemBuilder: (context, index) {
                    return FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance.collection('utilisateurs').where('pseudos.Général', isEqualTo: mesAmis[index]).get(),
                      builder: (context, friendSnap) {
                        bool isOnline = false; bool isAFK = false; bool isLFG = false; String statutPerso = "";
                        if (friendSnap.hasData && friendSnap.data!.docs.isNotEmpty) { 
                          var docData = friendSnap.data!.docs.first.data() as Map<String, dynamic>; 
                          isOnline = docData.containsKey('enLigne') ? docData['enLigne'] == true : false; 
                          isAFK = docData.containsKey('isAFK') ? docData['isAFK'] == true : false; 
                          isLFG = docData.containsKey('isLFG') ? docData['isLFG'] == true : false; 
                          statutPerso = docData.containsKey('statut') ? docData['statut'] : ""; 
                        }
                        String statut = isAFK ? "🌙 AFK" : (isOnline ? "🟢 En ligne" : "⚪ Hors ligne");
                        if (statutPerso.isNotEmpty) statut += " - $statutPerso";
                        return ListTile(leading: const CircleAvatar(backgroundColor: Colors.cyanAccent, child: Icon(Icons.person, color: Colors.black)), title: Row(children: [Text(mesAmis[index], style: const TextStyle(fontWeight: FontWeight.bold)), if(isLFG) const Text(" 🎯", style: TextStyle(fontSize: 14))]), subtitle: Text(statut, style: TextStyle(color: isAFK ? Colors.orange : (isOnline ? Colors.greenAccent : Colors.grey), fontSize: 12)), trailing: const Icon(Icons.chat_bubble, color: Colors.grey), onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => MainScreen(salonInitial: "Privé : ${mesAmis[index]}")), (route) => false));
                      }
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// --- PARAMÈTRES ---
class ParametresPage extends StatefulWidget { final String monRole; const ParametresPage({super.key, required this.monRole}); @override State<ParametresPage> createState() => _ParametresPageState(); }
class _ParametresPageState extends State<ParametresPage> {
  final TextEditingController avatarController = TextEditingController(); final TextEditingController statutController = TextEditingController(); 
  String myColor = 'Cyan'; int myXp = 0; int myCoins = 0; bool filtreActif = true; bool isLFG = false; final user = FirebaseAuth.instance.currentUser;
  
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { var d = await FirebaseFirestore.instance.collection('utilisateurs').doc(user!.uid).get(); setState(() { myColor = d.data()?['couleur'] ?? 'Cyan'; myXp = d.data()?['xp'] ?? 0; myCoins = d.data()?['coins'] ?? 0; avatarController.text = d.data()?['avatar'] ?? ''; statutController.text = d.data()?['statut'] ?? ''; filtreActif = d.data()?['filtreInsultes'] ?? true; isLFG = d.data()?['isLFG'] ?? false; }); }
  Future<void> sauvegarder() async { await FirebaseFirestore.instance.collection('utilisateurs').doc(user!.uid).update({'avatar': avatarController.text.trim(), 'statut': statutController.text.trim(), 'couleur': myColor, 'filtreInsultes': filtreActif, 'isLFG': isLFG}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sauvegardé !"), backgroundColor: Colors.green)); }

  @override Widget build(BuildContext context) {
    int lvl = (myXp / 100).floor() + 1;
    String roleText = widget.monRole == 'createur' ? "🌌 CRÉATEUR DE L'APPLI" : (widget.monRole == 'admin' ? "👑 ADMINISTRATEUR" : (widget.monRole == 'modo' ? "🛡️ MODÉRATEUR" : "GAMER"));

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea( 
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CircleAvatar(radius: 40, backgroundImage: avatarController.text.isNotEmpty ? NetworkImage(avatarController.text) : null, child: avatarController.text.isEmpty ? const Icon(Icons.person, size: 50) : null), const SizedBox(height: 10),
            Center(child: Text(roleText, style: TextStyle(color: widget.monRole == 'createur' ? Colors.purpleAccent : Colors.cyanAccent, fontWeight: FontWeight.bold))),
            Center(child: Text("Niveau $lvl - ${getTitreNiveau(lvl)} ($myXp XP)", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))),
            Center(child: Text("💰 Solde : $myCoins ShadowCoins", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))), const SizedBox(height: 20),
            TextField(controller: statutController, maxLength: 30, decoration: const InputDecoration(labelText: 'Statut (ex: Je mange des pâtes)', prefixIcon: Icon(Icons.bubble_chart))),
            SwitchListTile(title: const Text("🎯 Cherche un groupe (LFG)"), subtitle: const Text("Affiche une cible à côté de ton pseudo.", style: TextStyle(fontSize: 12, color: Colors.grey)), activeColor: Colors.redAccent, value: isLFG, onChanged: (bool val) { setState(() { isLFG = val; }); }),
            SwitchListTile(title: const Text("Filtre Anti-Gros Mots"), subtitle: const Text("Désactive pour voir les insultes en clair.", style: TextStyle(fontSize: 12, color: Colors.grey)), activeColor: Colors.cyanAccent, value: filtreActif, onChanged: (bool val) { setState(() { filtreActif = val; }); }),
            TextField(controller: avatarController, decoration: const InputDecoration(labelText: 'URL Photo', prefixIcon: Icon(Icons.image))), const SizedBox(height: 20),
            DropdownButtonFormField<String>(value: myColor, decoration: const InputDecoration(labelText: "Couleur Pseudo VIP", border: OutlineInputBorder()), items: ['Cyan', 'Rouge', 'Vert', 'Violet', 'Or', 'Rainbow'].map((String val) { return DropdownMenuItem<String>(value: val, child: Text(val, style: TextStyle(color: getCouleurPseudo(val), fontWeight: FontWeight.bold))); }).toList(), onChanged: (v) { setState(() => myColor = v!); }),
            const SizedBox(height: 20), ElevatedButton(onPressed: sauvegarder, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent), child: const Text("SAUVEGARDER", style: TextStyle(color: Colors.black))),
            if (widget.monRole == 'admin' || widget.monRole == 'modo' || widget.monRole == 'createur') ...[const Divider(color: Colors.amber, height: 40), ListTile(leading: const Icon(Icons.gavel, color: Colors.amber), title: const Text('Panneau de Modération', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdminPage(monRole: widget.monRole))))],
            const Divider(height: 40), ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Déconnexion'), onTap: () async { await FirebaseAuth.instance.signOut(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage())); }),
          ],
        ),
      ),
    );
  }
}

// --- LE PANNEAU DE MODERATION (RECHERCHE "TOUS" CORRIGÉE) ---
class AdminPage extends StatefulWidget { final String monRole; const AdminPage({super.key, required this.monRole}); @override State<AdminPage> createState() => _AdminPageState(); }
class _AdminPageState extends State<AdminPage> {
  final TextEditingController rechercheController = TextEditingController();

  Future<QuerySnapshot> getRecherche() {
    String search = rechercheController.text.trim();
    if (search.toLowerCase() == 'tous') { return FirebaseFirestore.instance.collection('utilisateurs').get(); } // TOUS LES JOUEURS
    return FirebaseFirestore.instance.collection('utilisateurs').where('pseudos.Général', isEqualTo: search).get();
  }

  void gererJoueur(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>; String uid = doc.id; String pseudo = data['pseudos']?['Général'] ?? 'Inconnu'; String roleJoueur = data['role'] ?? 'user'; bool isBanni = data['banni'] ?? false; bool isMuted = data['isMuted'] ?? false; String appel = data['messageAppel'] ?? ''; int warns = data['warnings'] ?? 0;
    
    // IMMUNITÉ HIERARCHIQUE
    String myUid = FirebaseAuth.instance.currentUser!.uid;
    if (roleJoueur == 'createur' && uid != myUid) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action impossible : Ce joueur est le Créateur."))); return; }
    if (roleJoueur == 'admin' && widget.monRole != 'createur' && uid != myUid) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action impossible : Ce joueur est un Administrateur."))); return; }

    showModalBottomSheet(context: context, isScrollControlled: true, builder: (context) { 
      return SafeArea( 
        child: Container(
          padding: const EdgeInsets.all(20), color: Colors.black87, 
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Gérer $pseudo", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber)), 
            Text("Avertissements : $warns/3", style: TextStyle(color: warns >= 2 ? Colors.red : Colors.orange)),
            if (appel.isNotEmpty && isBanni) ...[const SizedBox(height: 10), Container(padding: const EdgeInsets.all(10), color: Colors.red.withOpacity(0.2), child: Text("📜 Appel reçu : \"$appel\"", style: const TextStyle(fontStyle: FontStyle.italic)))], 
            const Divider(), 
            
            if (!isBanni) ListTile(leading: const Icon(Icons.warning, color: Colors.orange), title: const Text("Donner un Warn"), onTap: () async {
              if (warns >= 2) { DateTime fin = DateTime.now().add(const Duration(hours: 24)); await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'banni': true, 'causeBan': "3 Avertissements atteints.", 'finBan': Timestamp.fromDate(fin), 'warnings': 0}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Auto-banni (3 warns)."))); } else { await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'warnings': FieldValue.increment(1)}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Avertissement ajouté."))); }
              Navigator.pop(context); setState((){}); 
            }),
            ListTile(leading: Icon(isMuted ? Icons.volume_up : Icons.volume_off, color: Colors.blueAccent), title: Text(isMuted ? "Enlever le Mute" : "Rendre Muet"), onTap: () async { await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'isMuted': !isMuted}); Navigator.pop(context); setState((){}); }), 
            if (isBanni) ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: const Text("Pardonner et Débannir"), onTap: () async { await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'banni': false, 'causeBan': FieldValue.delete(), 'finBan': FieldValue.delete(), 'messageAppel': '', 'warnings': 0}); Navigator.pop(context); setState((){}); }),
            if (!isBanni) ListTile(leading: const Icon(Icons.timer, color: Colors.orange), title: const Text("Bannir (24h)"), onTap: () { Navigator.pop(context); final causeController = TextEditingController(); showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Motif du Ban 24h"), content: TextField(controller: causeController), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")), ElevatedButton(onPressed: () async { DateTime fin = DateTime.now().add(const Duration(hours: 24)); await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'banni': true, 'causeBan': causeController.text.trim(), 'finBan': Timestamp.fromDate(fin)}); Navigator.pop(context); setState((){}); }, child: const Text("BANNIR 24H"))])); }),
            
            if (!isBanni && (widget.monRole == 'admin' || widget.monRole == 'createur')) ListTile(leading: const Icon(Icons.block, color: Colors.red), title: const Text("Bannir Définitivement"), onTap: () { Navigator.pop(context); final causeController = TextEditingController(); showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Motif"), content: TextField(controller: causeController), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'banni': true, 'causeBan': causeController.text.trim()}); Navigator.pop(context); setState((){}); }, child: const Text("BAN PERM"))])); }),

            // GESTION DES ROLES (SEUL LE CREATEUR PEUT NOMMER UN ADMIN)
            if (widget.monRole == 'createur' && roleJoueur != 'createur') ListTile(leading: const Icon(Icons.star, color: Colors.purpleAccent), title: Text(roleJoueur == 'admin' ? "Rétrograder en Joueur" : "Promouvoir Administrateur"), onTap: () async { await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'role': roleJoueur == 'admin' ? 'user' : 'admin'}); Navigator.pop(context); setState((){}); }),
            if ((widget.monRole == 'admin' || widget.monRole == 'createur') && roleJoueur != 'admin' && roleJoueur != 'createur') ListTile(leading: const Icon(Icons.shield, color: Colors.amber), title: Text(roleJoueur == 'modo' ? "Rétrograder en Joueur" : "Promouvoir Modérateur"), onTap: () async { await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'role': roleJoueur == 'modo' ? 'user' : 'modo'}); Navigator.pop(context); setState((){}); }),
          ])
        )
      ); 
    });
  }

  @override Widget build(BuildContext context) { 
    return Scaffold(
      appBar: AppBar(title: const Text('Modération', style: TextStyle(color: Colors.amber))), 
      body: SafeArea(
        child: Column(
          children: [
            Padding(padding: const EdgeInsets.all(16.0), child: TextField(controller: rechercheController, decoration: InputDecoration(labelText: "Pseudo (Tape 'Tous' pour voir tout le monde)", suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() {}))))), 
            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: getRecherche(), 
                builder: (context, snapshot) { 
                  if (rechercheController.text.isEmpty) return const Center(child: Text("Cherche un joueur.")); 
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Joueur introuvable.")); 
                  
                  // AFFICHAGE DE LA LISTE MULTIPLE (POUR LE MOT "TOUS")
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index]; Map<String, dynamic> data = doc.data() as Map<String, dynamic>; 
                      String role = data['role'] ?? 'user'; 
                      String displayRole = role == 'createur' ? '🌌 Créateur' : (role == 'admin' ? '👑 Admin' : (role == 'modo' ? '🛡️ Modo' : 'Gamer'));
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), 
                        child: ListTile(
                          title: Text(data['pseudos']['Général'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), 
                          subtitle: Text("$displayRole\nMute : ${data['isMuted'] == true ? 'Oui' : 'Non'} | Banni : ${data['banni'] == true ? 'Oui' : 'Non'}"), 
                          trailing: const Icon(Icons.settings, color: Colors.cyanAccent), 
                          onTap: () => gererJoueur(doc)
                        )
                      );
                    }
                  );
                }
              )
            )
          ]
        )
      )
    ); 
  }
}
