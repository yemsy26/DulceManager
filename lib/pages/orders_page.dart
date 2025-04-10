import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';


// Importamos el archivo que genera el PDF y lo comparte.
import '../order/print_invoice.dart';
import '../order/thermal_printer_service.dart';


class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String? _userId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Datos del negocio (opcional)
  Map<String, dynamic>? _businessData;

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
      _loadBusinessData();
    }
  }

  Future<void> _loadBusinessData() async {
    if (_userId == null) return;
    final doc = await FirebaseFirestore.instance.collection('negocios').doc(_userId).get();
    if (doc.exists) {
      setState(() {
        _businessData = doc.data();
      });
    }
  }

  // Función para alternar el estado de la orden (pendiente <-> pagado)
  Future<void> _toggleOrderStatus(String orderId, String currentStatus) async {
    final newStatus = (currentStatus == 'pendiente') ? 'pagado' : 'pendiente';
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': newStatus,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Orden marcada como $newStatus')));
  }

  void _editOrder(String orderId) {
    Navigator.pushNamed(context, '/orderEdit', arguments: orderId);
  }

  Future<void> _confirmDeleteOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Está seguro de eliminar este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Orden eliminada')));
    }
  }

  // Función para compartir la factura usando PDF con formato profesional.
  // Se invoca la función sharePdfInvoice() del archivo print_invoice.dart.
  Future<void> _shareInvoice(Map<String, dynamic> orderData) async {
    // Agregamos el campo "orderId" al mapa para que la función pueda mostrarlo.
    final fullData = {...orderData, 'orderId': orderData['orderId'] ?? ''};
    await sharePdfInvoice(fullData);
  }

// Función para imprimir la factura, delegando completamente en el archivo thermal
  Future<void> _printInvoice(Map<String, dynamic> orderData) async {
    final printerService = ThermalPrinterService();
    await printerService.printThermalInvoice(orderData);
  }

  // Muestra los detalles de la orden en un diálogo
  void _viewOrderDetails(Map<String, dynamic> orderData) {
    showDialog(
      context: context,
      builder: (ctx) {
        final clientName = orderData['clientName'] ?? 'Desconocido';
        final total = orderData['total'] ?? 0;
        final status = orderData['status'] ?? 'pendiente';
        final items = orderData['items'] as List<dynamic>? ?? [];
        final deliveryDate = (orderData['deliveryDate'] as Timestamp?)?.toDate();
        return AlertDialog(
          title: const Text('Detalles de la Orden'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cliente: $clientName'),
                Text('Estado: $status'),
                Text('Total: \$$total'),
                if (status == 'pendiente' && deliveryDate != null)
                  Text('Entrega: ${deliveryDate.toLocal().toString().split(' ')[0]}',
                      style: const TextStyle(color: Colors.orange)),
                const Divider(),
                const Text('Productos:', style: TextStyle(fontWeight: FontWeight.bold)),
                for (final item in items)
                  Text('${item['name']} - Cant: ${item['quantity']} - \$${item['price']}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
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
        title: const Text('Historial de Pedidos'),
      ),
      body: Column(
        children: [
          // Información del negocio (opcional)
          if (_businessData != null)
            Card(
              elevation: 2,
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text(
                  _businessData!['nombreComercial'] ?? 'Negocio sin nombre',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${_businessData!['direccion'] ?? ''}\n'
                      'Tel: ${_businessData!['telefono'] ?? ''}\n'
                      'Email: ${_businessData!['email'] ?? ''}',
                ),
                isThreeLine: true,
                leading: (_businessData!['logoUrl'] != null &&
                    _businessData!['logoUrl'].toString().isNotEmpty)
                    ? CircleAvatar(backgroundImage: NetworkImage(_businessData!['logoUrl']))
                    : const CircleAvatar(child: Icon(Icons.store)),
              ),
            ),
          // Buscador local
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar por ID o cliente',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          // Lista de órdenes (se muestra sin filtro de fecha; se ordena de tal manera que las pendientes aparecen arriba)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('orders')
                  .where('userId', isEqualTo: _userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('Error en StreamBuilder: ${snapshot.error}');
                  return const Center(child: Text('Error al cargar los pedidos'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                List<QueryDocumentSnapshot> orders = snapshot.data!.docs;
                // Ordena: pendientes primero; luego por fecha descendente
                orders.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  final statusA = dataA['status'] ?? 'pendiente';
                  final statusB = dataB['status'] ?? 'pendiente';
                  if (statusA == statusB) {
                    final dateA = (dataA['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final dateB = (dataB['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now();
                    return dateB.compareTo(dateA);
                  }
                  return statusA == 'pendiente' ? -1 : 1;
                });
                // Filtrar según búsqueda
                final filteredOrders = orders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final orderId = doc.id.toLowerCase();
                  final clientName = (data['clientName'] ?? '').toString().toLowerCase();
                  return orderId.contains(_searchQuery) || clientName.contains(_searchQuery);
                }).toList();
                if (filteredOrders.isEmpty) {
                  return const Center(child: Text('No hay resultados con esa búsqueda.'));
                }
                return ListView.builder(
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final doc = filteredOrders[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final orderId = doc.id;
                    final orderDate = (data['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final total = data['total'] ?? 0;
                    final clientName = data['clientName'] ?? 'Cliente no definido';
                    final status = data['status'] ?? 'pendiente';
                    final deliveryDate = (data['deliveryDate'] as Timestamp?)?.toDate();
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Encabezado del pedido
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Pedido #$orderId',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  orderDate.toLocal().toString().split(' ')[0],
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Cliente: $clientName', style: const TextStyle(fontSize: 14)),
                            Text('Estado: $status', style: const TextStyle(fontSize: 14)),
                            // Si la orden está pendiente, muestra la fecha de entrega; si ya está pagada no se muestra
                            if (status == 'pendiente' && deliveryDate != null)
                              Text('Fecha de Entrega: ${deliveryDate.toLocal().toString().split(' ')[0]}',
                                  style: const TextStyle(fontSize: 12, color: Colors.orange)),
                            const SizedBox(height: 4),
                            Text('Total: \$${total.toString()}', style: const TextStyle(fontSize: 14)),
                            const Divider(),
                            // Menú de acciones
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_red_eye, color: Colors.indigo),
                                  tooltip: 'Ver Detalles',
                                  onPressed: () {
                                    final fullData = {...data, 'orderId': orderId};
                                    _viewOrderDetails(fullData);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Editar Pedido',
                                  onPressed: () => _editOrder(orderId),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Eliminar Pedido',
                                  onPressed: () => _confirmDeleteOrder(orderId),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.send, color: Colors.green),
                                  tooltip: 'Compartir Factura (PDF)',
                                  onPressed: () {
                                    final fullData = {...data, 'orderId': orderId};
                                    _shareInvoice(fullData);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.print, color: Colors.black87),
                                  tooltip: 'Imprimir Factura',
                                  onPressed: () {
                                    final fullData = {...data, 'orderId': orderId};
                                    _printInvoice(fullData);
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    status == 'pendiente' ? Icons.timelapse : Icons.check_circle,
                                    color: status == 'pendiente' ? Colors.orange : Colors.green,
                                  ),
                                  tooltip: status == 'pendiente'
                                      ? 'Marcar como Pagado'
                                      : 'Marcar como Pendiente',
                                  onPressed: () => _toggleOrderStatus(orderId, status),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Crear Nuevo Pedido',
        onPressed: () {
          Navigator.pushNamed(context, '/orderEdit');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
