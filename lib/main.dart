import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const ShadowLinkApp());

class ShadowLinkApp extends StatelessWidget {
  const ShadowLinkApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShadowLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
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
            // Affichage du Logo (depuis ton dossier assets)
            Image.asset(
              'assets/images/logo.png',
              height: 120,
              errorBuilder: (context, error, stackTrace) => 
                const Icon(Icons.link, size: 80, color: Colors.blueAccent),
            ),
            const SizedBox(height: 20),
            const Text("SHADOWLINK", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 40),
            const TextField(decoration: InputDecoration(labelText: "Pseudo", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            const TextField(decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder())),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
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
  late AnimationController _scanController;
  List<String> friends = ["Shadow_Master", "Ghost_User"];

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  void _shareLink() {
    Share.share("Rejoins-moi sur ShadowLink ! Mon pseudo : User_77");
  }

  @override
  Widget build(BuildContext context) {
    if (_isPrivate) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Effet Laser Scan
            AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                return Positioned(
                  top: _scanController.value * MediaQuery.of(context).size.height,
                  left: 0, right: 0,
                  child: Container(height: 3, color: Colors.red, boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.8), blurRadius: 10)]),
                );
              },
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, size: 100, color: Colors.red),
                  const Text("SCANNER PRIVÉ", style: TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 50),
                  ElevatedButton(onPressed: () => setState(() => _isPrivate = false), child: const Text("DÉCONNEXION")),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("SHADOWLINK")),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(child: Image.asset('assets/images/logo.png', errorBuilder: (c, e, s) => const Icon(Icons.person, size: 50))),
            ListTile(leading: const Icon(Icons.share), title: const Text("Partager mon lien"), onTap: _shareLink),
            const Divider(),
            const Text("MES AMIS"),
            ...friends.map((name) => ListTile(leading: const Icon(Icons.person_outline), title: Text(name))),
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
              child: const Text("ACTIVER MODE PRIVÉ"),
            ),
          ],
        ),
      ),
    );
  }
}

