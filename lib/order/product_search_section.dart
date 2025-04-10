import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';

class ProductSearchSection extends StatelessWidget {
  final TextEditingController controller;
  final Function(Map<String, dynamic>) onProductSelected;

  const ProductSearchSection({
    super.key,
    required this.controller,
    required this.onProductSelected,
  });

  Future<void> _openSearchDialog(BuildContext context) async {
    bool dialogClosed = false;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return Dialog(
          child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('products')
                .where('ownerId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error al cargar productos'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final products = snapshot.data!.docs;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final data = products[index].data() as Map<String, dynamic>;
                  final productId = products[index].id;
                  final name = data['name']?.toString() ?? 'Sin nombre';
                  final price = data['price'] as double? ?? 0.0;
                  final imageUrl = data['imageUrl']?.toString() ?? '';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: imageUrl.isNotEmpty
                          ? NetworkImage(imageUrl)
                          : const AssetImage('assets/placeholder.png') as ImageProvider,
                    ),
                    title: Text('$name (\$$price)'),
                    onTap: () {
                      if (!dialogClosed) {
                        dialogClosed = true;
                        SchedulerBinding.instance.addPostFrameCallback((_) {
                          Navigator.pop(context, {
                            'productId': productId,
                            'name': name,
                            'price': price,
                            'quantity': 1,
                            'imageUrl': imageUrl,
                          });
                        });
                      }
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
    if (result != null) {
      onProductSelected(result);
      controller.text = result['name'];
    }
  }

  // Función para crear un nuevo producto
  Future<void> _createNewProduct(BuildContext context) async {
    final newProduct = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        final TextEditingController nameController = TextEditingController();
        final TextEditingController priceController = TextEditingController();
        final TextEditingController stockController = TextEditingController();
        final GlobalKey<FormState> formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Crear Nuevo Producto'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Ingresa un nombre'
                      : null,
                ),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Precio'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Ingresa un precio'
                      : null,
                ),
                TextFormField(
                  controller: stockController,
                  decoration: const InputDecoration(labelText: 'Stock'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Ingresa el stock'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() != true) return;
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  Navigator.pop(context);
                  return;
                }
                final productData = {
                  'name': nameController.text.trim(),
                  'price': double.tryParse(priceController.text.trim()) ?? 0.0,
                  'stock': int.tryParse(stockController.text.trim()) ?? 0,
                  'ownerId': user.uid,
                  'imageUrl': '',
                  'lastUpdated': FieldValue.serverTimestamp(),
                };
                final docRef = await FirebaseFirestore.instance
                    .collection('products')
                    .add(productData);
                Navigator.pop(context, {
                  'productId': docRef.id,
                  'name': productData['name'],
                  'price': productData['price'],
                  'quantity': 1,
                  'imageUrl': productData['imageUrl'],
                });
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    if (newProduct != null) {
      onProductSelected(newProduct);
      controller.text = newProduct['name'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Buscar Producto',
              prefixIcon: Icon(Icons.search, size: 20),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.search, size: 20),
          onPressed: () => _openSearchDialog(context),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed: () => _createNewProduct(context),
        ),
      ],
    );
  }
}
