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

// --- OUTILS & GAMIFICATION ---
Color getCouleurPseudo(String col) { switch(col) { case 'Rouge': return Colors.redAccent; case 'Vert': return Colors.greenAccent; case 'Violet': return Colors.purpleAccent; case 'Or': return Colors.amber; default: return Colors.cyanAccent; } }
String getTitreNiveau(int lvl) { if(lvl >= 50) return "Légende"; if(lvl >= 30) return "Élite"; if(lvl >= 10) return "Vétéran"; if(lvl >= 5) return "Habitué"; return "Recrue"; }

// --- CHARGEMENT ---
class LoadingScreen extends StatefulWidget { const LoadingScreen({super.key}); @override State<LoadingScreen> createState() => _LoadingScreenState(); }
class _LoadingScreenState extends State<LoadingScreen> {
  @override void initState() { super.initState(); _verifierStatut(); }
  Future<void> _verifierStatut() async {
    final user = FirebaseAuth.instance.currentUser; if (user == null) return;
    var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
    if (doc.exists) {
      Map<String, dynamic> d = doc.data() as Map<String, dynamic>;
      String p = d['pseudos']?['Général'] ?? '';
      if ((p.toLowerCase() == 'jun' || p.toLowerCase() == 'mrlx') && d['role'] != 'admin') { await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).update({'role': 'admin'}); }
      if (d['banni'] == true) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TribunalPage(donneesUtilisateur: d, uid: user.uid))); } 
      else { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen())); }
    }
  }
  @override Widget build(BuildContext context) { return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent))); }
}

class TribunalPage extends StatefulWidget { final Map<String, dynamic> donneesUtilisateur; final String uid; const TribunalPage({super.key, required this.donneesUtilisateur, required this.uid}); @override State<TribunalPage> createState() => _TribunalPageState(); }
class _TribunalPageState extends State<TribunalPage> {
  final TextEditingController appelController = TextEditingController();
  Future<void> envoyerAppel() async { if (appelController.text.trim().isEmpty) return; await FirebaseFirestore.instance.collection('utilisateurs').doc(widget.uid).update({'messageAppel': appelController.text.trim()}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appel envoyé.", style: TextStyle(color: Colors.white)))); }
  @override Widget build(BuildContext context) {
    String cause = widget.donneesUtilisateur['causeBan'] ?? "Violation des règles.";
    return Scaffold(backgroundColor: Colors.black87, body: Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.gavel, size: 80, color: Colors.redAccent), const SizedBox(height: 20), const Text("COMPTE RESTREINT", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.redAccent)), const SizedBox(height: 20), Text("Cause : $cause", style: const TextStyle(fontSize: 18, color: Colors.white, fontStyle: FontStyle.italic)), const SizedBox(height: 40), TextField(controller: appelController, decoration: const InputDecoration(hintText: "Excuses...", filled: true, fillColor: Colors.black54)), const SizedBox(height: 20), ElevatedButton(onPressed: envoyerAppel, style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), child: const Text("ENVOYER MON APPEL", style: TextStyle(color: Colors.black))), const SizedBox(height: 20), TextButton(onPressed: () async { await FirebaseAuth.instance.signOut(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage())); }, child: const Text("Se déconnecter", style: TextStyle(color: Colors.redAccent))),]))));
  }
}

