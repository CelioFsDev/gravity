// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_role.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentUserStatusHash() => r'15c18a9eb988dcb5ef4abcff8bb6166b2eda6888';

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
String _$userRoleStreamHash() => r'db15faf92e74652dd41354f0e6dd46aa8148a505';

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
String _$currentRoleHash() => r'4258720c760c99fefa8e56cd7d52a13d80f2685f';

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
