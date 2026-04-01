import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase options for the configured platforms in this repository.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return _web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _ios;
      case TargetPlatform.windows:
        return _web;
      default:
        return _web;
    }
  }

  static const FirebaseOptions _android = FirebaseOptions(
    apiKey: 'AIzaSyBMeR_RH66Vcb0L0pc0AG02gmqPO57fXqk',
    appId: '1:866110171338:android:64ff6d2812e4d575b22c33',
    messagingSenderId: '866110171338',
    projectId: 'catalogo-ja-89aae',
  );

  static const FirebaseOptions _ios = FirebaseOptions(
    apiKey:
        'REPLACE_WITH_FIREBASE_API_KEY', // Get this from `flutterfire configure` or Firebase console
    appId:
        'REPLACE_WITH_FIREBASE_APP_ID', // Get this from `flutterfire configure` or Firebase console
    messagingSenderId: '666583578619',
    projectId: 'catalogo-fc9b5',
    iosBundleId: 'REPLACE_WITH_BUNDLE_ID',
  );

  static const FirebaseOptions _web = FirebaseOptions(
    apiKey: 'AIzaSyAaRQRzA8lPBovETa8cj609dxeWIlc8Bb4',
    appId: '1:866110171338:web:554b3c834d75f519b22c33',
    messagingSenderId: '866110171338',
    projectId: 'catalogo-ja-89aae',
    authDomain: 'catalogo-ja-89aae.firebaseapp.com',
    storageBucket: 'catalogo-ja-89aae.firebasestorage.app',
    measurementId: 'G-04ZDD9V1XT',
  );
}
