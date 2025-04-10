// print_invoice.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Genera un PDF de factura con formato profesional.
/// Se incluyen los datos del negocio (logo, nombre, dirección, teléfono, email)
/// y los detalles del pedido (cliente, método de pago, productos, etc.).
/// Si la orden está marcada como "pendiente", se muestra la fecha de entrega.
/// Al final se muestra la fecha de emisión en un tamaño reducido.
Future<void> sharePdfInvoice(Map<String, dynamic> orderData) async {
  try {
    // 1. Recoger datos del pedido
    final orderId = orderData['orderId'] ?? '';
    final clientName = orderData['clientName'] ?? 'Cliente no definido';
    final total = orderData['total'] ?? 0;
    final paymentMethod = orderData['paymentMethod'] ?? 'No definido';
    final status = orderData['status'] ?? 'pendiente';
    final items = orderData['items'] as List<dynamic>? ?? [];
    final deliveryDateTimestamp = orderData['deliveryDate'];
    DateTime? deliveryDate;
    if (deliveryDateTimestamp is Timestamp) {
      deliveryDate = deliveryDateTimestamp.toDate();
    }

    // 2. Cargar la fuente Roboto desde assets
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final robotoFont = pw.Font.ttf(fontData.buffer.asByteData());

    // 3. Cargar datos del negocio (desde la colección 'negocios' usando el UID del usuario)
    Map<String, dynamic>? businessData;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final businessDoc = await FirebaseFirestore.instance
          .collection('negocios')
          .doc(currentUser.uid)
          .get();
      if (businessDoc.exists) {
        businessData = businessDoc.data();
      }
    }

    // 4. Descargar el logo del negocio, si existe
    Uint8List? logoBytes;
    if (businessData != null &&
        businessData['logoUrl'] != null &&
        businessData['logoUrl'].toString().isNotEmpty) {
      final response = await http.get(Uri.parse(businessData['logoUrl']));
      if (response.statusCode == 200) {
        logoBytes = response.bodyBytes;
      }
    }

    // 5. Crear el documento PDF utilizando la fuente Roboto
    final pdf = pw.Document(theme: pw.ThemeData.withFont(
      base: robotoFont,
    ));

    // 6. Agregar página con un encabezado para el negocio, los datos del pedido y los productos.
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Encabezado del negocio
              if (businessData != null) ...[
                if (logoBytes != null)
                  pw.Center(
                    child: pw.Container(
                      height: 80,
                      width: 80,
                      child: pw.Image(pw.MemoryImage(logoBytes)),
                    ),
                  ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    businessData['nombreComercial'] ?? 'Negocio',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    businessData['direccion'] ?? '',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'Tel: ${businessData['telefono'] ?? ''}   Email: ${businessData['email'] ?? ''}',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ),
                pw.Divider(height: 20),
              ],
              // Encabezado de la factura
              pw.Center(
                child: pw.Text(
                  'Factura del Pedido #$orderId',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Cliente: $clientName', style: pw.TextStyle(fontSize: 14)),
                  pw.Text('Método: $paymentMethod', style: pw.TextStyle(fontSize: 14)),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text('Estado: $status', style: pw.TextStyle(fontSize: 14)),
              if (status == 'pendiente' && deliveryDate != null)
                pw.Text(
                  'Fecha de Entrega: ${deliveryDate.toLocal().toString().split(' ')[0]}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.orange),
                ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Total: \$${total.toString()}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(height: 20),
              // Detalle de productos en formato de tabla
              pw.Text('Productos:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
              pw.SizedBox(height: 5),
              pw.Table.fromTextArray(
                cellAlignment: pw.Alignment.centerLeft,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                cellStyle: pw.TextStyle(fontSize: 10),
                data: <List<String>>[
                  <String>['Producto', 'Cant', 'Precio Unit.', 'Subtotal'],
                  ...items.map((item) {
                    final name = item['name'] ?? '';
                    final quantity = item['quantity'] ?? 0;
                    final price = item['price'] ?? 0;
                    final subtotal = (price * quantity).toString();
                    return [
                      name.toString(),
                      quantity.toString(),
                      "\$$price",
                      "\$$subtotal"
                    ];
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  '¡Gracias por su compra!',
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 14),
                ),
              ),
              pw.SizedBox(height: 20),
              // Fecha de emisión (más pequeña y en el pie de página)
              pw.Text(
                'Fecha de Emisión: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                style: pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.right,
              ),
            ],
          );
        },
      ),
    );

    // 7. Guardar el PDF en un archivo temporal
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/factura_$orderId.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    // 8. Compartir el PDF usando share_plus
    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Factura del Pedido #$orderId',
    );
  } catch (e) {
    debugPrint('Error al generar/compartir PDF: $e');
  }
}
