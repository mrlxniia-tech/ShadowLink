import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  // Indispensable pour initialiser Firebase avant de lancer l'app
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
                              theme: ThemeData(primarySwatch: Colors.blue),
                                    home: const LoginPage(),
                                        );
                                          }
                                          }

                                          class LoginPage extends StatelessWidget {
                                            const LoginPage({super.key});

                                              @override
                                                Widget build(BuildContext context) {
                                                    return Scaffold(
                                                          appBar: AppBar(title: const Text('Connexion ShadowLink')),
                                                                body: Center(
                                                                        child: ElevatedButton(
                                                                                  onPressed: () {
                                                                                              // Ici tu ajouteras ta logique de connexion plus tard
                                                                                                          print("Tentative de connexion...");
                                                                                                                    },
                                                                                                                              child: const Text('Se connecter'),
                                                                                                                                      ),
                                                                                                                                            ),
                                                                                                                                                );
                                                                                                                                                  }
                                                                                                                                                  }