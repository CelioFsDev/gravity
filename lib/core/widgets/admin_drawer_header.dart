import 'package:flutter/material.dart';
import 'package:catalogo_ja/ui/theme/app_tokens.dart';

class AdminDrawerHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final IconData icon;

  const AdminDrawerHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.icon = Icons.auto_awesome,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = MediaQuery.sizeOf(context).width;
        final headerWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : (viewportWidth * 0.5).clamp(160.0, 220.0);

        return SizedBox(
          width: headerWidth,
          child: Container(
            padding: const EdgeInsets.all(AppTokens.space12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: imageUrl == null
                          ? LinearGradient(
                              colors: [
                                AppTokens.accentBlue,
                                AppTokens.accentBlue.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: imageUrl != null ? Colors.white : null,
                    ),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(icon, color: Colors.white, size: 22),
                          )
                        : Icon(icon, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: Theme.of(context).hintColor,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
