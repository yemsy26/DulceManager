// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyABRslG8el0G4yn9-w0wuAOyD8YFeH4iw8',
    appId: '1:455801826429:web:a8985fa53a196f5acad514',
    messagingSenderId: '455801826429',
    projectId: 'dulcemanager-abfdf',
    authDomain: 'dulcemanager-abfdf.firebaseapp.com',
    databaseURL: 'https://dulcemanager-abfdf-default-rtdb.firebaseio.com',
    storageBucket: 'dulcemanager-abfdf.firebasestorage.app',
    measurementId: 'G-HGYDS5L38H',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBxsTD8Ep_8yEdnJSxeS7TtrJUIQMYcPIo',
    appId: '1:455801826429:android:67f6026455340dedcad514',
    messagingSenderId: '455801826429',
    projectId: 'dulcemanager-abfdf',
    databaseURL: 'https://dulcemanager-abfdf-default-rtdb.firebaseio.com',
    storageBucket: 'dulcemanager-abfdf.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyADtLK5SUPED9whGHlL7kXx-dC1A_TsmCU',
    appId: '1:455801826429:ios:0f30ebfea84e9d83cad514',
    messagingSenderId: '455801826429',
    projectId: 'dulcemanager-abfdf',
    databaseURL: 'https://dulcemanager-abfdf-default-rtdb.firebaseio.com',
    storageBucket: 'dulcemanager-abfdf.firebasestorage.app',
    iosClientId: '455801826429-tfkgvsp41j3ljr4e3f1v2qi6vl2e7spm.apps.googleusercontent.com',
    iosBundleId: 'com.example.dulcemanager',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyADtLK5SUPED9whGHlL7kXx-dC1A_TsmCU',
    appId: '1:455801826429:ios:0f30ebfea84e9d83cad514',
    messagingSenderId: '455801826429',
    projectId: 'dulcemanager-abfdf',
    databaseURL: 'https://dulcemanager-abfdf-default-rtdb.firebaseio.com',
    storageBucket: 'dulcemanager-abfdf.firebasestorage.app',
    iosClientId: '455801826429-tfkgvsp41j3ljr4e3f1v2qi6vl2e7spm.apps.googleusercontent.com',
    iosBundleId: 'com.example.dulcemanager',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyABRslG8el0G4yn9-w0wuAOyD8YFeH4iw8',
    appId: '1:455801826429:web:29aaddd5a3d9deadcad514',
    messagingSenderId: '455801826429',
    projectId: 'dulcemanager-abfdf',
    authDomain: 'dulcemanager-abfdf.firebaseapp.com',
    databaseURL: 'https://dulcemanager-abfdf-default-rtdb.firebaseio.com',
    storageBucket: 'dulcemanager-abfdf.firebasestorage.app',
    measurementId: 'G-D5HLNS5JXD',
  );
}
