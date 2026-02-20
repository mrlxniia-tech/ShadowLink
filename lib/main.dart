import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart'; // Nouvel outil pour les liens

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
      theme: ThemeData(primarySwatch: Colors.blue),
      // Si l'utilisateur est déjà connecté, on l'envoie direct à l'accueil !
      home: FirebaseAuth.instance.currentUser == null ? const LoginPage() : const HomePage(),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Compte créé ! 🚀"), backgroundColor: Colors.green));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.message}"), backgroundColor: Colors.orange));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bienvenue sur ShadowLink')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: seConnecter, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text('Se connecter', style: TextStyle(fontSize: 18))),
            const SizedBox(height: 16),
            TextButton(onPressed: sInscrire, child: const Text("Pas encore de compte ? S'inscrire", style: TextStyle(color: Colors.blueGrey))),
          ],
        ),
      ),
    );
  }
}

// --- PAGE D'ACCUEIL ---
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil ShadowLink'),
        actions: [
          // NOUVEAU : Le bouton Paramètres en haut à droite
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ParametresPage()));
            },
          )
        ],
      ),
      body: const Center(
        child: Text('Bienvenue dans ton espace ! 🚀', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// --- PAGE DES PARAMÈTRES ---
class ParametresPage extends StatelessWidget {
  const ParametresPage({super.key});

  // Fonction qui va ouvrir le navigateur pour télécharger la MAJ
  Future<void> ouvrirLienMiseAJour(BuildContext context) async {
    // Remplacer ce lien par le lien direct de ton APK plus tard
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
          ListTile(
            leading: const Icon(Icons.system_update, color: Colors.blue),
            title: const Text('Mise à jour'),
            subtitle: const Text('Télécharger la dernière version (APK)'),
            onTap: () => ouvrirLienMiseAJour(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Se déconnecter', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              // Retour à la page de connexion en supprimant l'historique des pages
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
            },
          ),
        ],
      ),
    );
  }
}
