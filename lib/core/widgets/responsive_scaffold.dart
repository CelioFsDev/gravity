import 'package:flutter/material.dart';

class ResponsiveScaffold extends StatelessWidget {
  final Widget? body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final Widget? endDrawer;
  final double maxWidth;
  final Color? backgroundColor;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;

  const ResponsiveScaffold({
    super.key,
    this.body,
    this.appBar,
    this.floatingActionButton,
    this.drawer,
    this.endDrawer,
    this.maxWidth = 1200,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.bottomSheet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Scaffold(
            appBar: appBar,
            body: body,
            floatingActionButton: floatingActionButton,
            drawer: drawer,
            endDrawer: endDrawer,
            backgroundColor:
                Colors.transparent, // Let Container handle background
            bottomNavigationBar: bottomNavigationBar,
            bottomSheet: bottomSheet,
          ),
        ),
      ),
    );
  }
}
