/*
  File: register_screen.dart
  Location: lib/screens/register_screen.dart
  Description: Pantalla de registro con diseño futurista para DulceManager.
               Registra al usuario en Firebase Auth y crea un documento en Firestore en la colección 'negocios'
               con 'approved' en false para aprobación manual.
*/

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _errorMessage;

  Future<void> _register() async {
    if (_formKey.currentState?.validate() != true) return;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final String? uid = credential.user?.uid;
      if (uid != null) {
        debugPrint('Creando documento de negocio para el usuario: $uid');
        await _firestore.collection('negocios').doc(uid).set({
          'uid': uid,
          'nombreComercial': 'Nombre por defecto', // Valor inicial, se podrá actualizar luego
          'logoUrl': '',
          'direccion': '',
          'telefono': '',
          'email': _emailController.text.trim(),
          'approved': false, // Queda en estado pendiente
          'fechaRegistro': FieldValue.serverTimestamp(),
        });
        debugPrint('Documento creado correctamente.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro exitoso! Tu cuenta está en revisión.')),
      );
      await _auth.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      debugPrint('Error en registro: ${e.code} - ${e.message}');
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
      // Fondo oscuro futurista
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1F1F1F), Color(0xFF2C2C2C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Card(
              // Se usa withAlpha para evitar advertencias de withOpacity
              color: Colors.black87.withAlpha(204),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const _FuturisticLogoWidget(),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email, color: Colors.cyanAccent),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.black87),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Ingresa tu email';
                          if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) return 'Email no válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock, color: Colors.cyanAccent),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        obscureText: true,
                        style: const TextStyle(color: Colors.black87),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Ingresa una contraseña';
                          if (value.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Registrarse',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: const Text(
                          '¿Ya tienes cuenta? Inicia sesión',
                          style: TextStyle(color: Colors.cyanAccent),
                        ),
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

// Widget para el logo futurista en registro
class _FuturisticLogoWidget extends StatelessWidget {
  const _FuturisticLogoWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.local_cafe, // Puedes ajustar este ícono a uno representativo para repostería
          size: 80,
          color: Colors.cyanAccent,
        ),
        const SizedBox(height: 8),
        const Text(
          'DulceManager',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.cyanAccent,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
