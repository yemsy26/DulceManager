// config_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para la configuración del negocio
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _logoUrlController = TextEditingController();

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }

  Future<void> _loadBusinessData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Cargar datos del documento de negocio
    final doc = await FirebaseFirestore.instance.collection('negocios').doc(user.uid).get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        _businessNameController.text = data['nombreComercial'] ?? '';
        _addressController.text = data['direccion'] ?? '';
        _phoneController.text = data['telefono'] ?? '';
        _logoUrlController.text = data['logoUrl'] ?? '';
      });
    }
  }

  // Función para actualizar la configuración del negocio
  Future<void> _updateNegocio() async {
    if (_formKey.currentState?.validate() != true) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('negocios').doc(user.uid).update({
        'nombreComercial': _businessNameController.text.trim(),
        'direccion': _addressController.text.trim(),
        'telefono': _phoneController.text.trim(),
        'logoUrl': _logoUrlController.text.trim(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración del negocio actualizada')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  // Función para cambiar el logo del negocio usando image_picker
  Future<void> _changeLogo() async {
    final ImagePicker picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Seleccionar fuente"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text("Cámara"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text("Galería"),
          ),
        ],
      ),
    );
    if (source == null) return;

    final pickedFile = await picker.pickImage(source: source, maxWidth: 600);
    if (pickedFile == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Subir la imagen a Firebase Storage en "business_logos/UID/UID.jpg"
    final storageRef = FirebaseStorage.instance
        .ref()
        .child("business_logos")
        .child(user.uid)
        .child("${user.uid}.jpg");
    try {
      final uploadTask = storageRef.putFile(File(pickedFile.path));
      final snapshot = await uploadTask.whenComplete(() {});
      final logoUrl = await snapshot.ref.getDownloadURL();
      // Actualizar la URL en Firestore
      await FirebaseFirestore.instance.collection('negocios').doc(user.uid).update({
        'logoUrl': logoUrl,
      });
      setState(() {
        _logoUrlController.text = logoUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo actualizado correctamente')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración - Negocio'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              TextFormField(
                controller: _businessNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del negocio',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa el nombre del negocio';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa la dirección';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa el teléfono';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Mostrar el logo actual o un ícono por defecto
              _logoUrlController.text.isNotEmpty
                  ? Image.network(
                _logoUrlController.text,
                height: 120,
                width: 120,
                fit: BoxFit.cover,
              )
                  : const Icon(
                Icons.image,
                size: 120,
                color: Colors.grey,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _changeLogo,
                icon: const Icon(Icons.camera_alt),
                label: const Text("Cambiar logo"),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _updateNegocio,
                child: const Text('Actualizar Negocio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
