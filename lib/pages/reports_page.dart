import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:screenshot/screenshot.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' show TableHelper;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;                // para ui.TextDirection

// ...

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime? _startDate, _endDate;
  final _dateFormat = DateFormat('yyyy-MM-dd');
  String _type = "Ventas";
  final _types = ["Ventas", "Clientes", "Catálogo"];

  Map<String, dynamic>? _business;
  List<_DayData> _data = [];

  final _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('negocios').doc(uid).get();
    setState(() => _business = doc.data());
  }

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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reportes"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_type == "Ventas") ...[
              Row(
                children: [
                  Expanded(child: _buildDatePicker("Desde", _startDate, (d) => setState(() => _startDate = d))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDatePicker("Hasta", _endDate, (d) => setState(() => _endDate = d))),
                ],
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              value: _type,
              items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _type = val!),
              decoration: const InputDecoration(
                labelText: 'Tipo de Reporte',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text("Generar Reporte"),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_type == "Ventas") {
      return FutureBuilder<QuerySnapshot>(
        future: _fetchOrders(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          _prepareData(snap.data!.docs);
          return ListView(
            children: [
              if (_business != null) _buildBusinessHeader(),
              Screenshot(
                controller: _screenshotController,
                child: SizedBox(height: 300, child: _buildChart()),
              ),
              const SizedBox(height: 16),
              _buildMetricsCard(),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _exportPdf,
                icon: const Icon(Icons.download),
                label: const Text("Exportar PDF"),
              ),
            ],
          );
        },
      );
    } else if (_type == "Clientes") {
      return FutureBuilder<QuerySnapshot>(
        future: _fetchClients(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          return ListView(
            children: [
              if (_business != null) _buildBusinessHeader(),
              _buildClientsReport(docs),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _exportPdf,
                icon: const Icon(Icons.download),
                label: const Text("Exportar PDF"),
              ),
            ],
          );
        },
      );
    } else if (_type == "Catálogo") {
      return FutureBuilder<QuerySnapshot>(
        future: _fetchProducts(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          return ListView(
            children: [
              if (_business != null) _buildBusinessHeader(),
              _buildProductsReport(docs),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _exportPdf,
                icon: const Icon(Icons.download),
                label: const Text("Exportar PDF"),
              ),
            ],
          );
        },
      );
    }
    return Center(child: Text("Tipo de reporte desconocido"));
  }

  Widget _buildBusinessHeader() {
    return Column(
      children: [
        Row(
          children: [
            (_business != null &&
                _business!['logoUrl'] != null &&
                _business!['logoUrl'].toString().isNotEmpty)
                ? Image.network(_business!['logoUrl'], width: 60, height: 60)
                : Image.asset('assets/logo.png', width: 60, height: 60),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_business!['nombreComercial'] ?? '',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(_business!['direccion'] ?? ''),
                  Text("Tel: ${_business!['telefono'] ?? ''}"),
                ],
              ),
            ),
          ],
        ),
        const Divider(thickness: 2),
      ],
    );
  }

  Widget _buildChart() {
    final spotsBar = <BarChartGroupData>[];
    for (var i = 0; i < _data.length; i++) {
      spotsBar.add(BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(toY: _data[i].orders.toDouble(), width: 8)],
      ));
    }

    return BarChart(
      BarChartData(
        barGroups: spotsBar,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, _) {
              final idx = val.toInt().clamp(0, _data.length - 1);
              return Text(_data[idx].dayLabel, style: const TextStyle(fontSize: 10));
            }),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        ),
        gridData: FlGridData(show: true),
      ),
    );
  }

  Widget _buildMetricsCard() {
    final totalSales = _data.fold(0.0, (ac, d) => ac + d.sales);
    final totalOrders = _data.fold<int>(0, (ac, d) => ac + d.orders);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
          children: [
            const TableRow(
              children: [
                Text("Métrica", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("Valor", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            TableRow(children: [
              const Text("Total Ventas"),
              Text("\$${totalSales.toStringAsFixed(2)}"),
            ]),
            TableRow(children: [
              const Text("Total Pedidos"),
              Text("$totalOrders"),
            ]),
            TableRow(children: [
              const Text("Días Reportados"),
              Text("${_data.length}"),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildClientsReport(List<QueryDocumentSnapshot> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Total Clientes: ${docs.length}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'Sin nombre';
          final phone = data['phone'] ?? '-';
          final photo = data['photoUrl'] ?? '';
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: photo.isNotEmpty
                    ? NetworkImage(photo)
                    : const AssetImage('assets/placeholder.png') as ImageProvider,
              ),
              title: Text(name),
              subtitle: FutureBuilder<int>(
                future: _getPurchaseCount(name),
                builder: (ctx, snapCount) {
                  final count = snapCount.hasData ? snapCount.data : 0;
                  return Text("Compras: ${count ?? 0}  |  Tel: $phone");
                },
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildProductsReport(List<QueryDocumentSnapshot> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Total Productos: ${docs.length}",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: (data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty)
                    ? NetworkImage(data['imageUrl'])
                    : const AssetImage('assets/placeholder.png') as ImageProvider,
              ),
              title: Text(data['name'] ?? 'Producto sin nombre'),
              subtitle: Text("Precio: \$${data['price'] ?? '0'} - Stock: ${data['stock'] ?? '0'}"),
            ),
          );
        }).toList(),
      ],
    );
  }

  Future<void> _exportPdf() async {
    Uint8List logoBytes;
    if (_business != null &&
        _business!['logoUrl'] != null &&
        _business!['logoUrl'].toString().isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(_business!['logoUrl']));
        if (response.statusCode == 200) {
          logoBytes = response.bodyBytes;
        } else {
          final assetData = await rootBundle.load('assets/logo.png');
          logoBytes = assetData.buffer.asUint8List();
        }
      } catch (_) {
        final assetData = await rootBundle.load('assets/logo.png');
        logoBytes = assetData.buffer.asUint8List();
      }
    } else {
      final assetData = await rootBundle.load('assets/logo.png');
      logoBytes = assetData.buffer.asUint8List();
    }

    final pdf = pw.Document();

    if (_type == "Ventas") {
      Uint8List chartImage;
      try {
        chartImage = await _captureChart();
      } catch (e) {
        chartImage = Uint8List(0);
      }
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) {
            return [
              pw.Row(children: [
                pw.Image(pw.MemoryImage(logoBytes), width: 60, height: 60),
                pw.SizedBox(width: 12),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_business?['nombreComercial'] ?? '',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text(_business?['direccion'] ?? ''),
                    pw.Text("Tel: ${_business?['telefono'] ?? ''}"),
                  ],
                ),
              ]),
              pw.Divider(thickness: 2),
              pw.Text("Reporte de Ventas", style: pw.TextStyle(fontSize: 18)),
              pw.Text(
                  "Desde: ${_startDate != null ? _dateFormat.format(_startDate!) : '-'}  Hasta: ${_endDate != null ? _dateFormat.format(_endDate!) : '-'}",
                  style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 12),
              TableHelper.fromTextArray(
                context: ctx,
                data: [
                  ['Métrica', 'Valor'],
                  [
                    'Total Ventas',
                    '\$${_data.fold(0.0, (ac, d) => ac + d.sales).toStringAsFixed(2)}'
                  ],
                  [
                    'Total Pedidos',
                    '${_data.fold<int>(0, (ac, d) => ac + d.orders)}'
                  ],
                  ['Días Reportados', '${_data.length}'],
                ],
              ),
              pw.SizedBox(height: 12),
              chartImage.isNotEmpty
                  ? pw.Container(
                height: 200,
                child: pw.Image(pw.MemoryImage(chartImage), fit: pw.BoxFit.contain),
              )
                  : pw.Text("No se pudo capturar el gráfico"),
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Generado: ${_dateFormat.format(DateTime.now())}",
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
            ];
          },
        ),
      );
    } else if (_type == "Clientes") {
      final clientsSnapshot = await _fetchClients();
      final clients = clientsSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      List<List<String>> tableData = [
        ['Nombre', 'Teléfono', 'Compras']
      ];
      for (var client in clients) {
        final name = client['name'] ?? '-';
        final phone = client['phone'] ?? '-';
        final count = await _getPurchaseCount(name);
        tableData.add([name, phone, count.toString()]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) {
            return [
              pw.Row(children: [
                pw.Image(pw.MemoryImage(logoBytes), width: 60, height: 60),
                pw.SizedBox(width: 12),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_business?['nombreComercial'] ?? '',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text(_business?['direccion'] ?? ''),
                    pw.Text("Tel: ${_business?['telefono'] ?? ''}"),
                  ],
                ),
              ]),
              pw.Divider(thickness: 2),
              pw.Text("Reporte de Clientes", style: pw.TextStyle(fontSize: 18)),
              pw.Text("Total Clientes: ${clients.length}", style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 12),
              TableHelper.fromTextArray(context: ctx, data: tableData),
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Generado: ${_dateFormat.format(DateTime.now())}",
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
            ];
          },
        ),
      );
    } else if (_type == "Catálogo") {
      final productsSnapshot = await _fetchProducts();
      final products = productsSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      List<List<String>> tableData = [
        ['Producto', 'Precio', 'Stock']
      ];
      for (var prod in products) {
        tableData.add([
          prod['name'] ?? '-',
          prod['price'] != null ? '\$${prod['price']}' : '-',
          prod['stock']?.toString() ?? '-',
        ]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) {
            return [
              pw.Row(children: [
                pw.Image(pw.MemoryImage(logoBytes), width: 60, height: 60),
                pw.SizedBox(width: 12),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_business?['nombreComercial'] ?? '',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text(_business?['direccion'] ?? ''),
                    pw.Text("Tel: ${_business?['telefono'] ?? ''}"),
                  ],
                ),
              ]),
              pw.Divider(thickness: 2),
              pw.Text("Reporte de Catálogo", style: pw.TextStyle(fontSize: 18)),
              pw.Text("Total Productos: ${products.length}", style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 12),
              TableHelper.fromTextArray(context: ctx, data: tableData),
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Generado: ${_dateFormat.format(DateTime.now())}",
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),
            ];
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdf.save());
  }

  Future<QuerySnapshot> _fetchOrders() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final start = _startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = _endDate ?? DateTime.now();
    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: uid)
        .where('orderDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('orderDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
  }

  Future<QuerySnapshot> _fetchClients() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('clients')
        .where('userId', isEqualTo: uid)
        .get();
  }

  Future<QuerySnapshot> _fetchProducts() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('products')
        .where('ownerId', isEqualTo: uid)
        .get();
  }

  void _prepareData(List<QueryDocumentSnapshot> docs) {
    final byDay = <String, _DayData>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['orderDate'] as Timestamp).toDate();
      final dayKey = _dateFormat.format(date);
      byDay.putIfAbsent(dayKey, () => _DayData(dayLabel: dayKey))
          .add(data['total']?.toDouble() ?? 0);
    }
    final list = byDay.values.toList()..sort((a, b) => a.dayLabel.compareTo(b.dayLabel));
    _data = list;
  }

  Widget _buildDatePicker(String label, DateTime? value, void Function(DateTime) onSelected) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onSelected(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(value != null ? _dateFormat.format(value) : ''),
      ),
    );
  }

  /// Captura el gráfico con ancestro de MediaQuery y Directionality
  /// Captura el gráfico con ancestro de MediaQuery y Directionality
  Future<Uint8List> _captureChart() async {
    const chartWidth = 300.0;
    const chartHeight = 200.0;

    return await _screenshotController.captureFromWidget(
      // 1) MediaQuery con el tamaño deseado
      MediaQuery(
        data: MediaQueryData(size: Size(chartWidth, chartHeight)),
        child:
        // 2) Directionality para el texto (usando ui.TextDirection)
        Directionality(
          textDirection: ui.TextDirection.ltr,
          child:
          // 3) Center + SizedBox para posicionar el gráfico
          Center(
            child: SizedBox(
              width: chartWidth,
              height: chartHeight,
              child: _buildChart(),
            ),
          ),
        ),
      ),
      pixelRatio: 2,
    );
  }

}

class _DayData {
  final String dayLabel;
  double sales = 0;
  int orders = 0;

  _DayData({required this.dayLabel});

  void add(double total) {
    sales += total;
    orders++;
  }
}
