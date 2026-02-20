import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
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
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: FirebaseAuth.instance.currentUser == null ? const LoginPage() : const MainScreen(),
      debugShowCheckedModeBanner: false,
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
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) return;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: ${e.message}"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ShadowLink')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gamepad, size: 80, color: Colors.deepPurpleAccent),
            const SizedBox(height: 30),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: seConnecter, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text('Se connecter')),
            TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())),
              child: const Text("Pas de compte ? Créer un profil", style: TextStyle(color: Colors.deepPurpleAccent)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- PAGE D'INSCRIPTION ---
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController pseudoGeneralController = TextEditingController();
  final List<String> listeJeux = ["Call of Duty", "Minecraft", "Roblox", "Fortnite", "Clash Royale", "Ea FC", "Valorant"];
  final Map<String, bool> jeuxCoches = {};
  final Map<String, TextEditingController> pseudosJeux = {};
  bool isChargement = false;

  @override
  void initState() {
    super.initState();
    for (var jeu in listeJeux) {
      jeuxCoches[jeu] = false;
      pseudosJeux[jeu] = TextEditingController();
    }
  }

  Future<void> creerCompte() async {
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty || pseudoGeneralController.text.trim().isEmpty) return;
    setState(() => isChargement = true);
    try {
      UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      Map<String, String> tousMesPseudos = {"Général": pseudoGeneralController.text.trim()};
      for (var jeu in listeJeux) {
        if (jeuxCoches[jeu] == true && pseudosJeux[jeu]!.text.trim().isNotEmpty) {
          tousMesPseudos[jeu] = pseudosJeux[jeu]!.text.trim();
        }
      }
      await FirebaseFirestore.instance.collection('utilisateurs').doc(userCred.user!.uid).set({
        'email': emailController.text.trim(),
        'pseudos': tousMesPseudos,
        'amis': [],
        'dateCreation': FieldValue.serverTimestamp(),
      });
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainScreen()), (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur de création"), backgroundColor: Colors.red));
    } finally {
      setState(() => isChargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Créer ton Profil Gamer")),
      body: isChargement ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()), obscureText: true),
            const SizedBox(height: 10),
            TextField(controller: pseudoGeneralController, decoration: const InputDecoration(labelText: 'Pseudo Principal', border: OutlineInputBorder())),
            const SizedBox(height: 30),
            ...listeJeux.map((jeu) => Column(
              children: [
                CheckboxListTile(title: Text(jeu), activeColor: Colors.deepPurpleAccent, value: jeuxCoches[jeu], onChanged: (bool? val) => setState(() => jeuxCoches[jeu] = val ?? false)),
                if (jeuxCoches[jeu] == true) Padding(padding: const EdgeInsets.only(left: 40.0, right: 16.0, bottom: 10.0), child: TextField(controller: pseudosJeux[jeu], decoration: InputDecoration(labelText: 'Pseudo sur $jeu', border: const OutlineInputBorder())))
              ],
            )).toList(),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: creerCompte, style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), child: const Text('Valider')),
          ],
        ),
      ),
    );
  }
}

