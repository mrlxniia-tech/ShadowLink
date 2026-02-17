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
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();

  Future<void> _auth() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(), password: _pass.text.trim());
    } catch (e) {
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(), password: _pass.text.trim());
      } catch (err) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("SHADOWLINK", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 30),
            TextField(controller: _email, decoration: const InputDecoration(labelText: "Email")),
            TextField(controller: _pass, decoration: const InputDecoration(labelText: "Pass"), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _auth, child: const Text("GO")),
          ],
        ),
      ),
    );
  }
}

class MainHub extends StatefulWidget {
  const MainHub({super.key});
  @override
  State<MainHub> createState() => _MainHubState();
}

class _MainHubState extends State<MainHub> with SingleTickerProviderStateMixin {
  bool _isPrivate = false;
  late AnimationController _ctrl;
  final List<Map<String, dynamic>> jeux = [
    {"n": "Fortnite", "c": Colors.purple, "i": Icons.auto_awesome},
    {"n": "GTA V", "c": Colors.green, "i": Icons.directions_car},
    {"n": "Valorant", "c": Colors.red, "i": Icons.track_changes},
    {"n": "FIFA", "c": Colors.blue, "i": Icons.sports_soccer},
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isPrivate) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => Positioned(
                top: _ctrl.value * MediaQuery.of(context).size.height,
                left: 0, right: 0,
                child: Container(height: 2, color: Colors.red),
              ),
            ),
            Center(child: ElevatedButton(onPressed: () => setState(() => _isPrivate = false), child: const Text("EXIT"))),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("HUB"), actions: [
        IconButton(icon: const Icon(Icons.lock), onPressed: () => setState(() => _isPrivate = true)),
        IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
      ]),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: jeux.length,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _save(jeux[i]['n']),
          child: Container(
            color: Colors.white10,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(jeux[i]['i'], color: jeux[i]['c'], size: 40),
              Text(jeux[i]['n']),
            ]),
          ),
        ),
      ),
    );
  }

  void _save(String g) {
    final t = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(g),
        TextField(controller: t),
        ElevatedButton(onPressed: () async {
          final u = FirebaseAuth.instance.currentUser;
          if (u != null) {
            await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
              'pseudos': {g: t.text}
            }, SetOptions(merge: true));
            Navigator.pop(context);
          }
        }, child: const Text("SAVE")),
      ]),
    ));
  }
}