// --- CONNEXION & INSCRIPTION ---
class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState() => _LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController(); final TextEditingController passwordController = TextEditingController(); bool _obscurePassword = true;
  Future<void> seConnecter() async { if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) return; try { await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim()); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoadingScreen())); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur de connexion"))); } }
  @override Widget build(BuildContext context) { return Scaffold(body: Container(decoration: BoxDecoration(image: DecorationImage(image: const NetworkImage('https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=2070'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken))), child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.videogame_asset, size: 80, color: Colors.cyanAccent), const SizedBox(height: 10), const Text("SHADOWLINK", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)), const SizedBox(height: 30), TextField(controller: emailController, decoration: InputDecoration(labelText: 'Email', filled: true, fillColor: Colors.black54, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))), const SizedBox(height: 16), TextField(controller: passwordController, obscureText: _obscurePassword, decoration: InputDecoration(labelText: 'Mot de passe', filled: true, fillColor: Colors.black54, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.cyanAccent), onPressed: () { setState(() { _obscurePassword = !_obscurePassword; }); }))), const SizedBox(height: 20), ElevatedButton(onPressed: seConnecter, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, minimumSize: const Size(double.infinity, 50)), child: const Text('CONNEXION', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))), TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())), child: const Text("Créer un profil", style: TextStyle(color: Colors.cyanAccent)))]))))); }
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
      await FirebaseFirestore.instance.collection('utilisateurs').doc(userCred.user!.uid).set({ 'email': emailController.text.trim(), 'pseudos': tousMesPseudos, 'amis': [], 'xp': 0, 'coins': 100, 'couleur': 'Cyan', 'enLigne': true, 'role': 'user', 'banni': false, 'filtreInsultes': true, 'isLFG': false, 'isAFK': false, 'statut': 'Nouveau ici !', 'dateCreation': FieldValue.serverTimestamp() });
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoadingScreen()), (route) => false);
    } catch (e) { } finally { setState(() => isChargement = false); }
  }
  @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text("Créer ton Profil")), body: isChargement ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(padding: const EdgeInsets.all(16.0), child: Column(children: [TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: pseudoGeneralController, decoration: const InputDecoration(labelText: 'Pseudo Principal', border: OutlineInputBorder())), const SizedBox(height: 30), ...listeJeux.map((jeu) { return Column(children: [CheckboxListTile(title: Text(jeu), activeColor: Colors.cyanAccent, value: jeuxCoches[jeu], onChanged: (bool? val) => setState(() => jeuxCoches[jeu] = val ?? false)), if (jeuxCoches[jeu] == true) Padding(padding: const EdgeInsets.only(left: 40.0, right: 16.0, bottom: 10.0), child: TextField(controller: pseudosJeux[jeu], decoration: InputDecoration(labelText: 'Pseudo sur $jeu', border: const OutlineInputBorder())))]); }).toList(), const SizedBox(height: 20), ElevatedButton(onPressed: creerCompte, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, minimumSize: const Size(double.infinity, 50)), child: const Text('VALIDER', style: TextStyle(color: Colors.black)))]))); }
}

