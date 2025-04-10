import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ClientEditScreen extends StatefulWidget {
  const ClientEditScreen({super.key});

  @override
  State<ClientEditScreen> createState() => _ClientEditScreenState();
}

class _ClientEditScreenState extends State<ClientEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(); // Nuevo campo de teléfono
  int _purchaseCount = 0;
  String _photoUrl = '';
  bool _isLoading = false;
  String? _errorMessage;
  String? _clientId; // Se asigna si se recibe un argumento (para editar)

  final ImagePicker _picker = ImagePicker();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Obtener el clientId de los argumentos, si existe.
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _clientId = args;
      _loadClientData();
    }
  }

  Future<void> _loadClientData() async {
    if (_clientId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(_clientId)
          .get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          _nameController.text = data['name'] ?? '';
          _phoneController.text = data['phone'] ?? ''; // Cargar el teléfono si existe
          _photoUrl = data['photoUrl'] ?? '';
          _purchaseCount = data['purchaseCount'] ?? 0;
        });
      }
    }
  }

  // Función para seleccionar imagen (cámara o galería) y subirla a Firebase Storage
  Future<void> _pickImage() async {
    final ImageSource? source = await showDialog<ImageSource>(
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

    final XFile? pickedFile =
    await _picker.pickImage(source: source, maxWidth: 600);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final imageName =
          _clientId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('client_photos')
          .child(userId)                // ← carpeta del usuario
          .child('$imageName.jpg');     // ← nombre de archivo

      print('=== UPLOAD PATH === ${storageRef.fullPath}');

      await storageRef.putFile(File(pickedFile.path));
      final downloadUrl = await storageRef.getDownloadURL();
      setState(() {
        _photoUrl = downloadUrl;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveClient() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = "Usuario no autenticado.";
        _isLoading = false;
      });
      return;
    }

    // Los datos que se enviarán incluyen el campo userId, obligatorio según las reglas.
    final data = {
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(), // Se envía el teléfono, aunque sea opcional.
      'photoUrl': _photoUrl,
      'purchaseCount': _purchaseCount,
      'userId': user.uid, // Campo obligatorio para cumplir las reglas de create.
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    try {
      final collection = FirebaseFirestore.instance.collection('clients');
      if (_clientId == null) {
        // Crear nuevo cliente
        await collection.add(data);
      } else {
        // Actualizar cliente existente
        await collection.doc(_clientId).update(data);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteClient() async {
    if (_clientId == null) return;
    setState(() {
      _isLoading = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(_clientId)
          .delete();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose(); // Se libera el controlador del teléfono
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        Text(_clientId == null ? 'Nuevo Cliente' : 'Editar Cliente'),
        actions: _clientId != null
            ? [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteClient,
          ),
        ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Foto del cliente: al tocar se invoca _pickImage
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _photoUrl.isNotEmpty
                      ? NetworkImage(_photoUrl)
                      : const AssetImage('assets/placeholder.png')
                  as ImageProvider,
                  child: _photoUrl.isEmpty
                      ? const Icon(Icons.camera_alt,
                      size: 30, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Cliente',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Ingresa el nombre del cliente';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Nuevo campo para teléfono (opcional)
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _purchaseCount.toString(),
                decoration: const InputDecoration(
                  labelText: 'Cantidad de Compras',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _purchaseCount = int.tryParse(value) ?? 0;
                  });
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
                  onPressed: _saveClient,
                  child: const Text('Guardar Cliente'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
