import 'package:flutter/material.dart';

void main() {
  runApp(const ShadowLinkApp());
}

class ShadowLinkApp extends StatelessWidget {
  const ShadowLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShadowLink Vocal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const VoiceDashboard(),
    );
  }
}

class VoiceDashboard extends StatefulWidget {
  const VoiceDashboard({super.key});

  @override
  State<VoiceDashboard> createState() => _VoiceDashboardState();
}

class _VoiceDashboardState extends State<VoiceDashboard> {
  String _status = "En attente de commande...";

  // Cette fonction analyse la voix (ton erreur venait d'ici)
  void _analyzeVoice(String text) {
    setState(() {
      if (text.toLowerCase().contains("privé")) {
        _status = "Passage en mode privé...";
        _switchToPrivate();
      } else {
        _status = "Commande : $text";
      }
    });
  }

  // La fonction qui manquait dans tes logs
  void _switchToPrivate() {
    print("Mode privé activé");
    // Ajoute ici ta logique pour le salon privé
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ShadowLink Vocal")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _analyzeVoice("privé"), 
              child: const Text("Tester Commande 'Privé'"),
            ),
          ],
        ),
      ),
    );
  }
} // <--- L'accolade magique qui ferme tout !