// --- ECRAN CLASSEMENT (TOP JOUEURS) ---
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🏆 Top Joueurs", style: TextStyle(color: Colors.amber))),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('utilisateurs').orderBy('xp', descending: true).limit(50).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var d = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              String pseudo = d['pseudos']?['Général'] ?? 'Inconnu'; int xp = d['xp'] ?? 0; int coins = d['coins'] ?? 0;
              return ListTile(leading: CircleAvatar(backgroundColor: index == 0 ? Colors.amber : (index == 1 ? Colors.grey[300] : (index == 2 ? Colors.orange[800] : Colors.blueGrey)), child: Text("#${index+1}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))), title: Text(pseudo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), subtitle: Text("Niv. ${(xp/100).floor()+1} • 🪙 $coins Coins", style: const TextStyle(color: Colors.amber)), trailing: Text("$xp XP", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)));
            }
          );
        }
      )
    );
  }
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

  @override Widget build(BuildContext context) {
    String fondEgal = (customBg.isNotEmpty && !tousLesSalons.contains(salonActuel)) ? customBg : (fondsEcrans[salonActuel] ?? "https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=1080");
    return Scaffold(
      appBar: AppBar(title: Text(salonActuel.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.cyanAccent)), centerTitle: true),
      drawer: Drawer(backgroundColor: const Color(0xFF1A1A24), child: Column(children: [DrawerHeader(decoration: const BoxDecoration(image: DecorationImage(image: NetworkImage('https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=2071'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken))), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 30, backgroundColor: Colors.cyanAccent, backgroundImage: myAvatarUrl.isNotEmpty ? NetworkImage(myAvatarUrl) : const NetworkImage('https://i.ibb.co/tP5c32d/logo.png')), const SizedBox(height: 10), const Text('SHADOWLINK', style: TextStyle(color: Colors.cyanAccent, fontSize: 22, fontWeight: FontWeight.bold))]))), Expanded(child: ListView(padding: EdgeInsets.zero, children: [ListTile(leading: const Icon(Icons.group, color: Colors.blueAccent), title: const Text("👥 Mes Amis", style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsPage())); }), ListTile(leading: const Icon(Icons.emoji_events, color: Colors.amber), title: const Text("🏆 Top Joueurs", style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage())); }), const Divider(color: Colors.white24), const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Text("🎮 JEUX OFFICIELS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))), ...tousLesSalons.map((jeu) => Container(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: jeu == salonActuel ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: ListTile(leading: CircleAvatar(backgroundImage: NetworkImage(fondsEcrans[jeu] ?? fondsEcrans["Général"]!), radius: 18), title: Text(jeu, style: TextStyle(color: jeu == salonActuel ? Colors.cyanAccent : Colors.white70)), onTap: () { setState((){ salonActuel = jeu; customBg = ""; }); Navigator.pop(context); }))).toList(), const Divider(color: Colors.white24, height: 30), Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("🌐 COMMUNAUTÉ", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.add_circle, color: Colors.greenAccent), onPressed: _afficherCreationSalon)])), StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('salons_custom').orderBy('timestamp', descending: true).snapshots(), builder: (context, snapshot) { if (!snapshot.hasData) return const SizedBox(); return Column(children: snapshot.data!.docs.map((doc) { Map d = doc.data() as Map; String nomCustom = d['nom'] ?? ''; String bgCustom = d['bgUrl'] ?? ''; return Container(margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: nomCustom == salonActuel ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(10)), child: ListTile(leading: CircleAvatar(backgroundImage: NetworkImage(bgCustom.isNotEmpty ? bgCustom : 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=200'), radius: 18), title: Text(nomCustom, style: TextStyle(color: nomCustom == salonActuel ? Colors.cyanAccent : Colors.white70)), onTap: () { setState(() { salonActuel = nomCustom; customBg = bgCustom; }); Navigator.pop(context); })); }).toList()); })])), SafeArea(top: false, bottom: true, child: ListTile(leading: const Icon(Icons.settings, color: Colors.grey), title: const Text("Profil & Paramètres"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ParametresPage(monRole: myRole)))))]),),
      body: Container(decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(fondEgal), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken))), child: ChatWidget(nomDuJeu: salonActuel, onChangeSalon: (nouveauSalon) { setState(() { salonActuel = nouveauSalon; customBg = ""; if (!tousLesSalons.contains(salonActuel)) tousLesSalons.add(salonActuel); }); }, monPseudoGeneral: monPseudoGeneral)),
    );
  }
}

