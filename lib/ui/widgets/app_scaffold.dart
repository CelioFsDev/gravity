import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: (useAppBar && hasTitle)
          ? AppBar(
              title: Text(title!),
              actions: actions,
              elevation: 0,
              backgroundColor: Colors.transparent,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: (isDark ? AppTokens.bgDark : AppTokens.bg).withOpacity(0.7),
                  ),
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          // Main Content
          SafeArea(
            bottom: bottomNavigationBar == null,
            child: Center(
              child: _buildContent(context, hasTitle, isDark),
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  Widget _buildContent(BuildContext context, bool hasTitle, bool isDark) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!useAppBar && showHeader && hasTitle)
          _buildGlassHeader(context, isDark),
        if (bottom != null) ...[bottom!],
        Expanded(child: body),
      ],
    );

    if (maxWidth.isFinite) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      );
    }

    return SizedBox(width: double.infinity, child: content);
  }

  Widget _buildGlassHeader(BuildContext context, bool isDark) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space24,
            AppTokens.space20,
            AppTokens.space24,
            AppTokens.space16,
          ),
          decoration: BoxDecoration(
            color: (isDark ? AppTokens.bgDark : AppTokens.bg).withOpacity(0.8),
            border: Border(
              bottom: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title!,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark ? AppTokens.textSecondaryDark : AppTokens.textSecondary,
                            ),
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
      ),
    );
  }
}
