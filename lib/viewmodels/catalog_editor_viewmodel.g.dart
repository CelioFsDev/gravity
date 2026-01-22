// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_editor_viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$catalogEditorViewModelHash() =>
    r'84420fcd8b46eba41aed33853410635958b229ad';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$CatalogEditorViewModel
    extends BuildlessAutoDisposeNotifier<CatalogEditorState> {
  late final Catalog? initialCatalog;

  CatalogEditorState build(
    Catalog? initialCatalog,
  );
}

/// See also [CatalogEditorViewModel].
@ProviderFor(CatalogEditorViewModel)
const catalogEditorViewModelProvider = CatalogEditorViewModelFamily();

/// See also [CatalogEditorViewModel].
class CatalogEditorViewModelFamily extends Family<CatalogEditorState> {
  /// See also [CatalogEditorViewModel].
  const CatalogEditorViewModelFamily();

  /// See also [CatalogEditorViewModel].
  CatalogEditorViewModelProvider call(
    Catalog? initialCatalog,
  ) {
    return CatalogEditorViewModelProvider(
      initialCatalog,
    );
  }

  @override
  CatalogEditorViewModelProvider getProviderOverride(
    covariant CatalogEditorViewModelProvider provider,
  ) {
    return call(
      provider.initialCatalog,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'catalogEditorViewModelProvider';
}

/// See also [CatalogEditorViewModel].
class CatalogEditorViewModelProvider extends AutoDisposeNotifierProviderImpl<
    CatalogEditorViewModel, CatalogEditorState> {
  /// See also [CatalogEditorViewModel].
  CatalogEditorViewModelProvider(
    Catalog? initialCatalog,
  ) : this._internal(
          () => CatalogEditorViewModel()..initialCatalog = initialCatalog,
          from: catalogEditorViewModelProvider,
          name: r'catalogEditorViewModelProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$catalogEditorViewModelHash,
          dependencies: CatalogEditorViewModelFamily._dependencies,
          allTransitiveDependencies:
              CatalogEditorViewModelFamily._allTransitiveDependencies,
          initialCatalog: initialCatalog,
        );

  CatalogEditorViewModelProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.initialCatalog,
  }) : super.internal();

  final Catalog? initialCatalog;

  @override
  CatalogEditorState runNotifierBuild(
    covariant CatalogEditorViewModel notifier,
  ) {
    return notifier.build(
      initialCatalog,
    );
  }

  @override
  Override overrideWith(CatalogEditorViewModel Function() create) {
    return ProviderOverride(
      origin: this,
      override: CatalogEditorViewModelProvider._internal(
        () => create()..initialCatalog = initialCatalog,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        initialCatalog: initialCatalog,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<CatalogEditorViewModel, CatalogEditorState>
      createElement() {
    return _CatalogEditorViewModelProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CatalogEditorViewModelProvider &&
        other.initialCatalog == initialCatalog;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, initialCatalog.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin CatalogEditorViewModelRef
    on AutoDisposeNotifierProviderRef<CatalogEditorState> {
  /// The parameter `initialCatalog` of this provider.
  Catalog? get initialCatalog;
}

class _CatalogEditorViewModelProviderElement
    extends AutoDisposeNotifierProviderElement<CatalogEditorViewModel,
        CatalogEditorState> with CatalogEditorViewModelRef {
  _CatalogEditorViewModelProviderElement(super.provider);

  @override
  Catalog? get initialCatalog =>
      (origin as CatalogEditorViewModelProvider).initialCatalog;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