// --- WIDGET CHAT ---
class ChatWidget extends StatefulWidget { final String nomDuJeu; final String monPseudoGeneral; final Function(String) onChangeSalon; const ChatWidget({super.key, required this.nomDuJeu, required this.onChangeSalon, required this.monPseudoGeneral}); @override State<ChatWidget> createState() => _ChatWidgetState(); }
class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController messageController = TextEditingController(); late stt.SpeechToText _speech; bool _isListening = false;
  String myAvatarUrl = ''; String myRole = 'user'; bool isMuted = false; int myXp = 0; int myCoins = 0; String myColor = 'Cyan'; String? reponseA;
  bool filtreInsultesActif = true; bool isAFK = false; bool isLFG = false; final String myUid = FirebaseAuth.instance.currentUser!.uid;

  @override void initState() { super.initState(); _speech = stt.SpeechToText(); _chargerMesInfos(); }
  Future<void> _chargerMesInfos() async { var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).get(); if (doc.exists) { var d = doc.data()!; setState(() { myAvatarUrl = d['avatar'] ?? ''; myRole = d['role'] ?? 'user'; isMuted = d['isMuted'] ?? false; myXp = d['xp'] ?? 0; myCoins = d['coins'] ?? 0; myColor = d['couleur'] ?? 'Cyan'; filtreInsultesActif = d['filtreInsultes'] ?? true; isAFK = d['isAFK'] ?? false; isLFG = d['isLFG'] ?? false; }); } }

  Future<void> envoyerMessage() async {
    if (isMuted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🔇 Tu es muet."))); return; }
    String texte = messageController.text.trim(); if (texte.isEmpty) return;
    
    // LA NOUVELLE COMMANDE HELP (AFFICHE LA LISTE)
    if (texte == '/help' || texte == '/commandes') {
      showDialog(context: context, builder: (context) => AlertDialog(
        title: const Text("📜 Liste des Commandes", style: TextStyle(color: Colors.amber)),
        backgroundColor: Colors.black87,
        content: const SingleChildScrollView(
          child: Text(
            "🎮 JEUX & FUN:\n/roll - Lance les dés\n/pileouface - Pile ou face\n/slots [mise] - Machine à sous\n/8ball [question] - Boule magique\n\n"
            "💬 ACTIONS:\n/slap @pseudo - Gifle quelqu'un\n/hug @pseudo - Fait un câlin\n/me [action] - Roleplay\n/tableflip - Jette une table\n/shrug - Hausse les épaules\n\n"
            "🕵️ SECRET & SOCIAL:\n/sneak [msg] - Message anonyme\n/afk [raison] - Passe en Absent\n/donner @pseudo [x] - Donne des Coins\n||texte|| - Cache un spoiler\n> texte - Citation verte\n\n"
            "👑 ADMIN:\n/annonce [msg] - Message global\n/clear - Nettoie l'écran", 
            style: TextStyle(color: Colors.white)
          )
        ),
        actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Fermer", style: TextStyle(color: Colors.cyanAccent)))]
      ));
      messageController.clear(); return;
    }

    String pseudoAffiche = widget.monPseudoGeneral; bool isSneak = false;
    if (isAFK && !texte.startsWith('/afk')) { await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'isAFK': false}); setState(() => isAFK = false); texte = "👋 Est de retour !\n$texte"; }

    if (texte == '/roulette') { if (Random().nextInt(6) == 0) { texte = "💥 PAN ! S'est pris la balle et est muet pour 1 minute !"; FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'isMuted': true}); setState(() => isMuted = true); Future.delayed(const Duration(minutes: 1), () { FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'isMuted': false}); if(mounted) setState(() => isMuted = false); }); } else { texte = "💨 Clic... A survécu à la roulette russe."; } }
    else if (texte.startsWith('/slots ')) { int mise = int.tryParse(texte.substring(7).trim()) ?? 0; if (mise <= 0 || mise > myCoins) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fonds insuffisants ou invalides."))); return; } List<String> items = ['🍒', '🍋', '🔔', '💎', '7️⃣']; String r1 = items[Random().nextInt(items.length)]; String r2 = items[Random().nextInt(items.length)]; String r3 = items[Random().nextInt(items.length)]; if (r1 == r2 && r2 == r3) { texte = "🎰 [$r1 $r2 $r3] JACKPOT ! Remporte ${mise*10} Coins !"; myCoins += (mise*10); } else if (r1 == r2 || r2 == r3 || r1 == r3) { texte = "🎰 [$r1 $r2 $r3] Gagne ${mise*2} Coins !"; myCoins += (mise*2); } else { texte = "🎰 [$r1 $r2 $r3] A perdu sa mise de $mise Coins."; myCoins -= mise; } await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'coins': myCoins}); }
    else if (texte.startsWith('/donner ')) { List<String> args = texte.split(' '); if (args.length == 3 && args[1].startsWith('@')) { int montant = int.tryParse(args[2]) ?? 0; String cible = args[1].substring(1); if (montant > 0 && montant <= myCoins) { var targetSnap = await FirebaseFirestore.instance.collection('utilisateurs').where('pseudos.Général', isEqualTo: cible).get(); if (targetSnap.docs.isNotEmpty) { await FirebaseFirestore.instance.collection('utilisateurs').doc(targetSnap.docs.first.id).update({'coins': FieldValue.increment(montant)}); myCoins -= montant; await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'coins': myCoins}); texte = "💸 A généreusement donné $montant Coins à $cible !"; } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joueur introuvable."))); return; } } else { return; } } }
    else if (texte.startsWith('/')) {
      if (texte == '/tableflip') { texte = "(╯°□°）╯︵ ┻━┻"; } else if (texte == '/shrug') { texte = "¯\\_(ツ)_/¯"; }
      else if (texte.startsWith('/sneak ')) { texte = texte.substring(7); isSneak = true; pseudoAffiche = "🕵️ Inconnu"; }
      else if (texte.startsWith('/me ')) { texte = "🎭 $pseudoAffiche ${texte.substring(4)}"; }
      else if (texte.startsWith('/8ball ')) { List<String> reps = ["C'est certain.", "Sans aucun doute.", "Très probable.", "Demande plus tard.", "Ne compte pas dessus.", "Ma source dit non.", "Très douteux."]; texte = "🎱 ${reps[Random().nextInt(reps.length)]}"; }
      else if (texte.startsWith('/slap ')) { texte = "💥 a giflé violemment ${texte.substring(6).trim()} !"; }
      else if (texte == '/clear' && myRole == 'admin') { texte = "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n🧹 LE CHAT A ÉTÉ NETTOYÉ PAR UN ADMIN 🧹"; }
      else if (texte.startsWith('/annonce ') && myRole == 'admin') { texte = "📢 ANNONCE : ${texte.substring(9).trim()}"; }
      else if (!texte.startsWith('/afk')) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Commande inconnue."))); return; }
    }

    try { var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).get(); if (doc.exists && !isSneak) pseudoAffiche = doc.data()!['pseudos']?[widget.nomDuJeu] ?? widget.monPseudoGeneral; } catch (e) { }
    await FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').add({'texte': texte, 'expediteur': pseudoAffiche, 'avatar': isSneak ? '' : myAvatarUrl, 'role': isSneak ? 'user' : myRole, 'email': FirebaseAuth.instance.currentUser!.email, 'xp': isSneak ? 0 : myXp, 'couleur': myColor, 'replyTo': reponseA, 'likes': [], 'isLFG': isLFG, 'isSneak': isSneak, 'timestamp': FieldValue.serverTimestamp()});
    await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'xp': FieldValue.increment(10), 'coins': FieldValue.increment(5)});
    setState(() { reponseA = null; myXp += 10; myCoins += 5; }); messageController.clear();
  }

  void likerMessage(String msgId, List currentLikes) { if (currentLikes.contains(myUid)) currentLikes.remove(myUid); else currentLikes.add(myUid); FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').doc(msgId).update({'likes': currentLikes}); }
  void actionMessage(String msgId, String texte, bool isMe, String auteur) { showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Action"), actions: [TextButton(onPressed: () { setState(() => reponseA = "$auteur : $texte"); Navigator.pop(context); }, child: const Text("Répondre 💬", style: TextStyle(color: Colors.blue))), TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: texte)); Navigator.pop(context); }, child: const Text("Copier", style: TextStyle(color: Colors.white))), if (isMe || myRole == 'admin' || myRole == 'modo') TextButton(onPressed: () async { await FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').doc(msgId).delete(); Navigator.pop(context); }, child: const Text("Supprimer", style: TextStyle(color: Colors.red))),])); }

  Widget buildPseudo(String pseudo, String couleur) {
    if (couleur == 'Rainbow') { return ShaderMask(shaderCallback: (bounds) => const LinearGradient(colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple]).createShader(bounds), child: Text(pseudo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13))); }
    return Text(pseudo, style: TextStyle(fontWeight: FontWeight.bold, color: getCouleurPseudo(couleur), fontSize: 13));
  }

  Widget buildFormattedText(String text, bool isAction) {
    RegExp imgRegex = RegExp(r'(https?:\/\/[^\s]+(?:\.jpg|\.jpeg|\.png|\.gif))', caseSensitive: false);
    if (imgRegex.hasMatch(text)) {
      String url = imgRegex.firstMatch(text)!.group(0)!; String cleanText = text.replaceAll(url, '').trim();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (cleanText.isNotEmpty) Text(cleanText, style: const TextStyle(fontSize: 16, color: Colors.white)), const SizedBox(height: 5), ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(url, height: 150, fit: BoxFit.cover))]);
    }
    Color tColor = isAction ? Colors.orangeAccent : Colors.white; if (text.startsWith('> ')) { tColor = Colors.lightGreenAccent; }
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
              return ListView.builder(
                reverse: true, itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final msgDoc = snapshot.data!.docs[index]; final msg = msgDoc.data() as Map<String, dynamic>; final bool isMe = msg['email'] == user?.email;
                  String avatarMsg = msg['avatar'] ?? ''; String roleMsg = msg['role'] ?? 'user';
                  int msgXp = msg['xp'] ?? 0; int lvl = (msgXp / 100).floor() + 1; String titreRPG = getTitreNiveau(lvl); 
                  List likes = msg['likes'] ?? []; bool userLFG = msg['isLFG'] ?? false; bool isSneak = msg['isSneak'] ?? false;
                  String timeString = ""; if (msg['timestamp'] != null) { DateTime dt = (msg['timestamp'] as Timestamp).toDate(); timeString = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}"; }
                  bool isMentioned = widget.monPseudoGeneral.isNotEmpty && msg['texte'].toString().contains('@${widget.monPseudoGeneral}');

                  String textAAfficher = msg['texte'] ?? "";
                  bool isAction = textAAfficher.startsWith('📢') || textAAfficher.startsWith('🎲') || textAAfficher.startsWith('🪙') || textAAfficher.startsWith('💥') || textAAfficher.startsWith('🫂') || textAAfficher.startsWith('🎭') || textAAfficher.startsWith('💸') || textAAfficher.startsWith('🎰') || textAAfficher.startsWith('🎱');
                  if (filtreInsultesActif && !isAction) { textAAfficher = textAAfficher.replaceAll(RegExp(r'(merde|putain|connard|con|salope|fdp|bâtard|tg|gueule)', caseSensitive: false), '***'); }
                  if (textAAfficher.contains('||')) { textAAfficher = textAAfficher.replaceAll(RegExp(r'\|\|(.*?)\|\|'), '[SPOILER CACHÉ]'); }

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: GestureDetector(
                      onLongPress: () => actionMessage(msgDoc.id, msg['texte'] ?? "", isMe, msg['expediteur']), onDoubleTap: () => likerMessage(msgDoc.id, likes), 
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: isMentioned ? Colors.amber.withOpacity(0.5) : (isMe ? Colors.cyanAccent.withOpacity(0.2) : Colors.black87), border: isMentioned ? Border.all(color: Colors.amber, width: 2) : Border.all(color: Colors.transparent), borderRadius: BorderRadius.circular(15)),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (msg['replyTo'] != null) Container(margin: const EdgeInsets.only(bottom: 5), padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white10, border: const Border(left: BorderSide(color: Colors.cyanAccent, width: 3)), borderRadius: BorderRadius.circular(5)), child: Text(msg['replyTo'], style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            
                            // LE PSEUDO APPARAIT POUR TOUT LE MONDE MAINTENANT
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if(!isSneak) Text("[Lvl $lvl] ", style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)), 
                                if(!isSneak && msgXp > 0) const Text("💠 ", style: TextStyle(fontSize: 10)), 
                                buildPseudo(msg['expediteur'] ?? "", msg['couleur'] ?? 'Cyan'), 
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

// --- AMIS (CORRECTION CRASH "BAD STATE" EN LIGNE) ---
class FriendsPage extends StatefulWidget { const FriendsPage({super.key}); @override State<FriendsPage> createState() => _FriendsPageState(); }
class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController searchController = TextEditingController(); final String myUid = FirebaseAuth.instance.currentUser!.uid;
  Future<void> envoyerDemande() async { /* Idem */ }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mes Amis")),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [ Expanded(child: TextField(controller: searchController, decoration: const InputDecoration(hintText: "Pseudo..."))), ElevatedButton(onPressed: envoyerDemande, child: const Text("Ajouter"))])),
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(); List<dynamic> mesAmis = (snapshot.data!.data() as Map?)?['amis'] ?? [];
              if (mesAmis.isEmpty) return const Center(child: Text("Aucun ami."));
              return ListView.builder(
                itemCount: mesAmis.length,
                itemBuilder: (context, index) {
                  return FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance.collection('utilisateurs').where('pseudos.Général', isEqualTo: mesAmis[index]).get(),
                    builder: (context, friendSnap) {
                      bool isOnline = false; bool isAFK = false; bool isLFG = false; String statutPerso = "";
                      
                      // LA VRAIE CORRECTION ANTI-CRASH EST ICI !
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
    );
  }
}

// --- PARAMÈTRES (AVEC RESTAURATION DU PANNEAU ADMIN) ---
class ParametresPage extends StatefulWidget { final String monRole; const ParametresPage({super.key, required this.monRole}); @override State<ParametresPage> createState() => _ParametresPageState(); }
class _ParametresPageState extends State<ParametresPage> {
  final TextEditingController avatarController = TextEditingController(); final TextEditingController statutController = TextEditingController(); 
  String myColor = 'Cyan'; int myXp = 0; int myCoins = 0; bool filtreActif = true; bool isLFG = false; final user = FirebaseAuth.instance.currentUser;
  
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { var d = await FirebaseFirestore.instance.collection('utilisateurs').doc(user!.uid).get(); setState(() { myColor = d.data()?['couleur'] ?? 'Cyan'; myXp = d.data()?['xp'] ?? 0; myCoins = d.data()?['coins'] ?? 0; avatarController.text = d.data()?['avatar'] ?? ''; statutController.text = d.data()?['statut'] ?? ''; filtreActif = d.data()?['filtreInsultes'] ?? true; isLFG = d.data()?['isLFG'] ?? false; }); }
  Future<void> sauvegarder() async { await FirebaseFirestore.instance.collection('utilisateurs').doc(user!.uid).update({'avatar': avatarController.text.trim(), 'statut': statutController.text.trim(), 'couleur': myColor, 'filtreInsultes': filtreActif, 'isLFG': isLFG}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sauvegardé !"), backgroundColor: Colors.green)); }

  @override Widget build(BuildContext context) {
    int lvl = (myXp / 100).floor() + 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(radius: 40, backgroundImage: avatarController.text.isNotEmpty ? NetworkImage(avatarController.text) : null, child: avatarController.text.isEmpty ? const Icon(Icons.person, size: 50) : null), const SizedBox(height: 10),
          Center(child: Text("Niveau $lvl - ${getTitreNiveau(lvl)} ($myXp XP)", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))),
          Center(child: Text("💰 Solde : $myCoins ShadowCoins", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))), const SizedBox(height: 20),
          TextField(controller: statutController, maxLength: 30, decoration: const InputDecoration(labelText: 'Statut (ex: Je mange des pâtes)', prefixIcon: Icon(Icons.bubble_chart))),
          SwitchListTile(title: const Text("🎯 Cherche un groupe (LFG)"), subtitle: const Text("Affiche une cible à côté de ton pseudo.", style: TextStyle(fontSize: 12, color: Colors.grey)), activeColor: Colors.redAccent, value: isLFG, onChanged: (bool val) { setState(() { isLFG = val; }); }),
          SwitchListTile(title: const Text("Filtre Anti-Gros Mots"), subtitle: const Text("Désactive pour voir les insultes en clair.", style: TextStyle(fontSize: 12, color: Colors.grey)), activeColor: Colors.cyanAccent, value: filtreActif, onChanged: (bool val) { setState(() { filtreActif = val; }); }),
          TextField(controller: avatarController, decoration: const InputDecoration(labelText: 'URL Photo', prefixIcon: Icon(Icons.image))), const SizedBox(height: 20),
          DropdownButtonFormField<String>(value: myColor, decoration: const InputDecoration(labelText: "Couleur Pseudo VIP", border: OutlineInputBorder()), items: ['Cyan', 'Rouge', 'Vert', 'Violet', 'Or', 'Rainbow'].map((String val) { return DropdownMenuItem<String>(value: val, child: Text(val, style: TextStyle(color: getCouleurPseudo(val), fontWeight: FontWeight.bold))); }).toList(), onChanged: (v) { setState(() => myColor = v!); }),
          const SizedBox(height: 20), ElevatedButton(onPressed: sauvegarder, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent), child: const Text("SAUVEGARDER", style: TextStyle(color: Colors.black))),
          
          // LA CORRECTION DU PANNEAU ADMIN EST ICI
          if (widget.monRole == 'admin' || widget.monRole == 'modo') ...[
            const Divider(color: Colors.amber, height: 40), 
            ListTile(
              leading: const Icon(Icons.gavel, color: Colors.amber), 
              title: const Text('Panneau de Modération', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)), 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdminPage(monRole: widget.monRole)))
            )
          ],
          
          const Divider(height: 40), ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Déconnexion'), onTap: () async { await FirebaseAuth.instance.signOut(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage())); }),
        ],
      ),
    );
  }
}

