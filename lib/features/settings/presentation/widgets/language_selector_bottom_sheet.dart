import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modal_drag_handle.dart';
import '../providers/settings_providers.dart';

/// Supported language configuration for Seriolab.
class LanguageSelectorOption {
  const LanguageSelectorOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });

  final String code;
  final String name;
  final String nativeName;
  final String flag;

  String get label => '$nativeName $flag';
}

/// Bottom sheet allowing users to change the app language.
///
/// Features:
/// - Clear list of supported languages with native names & country flags.
/// - Checkmark indicator on active language.
/// - Immediate application-wide locale update.
/// - Persistent storage for subsequent app starts.
class LanguageSelectorBottomSheet extends ConsumerWidget {
  const LanguageSelectorBottomSheet({super.key});

  /// All supported application languages.
  static const List<LanguageSelectorOption> supportedLanguages = [
    LanguageSelectorOption(
      code: 'en-US',
      name: 'English (US)',
      nativeName: 'English (US)',
      flag: '🇺🇸',
    ),
    LanguageSelectorOption(
      code: 'pt-PT',
      name: 'Português (Portugal)',
      nativeName: 'Português (Portugal)',
      flag: '🇵🇹',
    ),
    LanguageSelectorOption(
      code: 'pt-BR',
      name: 'Português (Brasil)',
      nativeName: 'Português (Brasil)',
      flag: '🇧🇷',
    ),
    LanguageSelectorOption(
      code: 'es-ES',
      name: 'Español (España)',
      nativeName: 'Español (España)',
      flag: '🇪🇸',
    ),
  ];

  /// Checks if a language code matches a given option.
  static bool isSelected(String? currentCode, String optionCode) {
    if (currentCode == null || currentCode.isEmpty) {
      return optionCode == 'en-US';
    }
    final current = currentCode.toLowerCase().replaceAll('_', '-');
    final target = optionCode.toLowerCase().replaceAll('_', '-');

    if (current == target) return true;
    if (current == 'en' && target == 'en-us') return true;
    if (current == 'pt' && target == 'pt-pt') return true;
    if (current == 'es' && target == 'es-es') return true;

    return false;
  }

  /// Returns user-facing label for a given language code.
  static String getDisplayName(String? code) {
    if (code == null || code.isEmpty) {
      return 'English (US) 🇺🇸';
    }
    for (final option in supportedLanguages) {
      if (isSelected(code, option.code)) {
        return option.label;
      }
    }
    return code;
  }

  /// Opens the language selection bottom sheet modal.
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const LanguageSelectorBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final activeCode = settings.language;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ModalDragHandle(topPadding: 0, bottomPadding: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Idioma da Aplicação',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.outline),
            const SizedBox(height: 4),
            ...supportedLanguages.map((option) {
              final active = isSelected(activeCode, option.code);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: active
                        ? const BorderSide(color: AppColors.primary, width: 1.2)
                        : BorderSide.none,
                  ),
                  tileColor: active
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                  title: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  trailing: active
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                          size: 22,
                        )
                      : null,
                  onTap: () async {
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .setLanguage(option.code);
                    if (context.mounted) {
                      Navigator.of(context).pop(option.code);
                    }
                  },
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
