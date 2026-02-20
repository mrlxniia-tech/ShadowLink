import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
        scaffoldBackgroundColor: const Color(0xFF121212),
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

  Future<void> seConnecter() async {
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) return;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.message}"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ShadowLink')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gamepad, size: 80, color: Colors.deepPurpleAccent),
            const SizedBox(height: 30),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: seConnecter, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text('Se connecter')),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())),
              child: const Text("Pas de compte ? Créer un profil Gamer", style: TextStyle(color: Colors.deepPurpleAccent)),
            ),
          ],
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

  // MISE A JOUR DES JEUX
  final List<String> listeJeux = ["Call of Duty", "Minecraft", "Roblox", "Fortnite", "Clash Royale", "Ea FC", "Valorant"];
  final Map<String, bool> jeuxCoches = {};
  final Map<String, TextEditingController> pseudosJeux = {};
  bool isChargement = false;

  @override
  void initState() {
    super.initState();
    for (var jeu in listeJeux) {
      jeuxCoches[jeu] = false;
      pseudosJeux[jeu] = TextEditingController();
    }
  }

  Future<void> creerCompte() async {
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty || pseudoGeneralController.text.trim().isEmpty) return;
    setState(() => isChargement = true);
    try {
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      Map<String, String> tousMesPseudos = {"Général": pseudoGeneralController.text.trim()};
      
      for (var jeu in listeJeux) {
        if (jeuxCoches[jeu] == true && pseudosJeux[jeu]!.text.trim().isNotEmpty) {
          tousMesPseudos[jeu] = pseudosJeux[jeu]!.text.trim();
        }
      }

      await FirebaseFirestore.instance.collection('utilisateurs').doc(userCred.user!.uid).set({
        'email': emailController.text.trim(),
        'pseudos': tousMesPseudos,
        'dateCreation': FieldValue.serverTimestamp(),
      });

      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainScreen()), (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur"), backgroundColor: Colors.red));
    } finally {
      setState(() => isChargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Créer ton Profil Gamer")),
      body: isChargement 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()), obscureText: true),
                const SizedBox(height: 10),
                TextField(controller: pseudoGeneralController, decoration: const InputDecoration(labelText: 'Pseudo Principal (Appli)', border: OutlineInputBorder())),
                const SizedBox(height: 30),
                const Text("Tes Jeux (Coche et rentre ton pseudo) :", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
                ...listeJeux.map((jeu) => Column(
                  children: [
                    CheckboxListTile(
                      title: Text(jeu), activeColor: Colors.deepPurpleAccent, value: jeuxCoches[jeu],
                      onChanged: (bool? val) => setState(() => jeuxCoches[jeu] = val ?? false),
                    ),
                    if (jeuxCoches[jeu] == true)
                      Padding(
                        padding: const EdgeInsets.only(left: 40.0, right: 16.0, bottom: 10.0),
                        child: TextField(controller: pseudosJeux[jeu], decoration: InputDecoration(labelText: 'Pseudo sur $jeu', border: const OutlineInputBorder())),
                      )
                  ],
                )).toList(),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: creerCompte, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text('Valider')),
              ],
            ),
          ),
    );
  }
}

// --- ECRAN PRINCIPAL (Menu Latéral + Chat) ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String salonActuel = "Général";
  final List<String> tousLesSalons = ["Général", "Call of Duty", "Minecraft", "Roblox", "Fortnite", "Clash Royale", "Ea FC", "Valorant"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('# $salonActuel'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ParametresPage())))
        ],
      ),
      // LE MENU SUR LE COTÉ
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurpleAccent),
              child: Center(child: Text('Salons', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: tousLesSalons.map((jeu) => ListTile(
                  leading: Icon(jeu == "Général" ? Icons.public : Icons.tag, color: jeu == salonActuel ? Colors.deepPurpleAccent : Colors.grey),
                  title: Text(jeu, style: TextStyle(fontWeight: jeu == salonActuel ? FontWeight.bold : FontWeight.normal)),
                  onTap: () {
                    setState(() => salonActuel = jeu);
                    Navigator.pop(context); // Ferme le menu
                  },
                )).toList(),
              ),
            ),
          ],
        ),
      ),
      body: ChatWidget(nomDuJeu: salonActuel), // Affiche le chat du salon sélectionné
    );
  }
}

// --- LE WIDGET DU CHAT (Intégré dans la page principale) ---
class ChatWidget extends StatefulWidget {
  final String nomDuJeu;
  const ChatWidget({super.key, required this.nomDuJeu});
  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController messageController = TextEditingController();

  Future<void> envoyerMessage() async {
    if (messageController.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String monPseudoActuel = "Joueur";
    try {
      final docUtilisateur = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
      if (docUtilisateur.exists) {
        final datas = docUtilisateur.data()!;
        final mapPseudos = datas['pseudos'] as Map<String, dynamic>?;
        monPseudoActuel = mapPseudos?[widget.nomDuJeu] ?? mapPseudos?['Général'] ?? "Joueur";
      }
    } catch (e) { }

    await FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').add({
      'texte': messageController.text.trim(),
      'expediteur': monPseudoActuel,
      'email': user.email,
      'timestamp': FieldValue.serverTimestamp(),
    });
    messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final messages = snapshot.data!.docs;
              return ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index].data() as Map<String, dynamic>;
                  final bool isMe = msg['email'] == user?.email;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: isMe ? Colors.deepPurpleAccent : Colors.grey[800], borderRadius: BorderRadius.circular(15)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe) Text(msg['expediteur'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 12)),
                          Text(msg['texte'] ?? "", style: const TextStyle(fontSize: 16, color: Colors.white)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(child: TextField(controller: messageController, decoration: InputDecoration(hintText: "Message dans #${widget.nomDuJeu}...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)), contentPadding: const EdgeInsets.symmetric(horizontal: 20)))),
              const SizedBox(width: 8),
              CircleAvatar(backgroundColor: Colors.deepPurpleAccent, child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: envoyerMessage))
            ],
          ),
        ),
      ],
    );
  }
}

// --- PARAMÈTRES ---
class ParametresPage extends StatelessWidget {
  const ParametresPage({super.key});
  Future<void> ouvrirLienMiseAJour(BuildContext context) async {
    final Uri url = Uri.parse('https://github.com/mrlxniia-tech/ShadowLink/actions'); 
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir"), backgroundColor: Colors.red));
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          ListTile(leading: const Icon(Icons.system_update, color: Colors.blue), title: const Text('Mise à jour'), onTap: () => ouvrirLienMiseAJour(context)),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Se déconnecter', style: TextStyle(color: Colors.red)), onTap: () async { await FirebaseAuth.instance.signOut(); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false); }),
        ],
      ),
    );
  }
}
