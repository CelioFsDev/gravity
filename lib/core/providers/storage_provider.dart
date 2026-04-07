import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service_interface.dart';
import '../services/saas_photo_storage_service.dart';
import '../services/minio_photo_storage_service.dart';
import '../../data/repositories/auth_repository.dart';

/// Define qual serviço de storage usar. 
/// true: MinIO (Backend API)
/// false: Firebase Storage (Legado)
const bool useMinioStorage = true; 

final storageServiceProvider = Provider<IPhotoStorageService>((ref) {
  if (useMinioStorage) {
    final auth = ref.watch(authRepositoryProvider);
    return MinioPhotoStorageService(auth);
  } else {
    return SaaSPhotoStorageService();
  }
});

// Alias para compatibilidade com o provider antigo se necessário
final saasPhotoStorageProvider = storageServiceProvider;
