import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Placeholder Firebase options.
/// Run `flutterfire configure` to generate this file with real values.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return _web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _ios;
      default:
        return FirebaseOptions(
          apiKey: 'REPLACE', // Get this from `flutterfire configure` or Firebase console
          appId: 'REPLACE', // Get this from `flutterfire configure` or Firebase console
          messagingSenderId: '666583578619',
          projectId: 'catalogo-fc9b5',
        );
    }
  }

  static const FirebaseOptions _android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FIREBASE_API_KEY', // Get this from `flutterfire configure` or Firebase console
    appId: 'REPLACE_WITH_FIREBASE_APP_ID', // Get this from `flutterfire configure` or Firebase console
    messagingSenderId: '666583578619',
    projectId: 'catalogo-fc9b5',
  );

  static const FirebaseOptions _ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FIREBASE_API_KEY', // Get this from `flutterfire configure` or Firebase console
    appId: 'REPLACE_WITH_FIREBASE_APP_ID', // Get this from `flutterfire configure` or Firebase console
    messagingSenderId: '666583578619',
    projectId: 'catalogo-fc9b5',
    iosBundleId: 'REPLACE_WITH_BUNDLE_ID',
  );

  static const FirebaseOptions _web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FIREBASE_API_KEY', // Get this from `flutterfire configure` or Firebase console
    appId: 'REPLACE_WITH_FIREBASE_APP_ID', // Get this from `flutterfire configure` or Firebase console
    messagingSenderId: '666583578619',
    projectId: 'catalogo-fc9b5',
    authDomain: 'catalogo-fc9b5.firebaseapp.com',
    storageBucket: 'catalogo-fc9b5.appspot.com',
    measurementId: 'REPLACE_WITH_FIREBASE_MEASUREMENT_ID', // This is different from the Google Analytics Property ID and typically starts with 'G-'. Get this from `flutterfire configure` or Firebase console.
  );
}
