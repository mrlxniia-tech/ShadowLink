import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NOUVEAU: Base de données

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
        primarySwatch: Colors.deepPurple, // Un petit style plus "Gaming"
        brightness: Brightness.dark,      // Mode sombre par défaut !
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
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.message}"), backgroundColor: Colors.red));
    }
  }

  Future<void> sInscrire() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.message}"), backgroundColor: Colors.orange));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ShadowLink - Connexion')),
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
            ElevatedButton(onPressed: seConnecter, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text('Se connecter', style: TextStyle(fontSize: 18))),
            TextButton(onPressed: sInscrire, child: const Text("Créer un compte")),
          ],
        ),
      ),
    );
  }
}

// --- PAGE D'ACCUEIL (Liste des Salons) ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Ta liste de jeux (tu pourras en ajouter autant que tu veux ici !)
  final List<String> jeux = const [
    "Général",
    "Call of Duty",
    "Minecraft",
    "Roblox",
    "Fortnite",
    "Clash Royale",
    "EA FC 24"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salons ShadowLink'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ParametresPage())),
          )
        ],
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
              onTap: () {
                // Ouvre le chat spécifique à ce jeu
                Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(nomDuJeu: jeux[index])));
              },
            ),
          );
        },
      ),
    );
  }
}

// --- PAGE DE CHAT (Le Discord) ---
class ChatPage extends StatefulWidget {
  final String nomDuJeu;
  const ChatPage({super.key, required this.nomDuJeu});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController messageController = TextEditingController();

  // Fonction pour envoyer un message dans la base de données
  Future<void> envoyerMessage() async {
    if (messageController.text.trim().isEmpty) return; // Ne pas envoyer de message vide

    final user = FirebaseAuth.instance.currentUser;
    final pseudo = user?.email?.split('@')[0] ?? "Joueur Inconnu"; // Pseudo = début de l'email

    await FirebaseFirestore.instance
        .collection('salons')
        .doc(widget.nomDuJeu)
        .collection('messages')
        .add({
      'texte': messageController.text.trim(),
      'expediteur': pseudo,
      'email': user?.email,
      'timestamp': FieldValue.serverTimestamp(), // Heure exacte pour trier
    });

    messageController.clear(); // Vide la case
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text('# ${widget.nomDuJeu}')),
      body: Column(
        children: [
          // 1. La zone d'affichage des messages en temps réel (StreamBuilder)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('salons')
                  .doc(widget.nomDuJeu)
                  .collection('messages')
                  .orderBy('timestamp', descending: true) // Du plus récent au plus ancien
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true, // Pour que la liste commence en bas (comme Discord)
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final bool isMe = msg['email'] == user?.email; // Mon message ou celui d'un autre ?

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.deepPurpleAccent : Colors.grey[800],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe) // Affiche le nom des autres joueurs
                              Text(msg['expediteur'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 12)),
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
          // 2. La barre pour écrire un message en bas
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: "Envoyer un message dans #${widget.nomDuJeu}...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.deepPurpleAccent,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: envoyerMessage,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- PAGE DES PARAMÈTRES (Reste identique) ---
class ParametresPage extends StatelessWidget {
  const ParametresPage({super.key});

  Future<void> ouvrirLienMiseAJour(BuildContext context) async {
    final Uri url = Uri.parse('https://github.com/mrlxniia-tech/ShadowLink/actions'); 
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible d'ouvrir le lien"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          ListTile(leading: const Icon(Icons.system_update, color: Colors.blue), title: const Text('Mise à jour'), subtitle: const Text('Télécharger la dernière version'), onTap: () => ouvrirLienMiseAJour(context)),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Se déconnecter', style: TextStyle(color: Colors.red)), onTap: () async { await FirebaseAuth.instance.signOut(); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false); }),
        ],
      ),
    );
  }
}
