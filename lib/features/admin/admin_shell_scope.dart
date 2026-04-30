import 'package:flutter/widgets.dart';

class AdminShellScope extends InheritedWidget {
  final bool canOpenDrawer;
  final VoidCallback openDrawer;

  const AdminShellScope({
    super.key,
    required this.canOpenDrawer,
    required this.openDrawer,
    required super.child,
  });

  static AdminShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdminShellScope>();
  }

  @override
  bool updateShouldNotify(AdminShellScope oldWidget) {
    return canOpenDrawer != oldWidget.canOpenDrawer ||
        openDrawer != oldWidget.openDrawer;
  }
}
