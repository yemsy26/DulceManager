import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Para reconocer Timestamp
import 'app_globals.dart'; // la ruta real a tu archivo

/// Servicio para impresión en impresoras térmicas usando la librería
/// [blue_thermal_printer](https://pub.dev/packages/blue_thermal_printer).
class ThermalPrinterService {
  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  /// Obtiene la lista de dispositivos (impresoras) Bluetooth emparejados.
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      final List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();
      return devices;
    } catch (e) {
      debugPrint("Error al obtener dispositivos emparejados: $e");
      return [];
    }
  }

  /// Verifica si ya hay una impresora conectada.
  Future<bool> isConnected() async {
    final bool? connected = await _bluetooth.isConnected;
    return connected ?? false;
  }

  /// Conecta a la impresora especificada [device].
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Si no está conectado, realiza la conexión.
      final bool connected = await isConnected();
      if (!connected) {
        await _bluetooth.connect(device);
      }
      return true;
    } catch (e) {
      debugPrint("Error al conectar con ${device.name}: $e");
      return false;
    }
  }

  /// Desconecta la impresora actual, si existe.
  Future<void> disconnect() async {
    try {
      await _bluetooth.disconnect();
    } catch (e) {
      debugPrint("Error al desconectar: $e");
    }
  }

  /// Imprime una factura sencilla con los datos proporcionados.
  /// Variables en inglés cambiadas a las mismas que orders_page:
  /// - [nombreComercial], [direccion], [telefono]
  /// - [orderId], [orderDate], [clientName], [items], [total],
  ///   [discount], [received], [change]
  Future<void> printInvoice({
    required String nombreComercial,
    required String direccion,
    required String telefono,
    required String orderId,
    required String orderDate,
    required String clientName,
    required List<Map<String, dynamic>> items,
    required double total,
    required double discount,
    required double received,
    required double change,
  }) async {
    try {
      // Verifica que la impresora esté conectada.
      if (!await isConnected()) {
        debugPrint("La impresora no está conectada. Abortando impresión.");
        return;
      }

      // Espacio y encabezado del negocio
      _bluetooth.printNewLine();
      _bluetooth.printCustom(nombreComercial, 2, 1);
      _bluetooth.printCustom(direccion, 1, 1);
      _bluetooth.printCustom("Tel: $telefono", 1, 1);
      _bluetooth.printNewLine();

      // Encabezado de la factura
      _bluetooth.printCustom("Factura #$orderId", 1, 0);
      _bluetooth.printCustom("Fecha: $orderDate", 1, 0);
      _bluetooth.printCustom("Cliente: $clientName", 1, 0);
      _bluetooth.printNewLine();

      // Productos
      _bluetooth.printCustom("------ Productos ------", 1, 0);
      for (final item in items) {
        final String name = item["name"] ?? "N/A";
        final int qty = item["quantity"] ?? 1;
        final double price = item["price"]?.toDouble() ?? 0.0;
        final double subtotal = price * qty;
        _bluetooth.printCustom("$qty x $name   \$${subtotal.toStringAsFixed(2)}", 1, 0);
      }
      _bluetooth.printCustom("-----------------------", 1, 0);

      // Totales
      _bluetooth.printCustom("Total: \$${total.toStringAsFixed(2)}", 1, 0);
      _bluetooth.printCustom("Descuento: \$${discount.toStringAsFixed(2)}", 1, 0);
      _bluetooth.printCustom("Recibido: \$${received.toStringAsFixed(2)}", 1, 0);
      _bluetooth.printCustom("Cambio: \$${change.toStringAsFixed(2)}", 1, 0);

      // Mensaje final y corte
      _bluetooth.printNewLine();
      _bluetooth.printCustom("¡Gracias por su compra!", 1, 1);
      _bluetooth.printNewLine();
      _bluetooth.paperCut();
    } catch (e) {
      debugPrint("Error al imprimir la factura: $e");
    }
  }

  /// Método que muestra una pantalla para seleccionar la impresora si no está conectada.
  /// Se utiliza un diálogo (PrinterSelectionDialog) que muestra los dispositivos Bluetooth emparejados.
  /// Se asume que se dispone de un GlobalKey<NavigatorState> llamado 'navigatorKey'
  Future<bool> ensurePrinterConnected() async {
    if (await isConnected()) {
      return true;
    }

    // Se utiliza el global navigatorKey para obtener un BuildContext.
    // Asegúrate de tener algo similar definido en el main.dart:
    // final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    BuildContext? context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint("No hay contexto disponible para mostrar el diálogo de conexión.");
      return false;
    }

    // Muestra el diálogo para seleccionar impresora.
    BluetoothDevice? selectedDevice = await showDialog<BluetoothDevice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PrinterSelectionDialog(),
    );

    if (selectedDevice != null) {
      bool connected = await connectToDevice(selectedDevice);
      return connected;
    }
    return false;
  }

  /// Método para delegar la impresión térmica recibiendo el Map de datos.
  /// Antes de imprimir, se verifica si hay una impresora conectada; de lo contrario,
  /// se muestra el diálogo para seleccionar y conectar.
  Future<void> printThermalInvoice(Map<String, dynamic> orderData) async {
    bool connected = await ensurePrinterConnected();
    if (!connected) {
      debugPrint("Impresora no conectada, cancelando impresión.");
      return;
    }

    // Extrae los datos usando las claves definidas en orders_page.
    final nombreComercial = orderData['nombreComercial'] ?? 'Negocio sin nombre';
    final direccion = orderData['direccion'] ?? '';
    final telefono = orderData['telefono'] ?? '';
    final orderId = orderData['orderId'] ?? '';
    String orderDate;
    if (orderData['orderDate'] != null && orderData['orderDate'] is Timestamp) {
      orderDate = (orderData['orderDate'] as Timestamp).toDate().toLocal().toString().split(' ')[0];
    } else {
      orderDate = DateTime.now().toLocal().toString().split(' ')[0];
    }
    final clientName = orderData['clientName'] ?? 'Cliente no definido';
    final List<Map<String, dynamic>> items =
    List<Map<String, dynamic>>.from(orderData['items'] ?? []);
    final total = orderData['total']?.toDouble() ?? 0.0;
    final discount = orderData['discount']?.toDouble() ?? 0.0;
    final received = orderData['received']?.toDouble() ?? total;
    final change = orderData['change']?.toDouble() ?? 0.0;

    await printInvoice(
      nombreComercial: nombreComercial,
      direccion: direccion,
      telefono: telefono,
      orderId: orderId,
      orderDate: orderDate,
      clientName: clientName,
      items: items,
      total: total,
      discount: discount,
      received: received,
      change: change,
    );
  }
}

/// Widget que muestra una ventana de diálogo para seleccionar entre
/// los dispositivos Bluetooth emparejados.
class PrinterSelectionDialog extends StatefulWidget {
  const PrinterSelectionDialog({Key? key}) : super(key: key);

  @override
  _PrinterSelectionDialogState createState() => _PrinterSelectionDialogState();
}

class _PrinterSelectionDialogState extends State<PrinterSelectionDialog> {
  List<BluetoothDevice> devices = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      isLoading = true;
    });
    // Utilizamos una instancia del mismo servicio para obtener dispositivos.
    final thermal = ThermalPrinterService();
    devices = await thermal.getBondedDevices();
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Seleccionar impresora"),
      content: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            return ListTile(
              title: Text(device.name ?? "Dispositivo sin nombre"),
              subtitle: Text(device.address ?? ""),
              onTap: () {
                Navigator.of(context).pop(device);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("Cancelar"),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadDevices,
        )
      ],
    );
  }
}
