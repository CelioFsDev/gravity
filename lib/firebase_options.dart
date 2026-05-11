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
    apiKey: 'AIzaSyB1ul-7ZilqnG0Ck0Apk_3D6Z9nFr45cds',
    appId: '1:866110171338:ios:a71004a3d73b26e7b22c33',
    messagingSenderId: '866110171338',
    projectId: 'catalogo-ja-89aae',
    storageBucket: 'catalogo-ja-89aae.firebasestorage.app',
    iosBundleId: 'com.catalogoja.app',
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
