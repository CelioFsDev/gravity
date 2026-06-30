import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:catalogo_ja/firebase_options.dart';
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final snap = await FirebaseFirestore.instance.collection('tenants').limit(1).get();
  if (snap.docs.isEmpty) {
    print('No tenants found.');
    return;
  }
  final tenantId = snap.docs.first.id;
  final prods = await FirebaseFirestore.instance.collection('tenants').doc(tenantId).collection('products').limit(5).get();
  for (var d in prods.docs) {
    final data = d.data();
    print('Prod ID: ${d.id}');
    print('  images: ${data['images']}');
    print('  remoteImages: ${data['remoteImages']}');
    print('  imageUrl: ${data['imageUrl']}');
    print('  photo: ${data['photo']}');
  }
}
