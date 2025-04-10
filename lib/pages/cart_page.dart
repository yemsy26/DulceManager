import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  // Ejemplo estático de carrito; en producción, gestiona el estado con un state manager.
  final List<Map<String, dynamic>> cartItems = const [
    {'name': 'Pastel de Chocolate', 'quantity': 1},
    {'name': 'Cupcake de Vainilla', 'quantity': 2},
  ];

  Future<void> _sendOrder(String message) async {
    // Número del negocio; reemplaza con el número real o consúltalo de Firestore
    final phoneNumber = '1234567890';
    final url = Uri.parse("https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'No se pudo abrir $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Construye el resumen del pedido a partir del carrito
    String orderSummary = "Hola, deseo realizar el siguiente pedido:\n";
    for (var item in cartItems) {
      orderSummary += "${item['name']} - Cantidad: ${item['quantity']}\n";
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Carrito de Compras')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          orderSummary,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _sendOrder(orderSummary),
        label: const Text('Ordenar'),
        icon: const Icon(Icons.send),
      ),
    );
  }
}
