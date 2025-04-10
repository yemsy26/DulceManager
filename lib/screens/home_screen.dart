import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/client_page.dart';
import '../pages/products_page.dart';
import '../pages/orders_page.dart';
import '../pages/reports_page.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _businessName = "DulceManager"; // Valor por defecto

  // Lista de páginas separadas
  final List<Widget> _pages = const [
    ClientPage(),
    ProductsPage(),
    OrdersPage(),
    ReportsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadBusinessName();
  }

  // Carga el nombre del negocio desde Firestore
  Future<void> _loadBusinessName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('negocios').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _businessName = doc.data()?['nombreComercial'] ?? "DulceManager";
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_businessName),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: NetworkImage(
                      FirebaseAuth.instance.currentUser?.photoURL ??
                          'https://via.placeholder.com/150?text=Perfil',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _businessName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Configuración"),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/config');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Cerrar sesión"),
              onTap: () async {
                Navigator.pop(context);
                await _signOut(context);
              },
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Cliente',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Productos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Pedidos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Reportes',
          ),
        ],
      ),
    );
  }
}