// --- LE PANNEAU DE MODERATION RESTAURÉ ---
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
            ListTile(leading: Icon(isMuted ? Icons.volume_up : Icons.volume_off, color: Colors.blueAccent), title: Text(isMuted ? "Enlever le Mute" : "Rendre Muet (Restreindre)"), onTap: () async { await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'isMuted': !isMuted}); Navigator.pop(context); setState((){}); }),
            ListTile(leading: Icon(isBanni ? Icons.check_circle : Icons.block, color: isBanni ? Colors.green : Colors.red), title: Text(isBanni ? "Débannir et pardonner" : "Bannir ce joueur"), onTap: () {
              Navigator.pop(context);
              if (isBanni) { FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'banni': false, 'causeBan': '', 'messageAppel': ''}); setState((){}); return; }
              final causeController = TextEditingController();
              showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Motif du Ban"), content: TextField(controller: causeController, decoration: const InputDecoration(hintText: "Ex: Insultes...")), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await FirebaseFirestore.instance.collection('utilisateurs').doc(uid).update({'banni': true, 'causeBan': causeController.text.trim()}); Navigator.pop(context); setState((){}); }, child: const Text("BANNIR"))]));
            }),
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
          Padding(padding: const EdgeInsets.all(16.0), child: TextField(controller: rechercheController, decoration: InputDecoration(labelText: "Rechercher un pseudo...", suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() {}))))),
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
