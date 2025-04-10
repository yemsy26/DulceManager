import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';

class ClientSearchSection extends StatelessWidget {
  final TextEditingController controller;
  final Function(Map<String, dynamic>) onClientSelected;

  const ClientSearchSection({
    super.key,
    required this.controller,
    required this.onClientSelected,
  });

  Future<void> _openSearchDialog(BuildContext context) async {
    bool dialogClosed = false;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return Dialog(
          child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('clients')
                .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error al cargar clientes'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final clients = snapshot.data!.docs;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: clients.length,
                itemBuilder: (context, index) {
                  final data = clients[index].data() as Map<String, dynamic>;
                  final clientId = clients[index].id;
                  final name = data['name']?.toString() ?? 'Sin nombre';
                  final photoUrl = data['photoUrl']?.toString() ?? '';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : const AssetImage('assets/placeholder.png')
                      as ImageProvider,
                    ),
                    title: Text(name),
                    onTap: () {
                      if (!dialogClosed) {
                        dialogClosed = true;
                        SchedulerBinding.instance.addPostFrameCallback((_) {
                          Navigator.pop(context, {
                            'clientId': clientId,
                            'clientName': name,
                            'clientPhoto': photoUrl,
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
      onClientSelected(result);
      controller.text = result['clientName'];
    }
  }

  // Función para crear un nuevo cliente (diálogo)
  Future<void> _createNewClient(BuildContext context) async {
    final newClient = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        final TextEditingController nameController = TextEditingController();
        final TextEditingController phoneController = TextEditingController();
        final GlobalKey<FormState> formKey = GlobalKey<FormState>();
        return AlertDialog(
          title: const Text('Crear Nuevo Cliente'),
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
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
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
                final clientData = {
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'userId': user.uid,
                  'purchaseCount': 0,
                  'photoUrl': '',
                  'lastUpdated': FieldValue.serverTimestamp(),
                };
                final docRef = await FirebaseFirestore.instance
                    .collection('clients')
                    .add(clientData);
                Navigator.pop(context, {
                  'clientId': docRef.id,
                  'clientName': clientData['name'],
                  'clientPhoto': clientData['photoUrl'],
                });
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    if (newClient != null) {
      onClientSelected(newClient);
      controller.text = newClient['clientName'];
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
              labelText: 'Buscar Cliente',
              prefixIcon: Icon(Icons.person, size: 20),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.search, size: 20),
          onPressed: () => _openSearchDialog(context),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed: () => _createNewClient(context),
        ),
      ],
    );
  }
}
