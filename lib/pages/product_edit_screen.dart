import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductEditScreen extends StatefulWidget {
  const ProductEditScreen({super.key});

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  String _imageUrl = '';
  bool _isLoading = false;
  String? _errorMessage;
  String? _productId; // Si se pasa un ID, estamos editando; si no, es nuevo

  final ImagePicker _picker = ImagePicker();

  Future<void> _loadProductData() async {
    if (_productId != null) {
      final doc = await FirebaseFirestore.instance.collection('products').doc(_productId).get();
      final data = doc.data();
      if (data != null) {
        setState(() {
          _nameController.text = data['name'] ?? '';
          _descriptionController.text = data['description'] ?? '';
          _priceController.text = data['price']?.toString() ?? '';
          _categoryController.text = data['category'] ?? '';
          _stockController.text = data['stock']?.toString() ?? '0';
          _imageUrl = data['imageUrl'] ?? '';
        });
      }
    }
  }

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

    final XFile? pickedFile = await _picker.pickImage(source: source, maxWidth: 600);
    if (pickedFile == null) return;

    setState(() {
      _isLoading = true;
    });
    try {
      // Define un nombre para la imagen. Si estamos editando, usamos _productId; de lo contrario, un timestamp.
      final userId = FirebaseAuth.instance.currentUser!.uid; // ← asegura autenticación
      final imageName = _productId ?? DateTime.now().millisecondsSinceEpoch.toString();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child("product_images")
          .child(userId) // ← carpeta del usuario (obligatorio según tus reglas)
          .child("$imageName.jpg");

      await storageRef.putFile(File(pickedFile.path));
      final downloadUrl = await storageRef.getDownloadURL();
      setState(() {
        _imageUrl = downloadUrl;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveProduct() async {
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

    // Agregar el campo ownerId para cumplir con las reglas de seguridad.
    final data = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
      'category': _categoryController.text.trim(),
      'stock': int.tryParse(_stockController.text.trim()) ?? 0,
      'imageUrl': _imageUrl,
      'lastUpdated': FieldValue.serverTimestamp(),
      'ownerId': user.uid,  // Campo obligatorio para la creación y actualización
    };

    final collection = FirebaseFirestore.instance.collection('products');
    try {
      if (_productId == null) {
        // Crear nuevo producto
        await collection.add(data);
      } else {
        // Actualizar producto existente
        await collection.doc(_productId).update(data);
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

  Future<void> _deleteProduct() async {
    if (_productId == null) return;
    setState(() {
      _isLoading = true;
    });
    try {
      await FirebaseFirestore.instance.collection('products').doc(_productId).delete();
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _productId = args;
      _loadProductData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_productId == null ? 'Nuevo Producto' : 'Editar Producto'),
        actions: _productId != null
            ? [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteProduct,
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
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _imageUrl.isNotEmpty
                      ? NetworkImage(_imageUrl)
                      : const AssetImage('assets/placeholder.png') as ImageProvider,
                  child: _imageUrl.isEmpty
                      ? const Icon(Icons.camera_alt, size: 30, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Producto',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa el nombre del producto';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa el precio';
                  if (double.tryParse(value) == null) return 'Ingresa un número válido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(
                  labelText: 'Stock',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Ingresa la cantidad en stock';
                  if (int.tryParse(value) == null) return 'Ingresa un número válido';
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
                  onPressed: _saveProduct,
                  child: const Text('Guardar Producto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
