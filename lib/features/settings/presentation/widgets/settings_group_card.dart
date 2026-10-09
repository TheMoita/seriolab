import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A styled group container matching the iOS/Material 3 Settings pattern,
/// styled with the Seriolab Midnight Indigo & Violet design system.
class SettingsGroupCard extends StatelessWidget {
  const SettingsGroupCard({
    super.key,
    this.title,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              title!.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.outline, width: 0.8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1)
                      const Divider(
                        height: 1,
                        thickness: 0.7,
                        color: AppColors.outline,
                        indent: 52,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
