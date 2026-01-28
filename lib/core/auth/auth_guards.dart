import 'auth_user.dart';

/// Toggle only for developer experimentation (never ship with `true` in production).
const bool kEnableDevAdminTools = false;

bool isLoggedIn(AuthUser? user) => user != null;

bool isAdmin(AuthUser? user) => user?.isAdmin ?? false;

/// Reminder: To bootstrap the first admin, update `users/{uid}` in Firestore
/// and set `role = "admin"` manually (the client merges data and never escalates
/// automatically when `kEnableDevAdminTools` is `false`).
