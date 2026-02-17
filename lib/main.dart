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
      title: 'ShadowLink',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.redAccent,
      ),
      // Vérifie si l'utilisateur est déjà connecté
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

// --- ÉCRAN D'ACCÈS (INSCRIPTION / CONNEXION) ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _handleAuth() async {
    try {
      // Tente de créer un compte, si l'email existe, tente de connecter
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link, size: 80, color: Colors.redAccent),
            const Text("SHADOWLINK", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 40),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: "Mot de passe", border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: _handleAuth, 
                child: const Text("SE CONNECTER / S'INSCRIRE", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- LE HUB PRINCIPAL (DOSSIERS DE JEUX) ---
class MainHub extends StatefulWidget {
  const MainHub({super.key});
  @override
  State<MainHub> createState() => _MainHubState();
}

class _MainHubState extends State<MainHub> with SingleTickerProviderStateMixin {
  bool _isPrivate = false;
  late AnimationController _scanController;

  final List<Map<String, dynamic>> jeux = [
    {"name": "Fortnite", "color": Colors.purple, "icon": Icons.auto_awesome},
    {"name": "GTA V", "color": Colors.green, "icon": Icons.money},
    {"name": "Valorant", "color": Colors.red, "icon": Icons.target},
    {"name": "PUBG", "color": Colors.orange, "icon": Icons.shield},
    {"name": "Roblox", "color": Colors.grey, "icon": Icons.grid_view},
    {"name": "FIFA", "color": Colors.blue, "icon": Icons.sports_soccer},
  ];

  @override
  void initState() {
    super.initState();
    _scanController = Animation
