/*
  File: login_screen.dart
  Location: lib/screens/login_screen.dart
  Description: Pantalla de login que utiliza Firebase Auth y Cloud Firestore para verificar que el usuario
               tenga su cuenta aprobada antes de acceder. Se incluyen validaciones de formulario y manejo de errores.
*/

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _errorMessage;

  Future<void> _signIn() async {
    if (_formKey.currentState?.validate() != true) return;
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final String? uid = credential.user?.uid;
      if (uid != null) {
        // Verificar si el documento de "negocios" existe
        final docRef = _firestore.collection('negocios').doc(uid);
        final docSnapshot = await docRef.get();
        if (!docSnapshot.exists) {
          // Si no existe, crearlo con valores mínimos (approved: false)
          await docRef.set({
            'uid': uid,
            'nombreComercial': 'Nombre por defecto',
            'logoUrl': '',
            'direccion': '',
            'telefono': '',
            'email': _emailController.text.trim(),
            'approved': false,
            'fechaRegistro': FieldValue.serverTimestamp(),
          });
          debugPrint('Documento de negocio creado automáticamente para el usuario: $uid');
        }
        // Ahora, si el documento existe, se verifica la aprobación.
        final approved = (await docRef.get()).data()?['approved'] ?? false;
        if (approved) {
          debugPrint('Usuario aprobado: $uid');
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          debugPrint('Cuenta en revisión para el usuario: $uid');
          setState(() {
            _errorMessage = 'Tu cuenta está en revisión. Espera la aprobación del administrador.';
          });
          await _auth.signOut();
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Error en inicio de sesión: ${e.code} - ${e.message}');
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e, stack) {
      debugPrint('Error desconocido: $e');
      debugPrint(stack.toString());
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fondo degradado profesional
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEDE7F6), Color(0xFFD1C4E9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _LogoWidget(),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu email';
                          }
                          if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                            return 'Email no válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu contraseña';
                          }
                          if (value.length < 6) {
                            return 'Mínimo 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _signIn,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Iniciar Sesión'),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/register');
                        },
                        child: const Text("¿No tienes cuenta? Regístrate aquí"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Widget para el logo en Login
class _LogoWidget extends StatelessWidget {
  const _LogoWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.cake, // Ícono relacionado con repostería
          size: 80,
          color: Colors.deepPurple.shade400,
        ),
        const SizedBox(height: 8),
        Text(
          'DulceManager',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple.shade700,
          ),
        ),
      ],
    );
  }
}
