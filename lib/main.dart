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
        scaffoldBackgroundColor: const Color(0xFF121212), // Fond bien sombre
      ),
      home: FirebaseAuth.instance.currentUser == null ? const LoginPage() : const HomePage(),
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
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Remplis tous les champs."), backgroundColor: Colors.orange));
      return;
    }
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
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
            const SizedBox(height: 16),
            // NOUVEAU: Le bouton renvoie vers la vraie page d'inscription !
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())),
              child: const Text("Pas de compte ? Créer un profil Gamer", style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- NOUVELLE PAGE D'INSCRIPTION AVANCÉE ---
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController pseudoGeneralController = TextEditingController();

  final List<String> listeJeux = ["Call of Duty", "Minecraft", "Roblox", "Fortnite", "Clash Royale", "EA FC 24"];
  final Map<String, bool> jeuxCoches = {};
  final Map<String, TextEditingController> pseudosJeux = {};

  bool isChargement = false;

  @override
  void initState() {
    super.initState();
    // On prépare les cases à cocher et les champs de texte pour chaque jeu
    for (var jeu in listeJeux) {
      jeuxCoches[jeu] = false;
      pseudosJeux[jeu] = TextEditingController();
    }
  }

  Future<void> creerCompte() async {
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty || pseudoGeneralController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email, mot de passe et Pseudo Principal obligatoires."), backgroundColor: Colors.orange));
      return;
    }

    setState(() => isChargement = true);

    try {
      // 1. Création du compte Firebase Auth
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // 2. Préparation du dictionnaire de tous ses pseudos
      Map<String, String> tousMesPseudos = {
        "Général": pseudoGeneralController.text.trim()
      };
      
      // On ajoute les pseudos spécifiques uniquement pour les jeux cochés
      for (var jeu in listeJeux) {
        if (jeuxCoches[jeu] == true && pseudosJeux[jeu]!.text.trim().isNotEmpty) {
          tousMesPseudos[jeu] = pseudosJeux[jeu]!.text.trim();
        }
      }

      // 3. Sauvegarde du Profil complet dans Firestore
      await FirebaseFirestore.instance.collection('utilisateurs').doc(userCred.user!.uid).set({
        'email': emailController.text.trim(),
        'pseudos': tousMesPseudos,
        'dateCreation': FieldValue.serverTimestamp(),
      });

      // 4. Succès -> Direction l'accueil !
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomePage()), (route) => false);

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.message}"), backgroundColor: Colors.red));
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
        : SingleChildScrollView( // Permet de faire défiler la page si c'est trop long
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tes Identifiants", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
                const SizedBox(height: 10),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 10),
                TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()), obscureText: true),
                const SizedBox(height: 10),
                TextField(controller: pseudoGeneralController, decoration: const InputDecoration(labelText: 'Pseudo Principal (Appli)', border: OutlineInputBorder())),
                const SizedBox(height: 30),

                const Text("À quels jeux joues-tu ?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent)),
                const Text("Coche les jeux et rentre ton pseudo exact dans le jeu.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 10),

                // Génération automatique des cases à cocher pour les jeux
                ...listeJeux.map((jeu) {
                  return Column(
                    children: [
                      CheckboxListTile(
                        title: Text(jeu, style: const TextStyle(fontWeight: FontWeight.bold)),
                        activeColor: Colors.deepPurpleAccent,
                        value: jeuxCoches[jeu],
                        onChanged: (bool? val) {
                          setState(() => jeuxCoches[jeu] = val ?? false);
                        },
                      ),
                      // Si la case est cochée, on affiche le champ pour taper le pseudo
                      if (jeuxCoches[jeu] == true)
                        Padding(
                          padding: const EdgeInsets.only(left: 40.0, right: 16.0, bottom: 10.0),
                          child: TextField(
                            controller: pseudosJeux[jeu],
                            decoration: InputDecoration(
                              labelText: 'Ton pseudo sur $jeu',
                              prefixIcon: const Icon(Icons.person, size: 20),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        )
                    ],
                  );
                }).toList(),

                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: creerCompte,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.deepPurpleAccent),
                  child: const Text('Valider mon profil', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }
}

// --- PAGE D'ACCUEIL ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});
  final List<String> jeux = const ["Général", "Call of Duty", "Minecraft", "Roblox", "Fortnite", "Clash Royale", "EA FC 24"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salons ShadowLink'),
        actions: [IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ParametresPage())))]
      ),
      body: ListView.builder(
        itemCount: jeux.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: const Icon(Icons.tag, color: Colors.deepPurpleAccent),
              title: Text(jeux[index], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(nomDuJeu: jeux[index]))),
            ),
          );
        },
      ),
    );
  }
}

// --- PAGE DE CHAT ---
class ChatPage extends StatefulWidget {
  final String nomDuJeu;
  const ChatPage({super.key, required this.nomDuJeu});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController messageController = TextEditingController();

  Future<void> envoyerMessage() async {
    if (messageController.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String monPseudoActuel = "Joueur";

    // On va chercher dans la base de données le pseudo spécifique à ce jeu !
    try {
      final docUtilisateur = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
      if (docUtilisateur.exists) {
        final datas = docUtilisateur.data()!;
        final mapPseudos = datas['pseudos'] as Map<String, dynamic>?;
        
        // Si le joueur a un pseudo pour CE jeu, on l'utilise. Sinon on utilise le Général.
        monPseudoActuel = mapPseudos?[widget.nomDuJeu] ?? mapPseudos?['Général'] ?? "Joueur";
      }
    } catch (e) {
      monPseudoActuel = "Joueur"; // Sécurité si erreur
    }

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
    return Scaffold(
      appBar: AppBar(title: Text('# ${widget.nomDuJeu}')),
      body: Column(
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
                Expanded(child: TextField(controller: messageController, decoration: InputDecoration(hintText: "Envoyer...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)), contentPadding: const EdgeInsets.symmetric(horizontal: 20)))),
                const SizedBox(width: 8),
                CircleAvatar(backgroundColor: Colors.deepPurpleAccent, child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: envoyerMessage))
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- PAGE DES PARAMÈTRES ---
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
