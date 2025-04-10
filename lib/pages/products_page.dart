import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
    } else {
      _userId = user.uid;
    }
  }

  // Referencia a la colección "products"
  final CollectionReference _productsCollection =
  FirebaseFirestore.instance.collection('products');

  Future<void> _deleteProduct(String productId) async {
    try {
      await _productsCollection.doc(productId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Producto eliminado correctamente")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al eliminar el producto: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Productos'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Se filtra la consulta para mostrar solo los productos cuyo ownerId coincide con el UID del usuario.
        stream: _productsCollection.where('ownerId', isEqualTo: _userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar los productos'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data!.docs;
          if (products.isEmpty) {
            return const Center(child: Text('No hay productos registrados.'));
          }
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final data = products[index].data() as Map<String, dynamic>;
              final productId = products[index].id;
              final name = data['name'] ?? 'Sin nombre';
              final price = data['price'] != null ? data['price'].toString() : '0';
              final stock = data['stock'] != null ? data['stock'].toString() : '0';
              final imageUrl = data['imageUrl'] ?? '';
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: imageUrl.isNotEmpty
                      ? NetworkImage(imageUrl)
                      : const AssetImage('assets/placeholder.png') as ImageProvider,
                ),
                title: Text(name),
                subtitle: Text('Precio: \$ $price - Stock: $stock'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteProduct(productId),
                ),
                onTap: () {
                  Navigator.pushNamed(context, '/productEdit', arguments: productId);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/productEdit');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
