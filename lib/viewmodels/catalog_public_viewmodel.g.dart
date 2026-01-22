// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_public_viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$catalogPublicHash() => r'36710d655133e93661b4e046a044e26d8a7be864';

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

/// See also [catalogPublic].
@ProviderFor(catalogPublic)
const catalogPublicProvider = CatalogPublicFamily();

/// See also [catalogPublic].
class CatalogPublicFamily extends Family<AsyncValue<PublicCatalogData?>> {
  /// See also [catalogPublic].
  const CatalogPublicFamily();

  /// See also [catalogPublic].
  CatalogPublicProvider call(
    String slug,
  ) {
    return CatalogPublicProvider(
      slug,
    );
  }

  @override
  CatalogPublicProvider getProviderOverride(
    covariant CatalogPublicProvider provider,
  ) {
    return call(
      provider.slug,
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
  String? get name => r'catalogPublicProvider';
}

/// See also [catalogPublic].
class CatalogPublicProvider
    extends AutoDisposeFutureProvider<PublicCatalogData?> {
  /// See also [catalogPublic].
  CatalogPublicProvider(
    String slug,
  ) : this._internal(
          (ref) => catalogPublic(
            ref as CatalogPublicRef,
            slug,
          ),
          from: catalogPublicProvider,
          name: r'catalogPublicProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$catalogPublicHash,
          dependencies: CatalogPublicFamily._dependencies,
          allTransitiveDependencies:
              CatalogPublicFamily._allTransitiveDependencies,
          slug: slug,
        );

  CatalogPublicProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.slug,
  }) : super.internal();

  final String slug;

  @override
  Override overrideWith(
    FutureOr<PublicCatalogData?> Function(CatalogPublicRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CatalogPublicProvider._internal(
        (ref) => create(ref as CatalogPublicRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        slug: slug,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<PublicCatalogData?> createElement() {
    return _CatalogPublicProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CatalogPublicProvider && other.slug == slug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, slug.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin CatalogPublicRef on AutoDisposeFutureProviderRef<PublicCatalogData?> {
  /// The parameter `slug` of this provider.
  String get slug;
}

class _CatalogPublicProviderElement
    extends AutoDisposeFutureProviderElement<PublicCatalogData?>
    with CatalogPublicRef {
  _CatalogPublicProviderElement(super.provider);

  @override
  String get slug => (origin as CatalogPublicProvider).slug;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
