import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/core/providers/global_loading_provider.dart';
import 'package:catalogo_ja/features/theme/theme_providers.dart';

class AppScaffold extends ConsumerWidget {
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
  final bool? showBackButton;
  final VoidCallback? onMenuPressed;

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
    this.showBackButton,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTitle = title != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();
    final shouldShowBackButton = showBackButton ?? canPop;
    
    final _ = ref.watch(globalLoadingProvider);
    final activeTask = ref.watch(globalLoadingProvider.notifier).mainActiveTask();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: (useAppBar && hasTitle)
          ? AppBar(
              automaticallyImplyLeading: shouldShowBackButton,
              title: Text(title!),
              actions: actions,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        bottom: bottomNavigationBar == null,
        child: Column(
          children: [
            if (activeTask != null) _buildGlobalProgress(context, activeTask),
            if (!useAppBar && showHeader && hasTitle)
              _buildSimpleHeader(
                context,
                ref,
                isDark,
                shouldShowBackButton,
              ),
            if (bottom != null) ...[bottom!],
            Expanded(child: body),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  Widget _buildSimpleHeader(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    bool shouldShowBackButton,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (shouldShowBackButton) ...[
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(width: 8),
          ] else if (onMenuPressed != null || _hasParentDrawer(context)) ...[
            IconButton(
              onPressed: onMenuPressed ?? () => Scaffold.of(context).openDrawer(),
              icon: Icon(Icons.menu_rounded, size: 24, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.person_outline_rounded,
              color: isDark ? AppTokens.vibrantCyan : AppTokens.electricBlue,
              size: 20,
            ),
            onPressed: () {
              Navigator.of(context).pushNamed('/admin/profile');
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? AppTokens.vibrantCyan : AppTokens.electricBlue,
              size: 20,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).update(
                (state) =>
                    state == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
              );
            },
          ),
        ],
      ),
    );
  }

  bool _hasParentDrawer(BuildContext context) {
    try {
      return Scaffold.maybeOf(context)?.hasDrawer ?? false;
    } catch (_) {
      return false;
    }
  }

  Widget _buildGlobalProgress(BuildContext context, Object activeTask) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activeTask.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
