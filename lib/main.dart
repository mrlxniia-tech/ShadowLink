import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D12),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black87, elevation: 0),
      ),
      home: FirebaseAuth.instance.currentUser == null ? const LoginPage() : const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- PAGE DE CONNEXION AVEC LOGIQUE DE BAN ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;

  Future<void> seConnecter() async {
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) return;
    try {
      UserCredential userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(), 
        password: passwordController.text.trim()
      );
      
      var doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(userCred.user!.uid).get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // 1. VERIFICATION BAN DEFINITIF
        if (data['banni'] == true) {
          await FirebaseAuth.instance.signOut();
          _alerte("❌ Compte banni définitivement.");
          return;
        }

        // 2. VERIFICATION BAN TEMPORAIRE
        if (data.containsKey('dateFinBan')) {
          DateTime fin = (data['dateFinBan'] as Timestamp).toDate();
          if (fin.isAfter(DateTime.now())) {
            await FirebaseAuth.instance.signOut();
            _alerte("⏳ Accès refusé. Ban fini le : ${fin.day}/${fin.month} à ${fin.hour}h${fin.minute}");
            return;
          }
        }
        
        // 3. AUTO-ADMINISTRATION (Jun & Mrlx)
        String p = data['pseudos']?['Général'] ?? '';
        if (p.toLowerCase() == 'jun' || p.toLowerCase() == 'mrlx') {
          await FirebaseFirestore.instance.collection('utilisateurs').doc(userCred.user!.uid).update({'role': 'admin'});
        }
      }
      
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
    } on FirebaseAuthException catch (e) {
      _alerte("Erreur: ${e.message}");
    }
  }

  void _alerte(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const NetworkImage('https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=2070'), 
            fit: BoxFit.cover, 
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken)
          )
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videogame_asset, size: 80, color: Colors.cyanAccent),
              const Text("SHADOWLINK", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)),
              const SizedBox(height: 30),
              TextField(controller: emailController, decoration: InputDecoration(labelText: 'Email', filled: true, fillColor: Colors.black54, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController, 
                obscureText: _obscurePassword, 
                decoration: InputDecoration(
                  labelText: 'Mot de passe', 
                  filled: true, 
                  fillColor: Colors.black54, 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscurePassword = !_obscurePassword))
                )
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: seConnecter,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text("SE CONNECTER", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- ECRAN PRINCIPAL ---
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SHADOWLINK"),
        actions: [
          // Bouton Admin visible uniquement si role == admin (simplifié ici)
          IconButton(icon: const Icon(Icons.admin_panel_settings), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanel()));
          }),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await FirebaseAuth.instance.signOut();
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
          }),
        ],
      ),
      body: const Center(child: Text("Bienvenue sur ShadowLink", style: TextStyle(fontSize: 20))),
    );
  }
}

// --- PANNEAU D'ADMINISTRATION ---
class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  Future<void> appliquerSanction(String userId, int jours, bool permanent, bool restriction) async {
    Map<String, dynamic> updates = {'estRestreint': restriction};
    
    if (permanent) {
      updates['banni'] = true;
    } else {
      updates['dateFinBan'] = Timestamp.fromDate(DateTime.now().add(Duration(days: jours)));
    }

    await FirebaseFirestore.instance.collection('utilisateurs').doc(userId).update(updates);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CONTRÔLE DES MEMBRES")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('utilisateurs').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var user = snapshot.data!.docs[index];
              var data = user.data() as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(child: Text(data['pseudos']?['Général']?[0] ?? "U")),
                title: Text(data['pseudos']?['Général'] ?? "Inconnu"),
                subtitle: Text(data['estRestreint'] == true ? "🔴 Restreint" : "🟢 Actif"),
                trailing: PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'ban_1d') appliquerSanction(user.id, 1, false, false);
                    if (val == 'ban_7d') appliquerSanction(user.id, 7, false, false);
                    if (val == 'ban_perm') appliquerSanction(user.id, 0, true, false);
                    if (val == 'mute') appliquerSanction(user.id, 0, false, true);
                    if (val == 'unban') {
                      FirebaseFirestore.instance.collection('utilisateurs').doc(user.id).update({'banni': false, 'estRestreint': false, 'dateFinBan': FieldValue.delete()});
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'ban_1d', child: Text("Bannir 24h")),
                    const PopupMenuItem(value: 'ban_7d', child: Text("Bannir 7 jours")),
                    const PopupMenuItem(value: 'ban_perm', child: Text("Bannir Définitif", style: TextStyle(color: Colors.red))),
                    const PopupMenuItem(value: 'mute', child: Text("Restreindre (Mute)")),
                    const PopupMenuItem(value: 'unban', child: Text("Gracier / Libérer", style: TextStyle(color: Colors.green))),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
