import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Se asume que estos widgets están implementados en archivos separados:
import '../order/client_search_section.dart';
import '../order/product_search_section.dart';
import '../order/payment_method_section.dart';

class OrderEditScreen extends StatefulWidget {
  const OrderEditScreen({super.key});

  @override
  State<OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends State<OrderEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Fechas
  DateTime _orderDate = DateTime.now();
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 1));

  // Controladores de campos
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _shippingController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _amountReceivedController = TextEditingController();

  // Controladores para búsquedas (cliente y producto)
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _productSearchController = TextEditingController();

  // Datos del cliente seleccionado
  String? _selectedClientId;
  String? _selectedClientName;
  String? _selectedClientPhoto;

  // Lista de productos seleccionados (cada uno: { 'productId', 'name', 'price', 'quantity', 'imageUrl' })
  List<Map<String, dynamic>> _selectedProducts = [];

  // Variables de pago y estado
  String _paymentMethod = 'efectivo'; // Opciones: 'efectivo', 'transferencia', 'pendiente'
  double _change = 0.0;
  double _pendingAmount = 0.0;
  String _status = 'pendiente';

  // Variables de UI
  bool _isLoading = false;
  String? _errorMessage;
  String? _orderId; // Si se pasa, es para editar

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      _orderId = args;
      _loadOrderData();
    }
  }

  Future<void> _loadOrderData() async {
    if (_orderId != null) {
      final doc = await FirebaseFirestore.instance.collection('orders').doc(_orderId).get();
      if (!mounted) return;
      final data = doc.data();
      if (data != null) {
        setState(() {
          _orderDate = (data['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now();
          _deliveryDate = (data['deliveryDate'] as Timestamp?)?.toDate() ??
              DateTime.now().add(const Duration(days: 1));
          _totalController.text = (data['total'] ?? 0.0).toString();
          _shippingController.text = data['shippingAddress'] ?? '';
          _discountController.text = (data['discount'] ?? 0.0).toString();
          _status = data['status'] ?? 'pendiente';
          _paymentMethod = data['paymentMethod'] ?? 'efectivo';
          _amountReceivedController.text = (data['amountReceived'] ?? 0.0).toString();
          _selectedProducts = List<Map<String, dynamic>>.from(data['items'] ?? []);
          _selectedClientId = data['clientId'];
          _selectedClientName = data['clientName'];
          _selectedClientPhoto = data['clientPhoto'];
        });
      }
    }
  }

  Future<void> _pickOrderDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _orderDate) {
      setState(() {
        _orderDate = picked;
      });
    }
  }

  Future<void> _pickDeliveryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate,
      firstDate: _orderDate,
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _deliveryDate) {
      setState(() {
        _deliveryDate = picked;
      });
    }
  }

  double _calculateSubtotal() {
    double subtotal = 0.0;
    for (final prod in _selectedProducts) {
      subtotal += (prod['price'] as double? ?? 0.0) * (prod['quantity'] as int? ?? 1);
    }
    return subtotal;
  }

  // Calcula total y asigna estado según el método de pago:
  void _calculateTotals() {
    final subtotal = _calculateSubtotal();
    final discount = double.tryParse(_discountController.text.trim()) ?? 0.0;
    final total = subtotal - discount;
    _totalController.text = total.toStringAsFixed(2);

    final amountReceived = double.tryParse(_amountReceivedController.text.trim()) ?? 0.0;
    if (_paymentMethod == 'efectivo' || _paymentMethod == 'transferencia') {
      _change = amountReceived - total;
      _pendingAmount = 0.0;
      _status = 'pagado';
    } else if (_paymentMethod == 'pendiente') {
      _pendingAmount = total - amountReceived;
      _change = 0.0;
      _status = 'pendiente';
    } else {
      _change = 0.0;
      _pendingAmount = 0.0;
    }
  }

  void _updateProductQuantity(String productId, int delta) {
    setState(() {
      final index = _selectedProducts.indexWhere((p) => p['productId'] == productId);
      if (index != -1) {
        int current = _selectedProducts[index]['quantity'] as int? ?? 1;
        int updated = current + delta;
        if (updated <= 0) {
          _selectedProducts.removeAt(index);
        } else {
          _selectedProducts[index]['quantity'] = updated;
        }
        _calculateTotals();
      }
    });
  }

  Future<void> _saveOrder() async {
    if (_formKey.currentState?.validate() != true) return;
    _calculateTotals();
    setState(() {
      _isLoading = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = "Usuario no autenticado";
        _isLoading = false;
      });
      return;
    }
    final data = {
      'userId': user.uid,
      'orderDate': Timestamp.fromDate(_orderDate),
      'deliveryDate': Timestamp.fromDate(_deliveryDate),
      'total': double.tryParse(_totalController.text.trim()) ?? 0.0,
      'shippingAddress': _shippingController.text.trim(),
      'discount': double.tryParse(_discountController.text.trim()) ?? 0.0,
      'items': _selectedProducts,
      'clientId': _selectedClientId,
      'clientName': _selectedClientName,
      'clientPhoto': _selectedClientPhoto,
      'status': _status,
      'paymentMethod': _paymentMethod,
      'amountReceived': double.tryParse(_amountReceivedController.text.trim()) ?? 0.0,
      'change': _change,
      'pendingAmount': _pendingAmount,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    try {
      final collection = FirebaseFirestore.instance.collection('orders');
      if (_orderId == null) {
        await collection.add(data);
      } else {
        await collection.doc(_orderId).update(data);
      }
      setState(() {
      });
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

  Future<void> _deleteOrder() async {
    if (_orderId == null) return;
    setState(() {
      _isLoading = true;
    });
    try {
      await FirebaseFirestore.instance.collection('orders').doc(_orderId).delete();
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

  // Función para compartir la factura

  // Función para imprimir la factura (stub)

  // Muestra los detalles de la orden en un diálogo

  @override
  void dispose() {
    _totalController.dispose();
    _shippingController.dispose();
    _discountController.dispose();
    _amountReceivedController.dispose();
    _clientSearchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Se asume que ClientSearchSection, ProductSearchSection y PaymentMethodSection están implementados
    return Scaffold(
      appBar: AppBar(
        title: Text(_orderId == null ? 'Nuevo Pedido' : 'Editar Pedido'),
        actions: _orderId != null
            ? [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteOrder,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              // Mostrar el cliente seleccionado (si existe)
              if (_selectedClientName != null)
                Text(
                  'Cliente Seleccionado: $_selectedClientName',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 16),
              // Sección de búsqueda de cliente
              ClientSearchSection(
                controller: _clientSearchController,
                onClientSelected: (result) {
                  setState(() {
                    _selectedClientId = result['clientId'] as String?;
                    _selectedClientName = result['clientName'] as String?;
                    _selectedClientPhoto = result['clientPhoto'] as String?;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Sección de búsqueda de producto
              ProductSearchSection(
                controller: _productSearchController,
                onProductSelected: (result) {
                  setState(() {
                    _selectedProducts.add(result);
                  });
                  _calculateTotals();
                },
              ),
              const SizedBox(height: 16),
              // Lista de productos seleccionados
              if (_selectedProducts.isNotEmpty)
                Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedProducts.length,
                    itemBuilder: (context, index) {
                      final prod = _selectedProducts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: (prod['imageUrl']?.toString().isNotEmpty ?? false)
                              ? NetworkImage(prod['imageUrl'])
                              : const AssetImage('assets/placeholder.png') as ImageProvider,
                        ),
                        title: Text(prod['name'] ?? 'Producto'),
                        subtitle: Text('Precio: \$${prod['price']}  Cantidad: ${prod['quantity']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                              onPressed: () => _updateProductQuantity(prod['productId'] as String, -1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green, size: 20),
                              onPressed: () => _updateProductQuantity(prod['productId'] as String, 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              // Selección de fechas
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fecha del Pedido: ${_orderDate.toLocal().toString().split(" ")[0]}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: _pickOrderDate,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fecha de Entrega: ${_deliveryDate.toLocal().toString().split(" ")[0]}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.date_range),
                    onPressed: _pickDeliveryDate,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Total (calculado automáticamente)
              TextFormField(
                controller: _totalController,
                decoration: const InputDecoration(
                  labelText: 'Total',
                  border: OutlineInputBorder(),
                ),
                readOnly: true,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              // Dirección de Envío
              TextFormField(
                controller: _shippingController,
                decoration: const InputDecoration(
                  labelText: 'Dirección de Envío',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Sección de método de pago
              PaymentMethodSection(
                selectedMethod: _paymentMethod,
                onMethodChanged: (method) {
                  setState(() {
                    _paymentMethod = method;
                  });
                  _calculateTotals();
                },
              ),
              const SizedBox(height: 16),
              // Monto Recibido
              TextFormField(
                controller: _amountReceivedController,
                decoration: const InputDecoration(
                  labelText: 'Monto Recibido',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  _calculateTotals();
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              if (_paymentMethod == 'efectivo')
                Text(
                  'Cambio: \$${_change.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16),
                ),
              if (_paymentMethod == 'pendiente')
                Text(
                  'Pendiente: \$${_pendingAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16),
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saveOrder,
                icon: const Icon(Icons.save),
                label: const Text('Guardar Pedido'),
              ),
            ],
          ),
        ),
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
