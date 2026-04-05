import 'dart:io';

void main() {
  final file = File('d:\\REPOSITORIO GIT\\gravity\\lib\\features\\admin\\products\\product_form_screen.dart');
  var content = file.readAsStringSync();

  // Clean up duplicate state variables again, just in case
  final dupRegex = RegExp(r'  // Multi-Store SaaS Overrides\s+bool _isIndividualStoreConfig = false;\s+List<String> _unavailableSizes = \[\];\s+List<String> _unavailableColors = \[\];\s+String\? _currentStoreId;\s+');
  content = content.replaceFirst(dupRegex, '');

  final loadMethod = r'''

  void _loadOverrides(String storeId) {
    final pr = widget.product;
    if (pr == null) return;

    final override = pr.storeOverrides[storeId];
    if (override != null) {
      setState(() {
        _isIndividualStoreConfig = true;
        _unavailableSizes = List<String>.from(override['unavailableSizes'] ?? []);
        _unavailableColors = List<String>.from(override['unavailableColors'] ?? []);
        
        final f = NumberFormat.decimalPattern('pt_BR');
        if (override['priceRetail'] != null) {
          _retailController.text = f.format(override['priceRetail']);
        }
        if (override['priceWholesale'] != null) {
          _wholesaleController.text = f.format(override['priceWholesale']);
        }
        if (override['isActive'] != null) {
          _isActive = override['isActive'];
        }
      });
    }
  }

  List<String> _getUnavailableSizes(List<String> allSizes) {
    return _unavailableSizes;
  }

  List<String> _getUnavailableColors(List<String> allColors) {
    return _unavailableColors;
  }

''';
  
  // Inject _loadOverrides after the end of initState
  content = content.replaceFirst(RegExp(r'_photos = _prioritizePrimaryPhoto\(_photos\);\s+}'), '_photos = _prioritizePrimaryPhoto(_photos);\n  }$loadMethod');

  // Inject currentStoreId detection and StoreOverrideControls in build
  final uiDetection = r'''
                      const SizedBox(height: AppTokens.space24),
                      if (_currentStoreId == null)
                        Builder(
                          builder: (context) {
                            final userEmail = ref.watch(authViewModelProvider).valueOrNull?.email;
                            if (userEmail != null) {
                              FirebaseFirestore.instance.collection('users').doc(userEmail.toLowerCase().trim()).get().then((doc) {
                                final sid = doc.data()?['currentStoreId'] as String?;
                                if (sid != null && mounted) {
                                  setState(() {
                                    _currentStoreId = sid;
                                    _loadOverrides(sid);
                                  });
                                }
                              });
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      if (_currentStoreId != null)
                        StoreOverrideControls(
                          storeId: _currentStoreId!,
                          isIndividual: _isIndividualStoreConfig,
                          onToggleIndividual: (v) => setState(() => _isIndividualStoreConfig = v),
                          allSizes: _sizesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                          allColors: _colorsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                          unavailableSizes: _unavailableSizes,
                          unavailableColors: _unavailableColors,
                          onToggleSize: (size, unavailable) {
                             setState(() {
                               if (unavailable) {
                                 if (!_unavailableSizes.contains(size)) _unavailableSizes.add(size);
                               } else {
                                 _unavailableSizes.remove(size);
                               }
                             });
                          },
                          onToggleColor: (color, unavailable) {
                             setState(() {
                               if (unavailable) {
                                 if (!_unavailableColors.contains(color)) _unavailableColors.add(color);
                               } else {
                                 _unavailableColors.remove(color);
                               }
                             });
                          },
                        ),
''';

  content = content.replaceFirst('                      const SizedBox(height: AppTokens.space24),\n                      SectionCard(', '$uiDetection                      SectionCard(');
  // fallback if newline differs
  content = content.replaceFirst('                      const SizedBox(height: AppTokens.space24),\r\n                      SectionCard(', '$uiDetection                      SectionCard(');

  final overrideSaveLogic = r'''
      tenantId: tenantId ?? widget.product?.tenantId,
      storeOverrides: widget.product?.storeOverrides ?? {},
    );

    // SaaS Overrides Logic
    if (_isIndividualStoreConfig && _currentStoreId != null) {
      final override = {
        'priceRetail': product.priceRetail,
        'priceWholesale': product.priceWholesale,
        'isActive': _isActive,
        'unavailableSizes': _getUnavailableSizes(product.sizes),
        'unavailableColors': _getUnavailableColors(product.colors),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      final newOverrides = Map<String, Map<String, dynamic>>.from(product.storeOverrides);
      newOverrides[_currentStoreId!] = override;
      
      if (widget.product != null) {
        product = widget.product!.copyWith(storeOverrides: newOverrides);
      } else {
        product = product.copyWith(storeOverrides: newOverrides);
      }
    }
''';

  content = content.replaceFirst('tenantId: tenantId ?? widget.product?.tenantId,\n    );', overrideSaveLogic);
  content = content.replaceFirst('tenantId: tenantId ?? widget.product?.tenantId,\r\n    );', overrideSaveLogic);

  file.writeAsStringSync(content);
  print('Refactoring complete!');
}
