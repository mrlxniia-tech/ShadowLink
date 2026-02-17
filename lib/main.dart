import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(ShadowLinkApp());

class ShadowLinkApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0E11),
        textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme),
      ),
      home: VoiceDashboard(),
    );
  }
}

class VoiceDashboard extends StatefulWidget {
  @override
  _VoiceDashboardState createState() => _VoiceDashboardState();
}

class _VoiceDashboardState extends State<VoiceDashboard> {
  // --- PARAMÈTRES ---
  bool isPrivate = false;
  String currentFriend = "";
  String lastSpoken = "En attente de voix...";
  final SpeechToText _speech = SpeechToText();
  
  // Ta liste d'amis pour le test
  List<String> squad = ["Sébastien", "Amine", "Julie"];

  @override
  void initState() {
    super.initState();
    _initVoiceSystem();
  }

  void _initVoiceSystem() async {
    bool available = await _speech.initialize();
    if (available) {
      _startListening();
    }
  }

  void _startListening() {
    _speech.listen(
      onResult: (result) {
        setState(() {
          lastSpoken = result.recognizedWords;
          _analyzeVoice(lastSpoken.toLowerCase());
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  void _analyzeVoice(String text) {
    if (!isPrivate) {
      for (var friend in squad) {
        if (text.contains(friend.toLowerCase())) {
          _switchToPrivate(friend);
          break;
        }
      }
    } else {
      // Mot-clé pour quitter la discussion
