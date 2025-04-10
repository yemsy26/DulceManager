import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';      // ← Import añadido
import 'firebase_options.dart';
import 'order/app_globals.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/config_screen.dart';
import 'pages/client_page.dart';
import 'pages/client_edit_screen.dart';
import 'pages/product_edit_screen.dart';
import 'pages/orders_page.dart';
import 'pages/order_detail_screen.dart';
import 'pages/cart_page.dart';
import 'pages/products_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    // Ignora error si la app ya estaba inicializada
    if (e.code != 'duplicate-app') rethrow;
  }

  // Habilitar persistencia offline de Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runZonedGuarded(() {
    runApp(const MyApp());
  }, (error, stack) {
    debugPrint('Error en la app: $error');
    debugPrint(stack.toString());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DulceManager',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/config': (context) => const ConfigScreen(),
        '/clientList': (context) => const ClientPage(),
        '/clientEdit': (context) => const ClientEditScreen(),
        '/productList': (context) => const ProductsPage(),
        '/productEdit': (context) => const ProductEditScreen(),
        '/orders': (context) => const OrdersPage(),
        '/orderEdit': (context) => const OrderEditScreen(),
        '/cart': (context) => const CartPage(),
      },
    );
  }
}
