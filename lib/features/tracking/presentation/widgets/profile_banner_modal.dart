import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/local_storage_utils.dart';
import '../../../../core/widgets/modal_drag_handle.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import 'series_backdrop_picker_sheet.dart';

/// Modal bottom sheet presenting banner customization options:
/// - Select TMDB Series Backdrop
/// - Upload Photo from Gallery
/// - Remove Banner (reset to default identity gradient)
class ProfileBannerModal extends ConsumerWidget {
  const ProfileBannerModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ProfileBannerModal(),
    );
  }

  Future<void> _pickFromGallery(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (picked != null) {
        final savedRelativePath = await LocalStorageUtils.copyToDocumentsDirectory(
          picked.path,
          'profile_banner',
        );

        await ref
            .read(settingsControllerProvider.notifier)
            .setProfileBannerPath(savedRelativePath);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.secondary, size: 20),
                  SizedBox(width: 10),
                  Text('Gallery photo applied as banner!'),
                ],
              ),
              backgroundColor: AppColors.surfaceHigh,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.outline),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking photo: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _chooseSeriesBackdrop(BuildContext context) async {
    Navigator.of(context).pop();
    await SeriesBackdropPickerSheet.show(context);
  }

  Future<void> _removeBanner(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    await ref.read(settingsControllerProvider.notifier).clearProfileBanner();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.refresh_rounded, color: AppColors.secondary, size: 20),
              SizedBox(width: 10),
              Text('Banner reset to default gradient.'),
            ],
          ),
          backgroundColor: AppColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.outline),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final hasCustomBanner = settings.hasCustomBanner;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top drag handle
            const ModalDragHandle(topPadding: 0, bottomPadding: 8),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Customize Profile Banner',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.outline),
            const SizedBox(height: 8),

            // Option 1: TMDB Series Backdrop
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.movie_filter_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              title: const Text(
                'Choose Show Backdrop',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: const Text(
                'Search shows and pick an official high-resolution wallpaper (TMDB)',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
              onTap: () => _chooseSeriesBackdrop(context),
            ),

            // Option 2: Gallery Image
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.secondary,
                  size: 22,
                ),
              ),
              title: const Text(
                'Upload from Gallery',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: const Text(
                'Select an image from your device storage',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textMuted,
              ),
              onTap: () => _pickFromGallery(context, ref),
            ),

            // Option 3: Remove Banner (revert to default)
            if (hasCustomBanner) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(color: AppColors.outline),
              ),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Remove Banner',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                subtitle: const Text(
                  'Reset to default Seriolab brand gradient banner',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () => _removeBanner(context, ref),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
