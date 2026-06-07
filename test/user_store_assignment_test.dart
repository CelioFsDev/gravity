import 'package:catalogo_ja/data/repositories/admin_user_account_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildStoreAssignmentUpdates', () {
    test('removes old store mapping and sets the new store assignment', () {
      final updates = AdminUserAccountRepository.buildStoreAssignmentUpdates(
        tenantId: 'tenant-1',
        oldStoreId: 'Loja A',
        newStoreId: 'Loja B',
        role: 'seller',
      );

      expect(updates['currentStoreId'], 'Loja B');
      expect(updates['rolesByStore.tenant-1.Loja B'], 'seller');
      expect(updates['rolesByStore.tenant-1.Loja A'], FieldValue.delete());
    });
  });
}
