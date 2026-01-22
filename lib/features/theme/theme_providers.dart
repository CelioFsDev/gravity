import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the last selected theme mode for the entire app.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