// --- ECRAN PRINCIPAL ---
class MainScreen extends StatefulWidget {
  final String salonInitial;
  const MainScreen({super.key, this.salonInitial = "Général"});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late String salonActuel;
  final List<String> tousLesSalons = ["Général", "Call of Duty", "Minecraft", "Roblox", "Fortnite", "Clash Royale", "Ea FC", "Valorant"];
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _texteEcoute = "";
  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    salonActuel = widget.salonInitial;
    if (!tousLesSalons.contains(salonActuel) && !salonActuel.startsWith("Privé")) tousLesSalons.add(salonActuel);
    _speech = stt.SpeechToText();
  }

  void _ecouterAssistant() async {
    if (!_isListening) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) return;
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: 'fr_FR',
          onResult: (val) {
            setState(() => _texteEcoute = val.recognizedWords.toLowerCase());
            if (_texteEcoute.contains("fin")) {
              _speech.stop();
              setState(() => _isListening = false);
              return;
            }
            if (_texteEcoute.contains("mute")) {
              _speech.stop();
              setState(() => _isListening = false);
              return;
            }
            if (_texteEcoute.contains("shadow fait une conversation privée avec")) {
              List<String> mots = _texteEcoute.split("avec");
              if (mots.length > 1) {
                String pseudoJoueur = mots.last.trim();
                _speech.stop();
                setState(() => _isListening = false);
                setState(() {
                  salonActuel = "Privé : $pseudoJoueur";
                  if (!tousLesSalons.contains(salonActuel)) tousLesSalons.add(salonActuel);
                });
              }
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('# $salonActuel'),
        actions: [
          // LA CLOCHE DE NOTIFICATIONS EN TEMPS RÉEL
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).collection('notifications').where('lu', isEqualTo: false).snapshots(),
            builder: (context, snapshot) {
              int notifCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: notifCount > 0,
                  label: Text(notifCount.toString()),
                  child: const Icon(Icons.notifications),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage())),
              );
            },
          )
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            const DrawerHeader(decoration: BoxDecoration(color: Colors.deepPurpleAccent), child: Center(child: Text('ShadowLink', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)))),
            ListTile(leading: const Icon(Icons.group, color: Colors.blueAccent), title: const Text("👥 Mes Amis", style: TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsPage())); }),
            const Divider(),
            Expanded(child: ListView(padding: EdgeInsets.zero, children: tousLesSalons.map((jeu) => ListTile(leading: Icon(jeu.startsWith("Privé") ? Icons.lock : Icons.tag, color: jeu == salonActuel ? Colors.deepPurpleAccent : Colors.grey), title: Text(jeu, style: TextStyle(fontWeight: jeu == salonActuel ? FontWeight.bold : FontWeight.normal)), onTap: () { setState(() => salonActuel = jeu); Navigator.pop(context); })).toList())),
            ListTile(leading: const Icon(Icons.settings), title: const Text("Paramètres"), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ParametresPage())))
          ],
        ),
      ),
      body: ChatWidget(nomDuJeu: salonActuel),
      floatingActionButton: FloatingActionButton(onPressed: _ecouterAssistant, backgroundColor: _isListening ? Colors.red : Colors.deepPurpleAccent, child: Icon(_isListening ? Icons.mic : Icons.mic_none)),
    );
  }
}

// --- LA PAGE DES NOTIFICATIONS ---
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  Future<void> accepterAmi(String myUid, String notifId, String uidDemandeur, String pseudoDemandeur) async {
    // 1. On m'ajoute son pseudo
    await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).update({'amis': FieldValue.arrayUnion([pseudoDemandeur])});
    
    // 2. On récupère mon pseudo à moi pour l'ajouter chez lui
    var myDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).get();
    String monPseudo = myDoc.data()?['pseudos']?['Général'] ?? 'Joueur';
    await FirebaseFirestore.instance.collection('utilisateurs').doc(uidDemandeur).update({'amis': FieldValue.arrayUnion([monPseudo])});

    // 3. On supprime la notif
    await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).collection('notifications').doc(notifId).delete();
  }

  Future<void> refuserAmi(String myUid, String notifId) async {
    await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).collection('notifications').doc(notifId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final String myUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).collection('notifications').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final notifs = snapshot.data!.docs;
          if (notifs.isEmpty) return const Center(child: Text("Aucune notification."));

          return ListView.builder(
            itemCount: notifs.length,
            itemBuilder: (context, index) {
              var notif = notifs[index].data() as Map<String, dynamic>;
              String notifId = notifs[index].id;

              if (notif['type'] == 'ami') {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_add, color: Colors.blueAccent),
                    title: Text("Demande d'ami de ${notif['de']}"),
                    subtitle: Row(
                      children: [
                        TextButton(onPressed: () => accepterAmi(myUid, notifId, notif['uidExpediteur'], notif['de']), child: const Text("Accepter", style: TextStyle(color: Colors.green))),
                        TextButton(onPressed: () => refuserAmi(myUid, notifId), child: const Text("Refuser", style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                );
              } else if (notif['type'] == 'mention') {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.alternate_email, color: Colors.amber),
                    title: Text("${notif['de']} t'a mentionné dans #${notif['salon']}"),
                    subtitle: Text('"${notif['texte']}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                    trailing: IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).collection('notifications').doc(notifId).delete(),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          );
        },
      ),
    );
  }
}

