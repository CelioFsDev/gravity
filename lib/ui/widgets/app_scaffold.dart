import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';
import 'package:catalogo_ja/core/providers/global_loading_provider.dart';

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
  Widget build(BuildContext context, WidgetRef ref) {
    final hasTitle = title != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Background Tasks logic
    final _ = ref.watch(globalLoadingProvider);
    final activeTask = ref.watch(globalLoadingProvider.notifier).mainActiveTask();

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
              child: _buildContent(context, ref, hasTitle, isDark, activeTask),
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, bool hasTitle, bool isDark, BackgroundTask? activeTask) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeTask != null) _buildGlobalProgress(context, activeTask),
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

  Widget _buildGlobalProgress(BuildContext context, BackgroundTask task) {
    return Container(
      width: double.infinity,
      color: AppTokens.accentBlue.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space24, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTokens.accentBlue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${task.title}: ${task.message}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTokens.accentBlue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(task.progress * 100).toInt()}%',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTokens.accentBlue),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: task.progress,
            minHeight: 2,
            backgroundColor: AppTokens.accentBlue.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTokens.accentBlue),
          ),
        ],
      ),
    );
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
