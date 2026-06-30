// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_role.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentUserStatusHash() => r'8d5bf3d3f34636399008cff5c37d261e06c896d5';

/// Provider to check if the current user is disabled/suspended
///
/// Copied from [currentUserStatus].
@ProviderFor(currentUserStatus)
final currentUserStatusProvider = AutoDisposeStreamProvider<bool>.internal(
  currentUserStatus,
  name: r'currentUserStatusProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentUserStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CurrentUserStatusRef = AutoDisposeStreamProviderRef<bool>;
String _$userRoleStreamHash() => r'0d9fb6bc3ab31b048b20b547cade3482a50b5818';

/// See also [userRoleStream].
@ProviderFor(userRoleStream)
final userRoleStreamProvider = AutoDisposeStreamProvider<UserRole>.internal(
  userRoleStream,
  name: r'userRoleStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userRoleStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef UserRoleStreamRef = AutoDisposeStreamProviderRef<UserRole>;
String _$currentRoleHash() => r'e126be7ccb3a6086a062d0a2520a04b1c6cdb251';

/// See also [CurrentRole].
@ProviderFor(CurrentRole)
final currentRoleProvider =
    AutoDisposeNotifierProvider<CurrentRole, UserRole>.internal(
  CurrentRole.new,
  name: r'currentRoleProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$currentRoleHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentRole = AutoDisposeNotifier<UserRole>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
