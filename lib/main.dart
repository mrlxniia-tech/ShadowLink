import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart'; // Nécessite l'ajout dans pubspec.yaml

void main() => runApp(const ShadowLinkApp());

class ShadowLinkApp extends StatelessWidget {
  const ShadowLinkApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      ),
      home: const AuthScreen(),
    );
  }
}

// --- ÉCRAN D'INSCRIPTION ---
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link, size: 80, color: Colors.blueAccent),
            const Text("SHADOWLINK", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 40),
            TextField(decoration: InputDecoration(labelText: "Pseudo", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(obscureText: true, decoration: InputDecoration(labelText: "Mot de passe", border: OutlineInputBorder())),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VoiceDashboard())),
                child: const Text("S'INSCRIRE"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DASHBOARD PRINCIPAL ---
class VoiceDashboard extends StatefulWidget {
  const VoiceDashboard({super.key});
  @override
  State<VoiceDashboard> createState() => _VoiceDashboardState();
}

class _VoiceDashboardState extends State<VoiceDashboard> with SingleTickerProviderStateMixin {
  bool _isPrivate = false;
  List<String> friends = ["Shadow_Master", "Ghost_User"]; // Liste d'amis démo

  void _shareLink() {
    Share.share("Rejoins-moi sur ShadowLink pour discuter en privé ! Mon pseudo : ShadowUser77");
  }

  void _addFriend() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ajouter un ami"),
        content: const TextField(decoration: InputDecoration(hintText: "Pseudo de l'ami")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          TextButton(onPressed: () {
            setState(() => friends.add("Nouvel Ami"));
            Navigator.pop(context);
          }, child: const Text("Ajouter")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isPrivate) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 100, color: Colors.red),
              const Text("SCANNER PRIVÉ ACTIF", style: TextStyle(color: Colors.red, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 50),
              ElevatedButton(onPressed: () => setState(() => _isPrivate = false), child: const Text("QUITTER")),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("SHADOWLINK")),
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(child: Icon(Icons.link, size: 50, color: Colors.blueAccent)),
            ListTile(leading: const Icon(Icons.share), title: const Text("Partager mon lien"), onTap: _shareLink),
            ListTile(leading: const Icon(Icons.person_add), title: const Text("Ajouter un ami"), onTap: _addFriend),
            const Divider(),
            const Padding(padding: EdgeInsets.all(16.0), child: Text("MES AMIS", style: TextStyle(color: Colors.grey))),
            ...friends.map((name) => ListTile(leading: const Icon(Icons.person, size: 20), title: Text(name))).toList(),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic, size: 100, color: Colors.blueAccent),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => setState(() => _isPrivate = true),
              child: const Text("MODE PRIVÉ (SCAN)"),
            ),
          ],
        ),
      ),
    );
  }
}
