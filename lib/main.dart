import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ShadowLinkApp());
}

class ShadowLinkApp extends StatelessWidget {
  const ShadowLinkApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      // L'appli vérifie si tu es déjà connecté ou non
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) return const MainHub();
          return const LoginScreen();
        },
      ),
    );
  }
}

// --- ÉCRAN D'INSCRIPTION RÉELLE ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _register() async {
    try {
      // Création du compte dans Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // Création automatique du "Dossier" de l'utilisateur dans Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'email': _emailController.text,
        'created_at': DateTime.now(),
        'pseudos_jeux': {}, // Dossier vide prêt à être rempli
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("SHADOWLINK", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Mot de passe"), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _register, child: const Text("CRÉER MON COMPTE")),
          ],
        ),
      ),
    );
  }
}

// --- LE HUB AVEC LES DOSSIERS DE JEUX ---
class MainHub extends StatelessWidget {
  const MainHub({super.key});

  @override
  Widget build(BuildContext context) {
    final List<String> jeux = ["Fortnite", "GTA V", "PUBG", "Valorant", "Roblox", "FIFA"];

    return Scaffold(
      appBar: AppBar(title: const Text("MES JEUX"), actions: [
        IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))
      ]),
      body: GridView.builder(
        padding: const EdgeInsets.all(15),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: jeux.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _ouvrirDossierJeu(context, jeux[index]),
            child: Container(
              decoration: BoxDecoration(color: Colors.blueGrey.shade900, borderRadius: BorderRadius.circular(15)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder, size: 50, color: Colors.orangeAccent),
                  const SizedBox(height: 10),
                  Text(jeux[index], style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _ouvrirDossierJeu(BuildContext context, String nomJeu) {
    // Ici on pourra ajouter la page spécifique pour chaque jeu
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 200,
        child: Center(child: Text("Dossier $nomJeu : Connecte ton pseudo ici")),
      ),
    );
  }
}
