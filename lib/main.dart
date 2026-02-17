import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- HUB GAMER SHADOWLINK ---
class GamerProfileScreen extends StatefulWidget {
  const GamerProfileScreen({super.key});
  @override
  State<GamerProfileScreen> createState() => _GamerProfileScreenState();
}

class _GamerProfileScreenState extends State<GamerProfileScreen> {
  // Les jeux avec leurs couleurs thématiques
  final Map<String, Map<String, dynamic>> games = {
    "Fortnite": {"color": Colors.purple, "icon": Icons.auto_awesome},
    "PUBG": {"color": Colors.orange, "icon": Icons.Shield},
    "Valorant": {"color": Colors.redAccent, "icon": Icons.target},
    "Rocket League": {"color": Colors.blue, "icon": Icons.directions_car},
    "GTA V": {"color": Colors.green, "icon": Icons.money},
    "Roblox": {"color": Colors.grey, "icon": Icons.grid_view},
    "FIFA": {"color": Colors.blue.shade900, "icon": Icons.sports_soccer},
  };

  final Map<String, String> _pseudos = {};

  // Fonction pour sauvegarder les pseudos sur ton serveur Firebase
  Future<void> _saveToFirebase() async {
    try {
      // On utilise l'ID unique de l'utilisateur (UID)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('gamers').doc(user.uid).set({
          'pseudos': _pseudos,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil synchronisé avec succès ! 🚀")),
        );
      } else {
        // Si pas de compte, on simule une sauvegarde locale pour le test
        print("Sauvegarde locale : $_pseudos");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connectez-vous pour sauvegarder en ligne !")),
        );
      }
    } catch (e) {
      print("Erreur : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MES COMPTES JEUX"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(onPressed: _saveToFirebase, icon: const Icon(Icons.save, color: Colors.greenAccent))
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(15),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text("Associe tes identifiants pour être retrouvé par la communauté :",
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            ),
            // Génération des cartes de jeux
            ...games.entries.map((entry) => _buildGameCard(entry.key, entry.value["icon"], entry.value["color"])).toList(),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _saveToFirebase,
              child: const Text("METTRE À JOUR MON PROFIL", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(String name, IconData icon, Color color) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 35),
            const SizedBox(width: 15),
            Expanded(
              child: TextField(
                onChanged: (val) => _pseudos[name] = val,
                decoration: InputDecoration(
                  labelText: "Pseudo $name",
                  labelStyle: TextStyle(color: color.withOpacity(0.7)),
                  border: InputBorder.none,
                  hintText: "Ton ID $name...",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