// --- PAGE DES AMIS ---
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});
  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController searchController = TextEditingController();
  final String myUid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> envoyerDemandeAmi() async {
    String search = searchController.text.trim();
    if (search.isEmpty) return;

    var query = await FirebaseFirestore.instance.collection('utilisateurs').where('pseudos.Général', isEqualTo: search).get();
    if (query.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joueur introuvable !"), backgroundColor: Colors.red));
    } else {
      String targetUid = query.docs.first.id;
      if (targetUid == myUid) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tu ne peux pas t'ajouter toi-même !"), backgroundColor: Colors.orange));
        return;
      }
      
      var myDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).get();
      String monPseudo = myDoc.data()?['pseudos']?['Général'] ?? 'Joueur';

      // ON ENVOIE LA NOTIFICATION A L'AUTRE JOUEUR
      await FirebaseFirestore.instance.collection('utilisateurs').doc(targetUid).collection('notifications').add({
         'type': 'ami',
         'de': monPseudo,
         'uidExpediteur': myUid,
         'lu': false,
         'timestamp': FieldValue.serverTimestamp(),
      });
      searchController.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Demande envoyée à $search ! 🚀"), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mes Amis")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: searchController, decoration: const InputDecoration(hintText: "Ajouter un pseudo...", border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: envoyerDemandeAmi, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)), child: const Text("Demander")),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('utilisateurs').doc(myUid).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var data = snapshot.data!.data() as Map<String, dynamic>?;
                List<dynamic> mesAmis = data?['amis'] ?? [];
                if (mesAmis.isEmpty) return const Center(child: Text("Tu n'as pas encore d'amis."));
                return ListView.builder(
                  itemCount: mesAmis.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.person, color: Colors.white)),
                      title: Text(mesAmis[index], style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.chat_bubble, color: Colors.deepPurpleAccent),
                      onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => MainScreen(salonInitial: "Privé : ${mesAmis[index]}")), (route) => false),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET CHAT (Avec mentions !) ---
class ChatWidget extends StatefulWidget {
  final String nomDuJeu;
  const ChatWidget({super.key, required this.nomDuJeu});
  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  final TextEditingController messageController = TextEditingController();

  Future<void> envoyerMessage() async {
    String texte = messageController.text.trim();
    if (texte.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String monPseudoActuel = "Joueur";
    try {
      final docUtilisateur = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
      if (docUtilisateur.exists) {
        final datas = docUtilisateur.data()!;
        final mapPseudos = datas['pseudos'] as Map<String, dynamic>?;
        monPseudoActuel = mapPseudos?[widget.nomDuJeu] ?? mapPseudos?['Général'] ?? "Joueur";
      }
    } catch (e) { }

    // 1. On envoie le message dans le salon
    await FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').add({
      'texte': texte,
      'expediteur': monPseudoActuel,
      'email': user.email,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. DETECTION DES MENTIONS (@Pseudo)
    RegExp exp = RegExp(r'@(\w+)');
    Iterable<RegExpMatch> matches = exp.allMatches(texte);
    for (final m in matches) {
      String mentionedPseudo = m.group(1)!;
      // On cherche si ce joueur existe
      var query = await FirebaseFirestore.instance.collection('utilisateurs').where('pseudos.Général', isEqualTo: mentionedPseudo).get();
      if (query.docs.isNotEmpty) {
        String targetUid = query.docs.first.id;
        if (targetUid != user.uid) {
          // On lui envoie une notification !
          await FirebaseFirestore.instance.collection('utilisateurs').doc(targetUid).collection('notifications').add({
            'type': 'mention',
            'de': monPseudoActuel,
            'salon': widget.nomDuJeu,
            'texte': texte,
            'lu': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('salons').doc(widget.nomDuJeu).collection('messages').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                reverse: true,
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final msg = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final bool isMe = msg['email'] == user?.email;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: isMe ? Colors.deepPurpleAccent : Colors.grey[800], borderRadius: BorderRadius.circular(15)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe) Text(msg['expediteur'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 12)),
                          Text(msg['texte'] ?? "", style: const TextStyle(fontSize: 16, color: Colors.white)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(child: TextField(controller: messageController, decoration: const InputDecoration(hintText: "Message (utilise @Pseudo pour mentionner)...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)), contentPadding: const EdgeInsets.symmetric(horizontal: 20)))),
              CircleAvatar(backgroundColor: Colors.deepPurpleAccent, child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: envoyerMessage))
            ],
          ),
        ),
      ],
    );
  }
}

// --- PARAMÈTRES ---
class ParametresPage extends StatelessWidget {
  const ParametresPage({super.key});
  Future<void> ouvrirLienMiseAJour(BuildContext context) async {
    final Uri url = Uri.parse('https://github.com/mrlxniia-tech/ShadowLink/actions'); 
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur"), backgroundColor: Colors.red));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        children: [
          ListTile(leading: const Icon(Icons.system_update, color: Colors.blue), title: const Text('Mise à jour'), onTap: () => ouvrirLienMiseAJour(context)),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Se déconnecter', style: TextStyle(color: Colors.red)), onTap: () async { await FirebaseAuth.instance.signOut(); Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false); }),
        ],
      ),
    );
  }
}
