import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
// Removed unused AppSectionHeader import

class AppScaffold extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final double maxWidth;
  final bool showHeader;
  final Widget? bottomNavigationBar;
  final bool useAppBar;
  final Widget? bottom;

  const AppScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.maxWidth = double.infinity,
    this.showHeader = true,
    this.bottomNavigationBar,
    this.useAppBar = false,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: (useAppBar && hasTitle)
          ? AppBar(
              title: Text(title!),
              actions: actions,
              elevation: 0,
              scrolledUnderElevation: 0,
            )
          : null,
      body: SafeArea(
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final resolvedMaxWidth = maxWidth.isFinite
                  ? math.min(maxWidth, constraints.maxWidth)
                  : constraints.maxWidth;

              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: resolvedMaxWidth,
                  height: constraints.maxHeight,
                  child: _buildContent(context, hasTitle),
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  Widget _buildContent(BuildContext context, bool hasTitle) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!useAppBar && showHeader && hasTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space24,
              AppTokens.space24,
              AppTokens.space24,
              AppTokens.space16,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.headlineSmall,
                        overflow: TextOverflow.visible,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(width: AppTokens.space16),
                  Row(mainAxisSize: MainAxisSize.min, children: actions!),
                ],
              ],
            ),
          ),
        if (bottom != null) ...[bottom!],
        Expanded(child: body),
      ],
    );

    return content;
  }
}
