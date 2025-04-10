import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientPage extends StatefulWidget {
  const ClientPage({super.key});

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Si no hay usuario, redirige a login.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
    } else {
      _userId = user.uid;
    }
  }

  // Referencia a la colección "clients"
  final CollectionReference _clientsCollection =
  FirebaseFirestore.instance.collection('clients');

  // Función para eliminar un cliente dado su ID
  Future<void> _deleteClient(String clientId) async {
    try {
      await _clientsCollection.doc(clientId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cliente eliminado correctamente")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al eliminar el cliente: $e")),
      );
    }
  }

  // Función para obtener el conteo de órdenes (compras) de un cliente.
  // Se filtra por 'userId' y 'clientName' para cumplir con las reglas de seguridad.
  Future<int> _getPurchaseCount(String clientName) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: uid)
          .where('clientName', isEqualTo: clientName)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint("Error al contar órdenes para $clientName: $e");
      return 0;
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
        title: const Text('Registro e Historial de Cliente'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Se filtran los documentos para que solo se muestren los que tienen el 'userId' del usuario actual.
        stream: _clientsCollection.where('userId', isEqualTo: _userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar los clientes'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final clients = snapshot.data!.docs;
          if (clients.isEmpty) {
            return const Center(child: Text('No hay clientes registrados.'));
          }
          return ListView.builder(
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final data = clients[index].data() as Map<String, dynamic>;
              final clientId = clients[index].id;
              final name = data['name'] ?? 'Sin nombre';
              final photoUrl = data['photoUrl'] ?? '';
              final phone = data['phone'] ?? '';

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : const AssetImage('assets/placeholder.png') as ImageProvider,
                ),
                title: Text(name),
                // Se utiliza un FutureBuilder para contar las órdenes (compras) de manera dinámica.
                subtitle: FutureBuilder<int>(
                  future: _getPurchaseCount(name),
                  builder: (context, snapshotCount) {
                    String countText = 'Compras: ';
                    if (snapshotCount.hasData) {
                      countText += snapshotCount.data.toString();
                    } else {
                      countText += '...';
                    }
                    if (phone.isNotEmpty) {
                      countText += '  |  Tel: $phone';
                    }
                    return Text(countText);
                  },
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteClient(clientId),
                ),
                onTap: () {
                  Navigator.pushNamed(context, '/clientEdit', arguments: clientId);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/clientEdit');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
