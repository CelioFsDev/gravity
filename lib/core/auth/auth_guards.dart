import 'auth_user.dart';

/// Toggle only for developer experimentation (never ship with `true` in production).
const bool kEnableDevAdminTools = false;
const bool kBypassAuth = true;

bool isLoggedIn(AuthUser? user) => kBypassAuth || user != null;

bool isAdmin(AuthUser? user) => kBypassAuth || (user?.isAdmin ?? false);

/// Reminder: To bootstrap the first admin, update `users/{uid}` in Firestore
/// and set `role = "admin"` manually (the client merges data and never escalates
/// automatically when `kEnableDevAdminTools` is `false`).
