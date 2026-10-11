import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modal_drag_handle.dart';
import '../../domain/entities/user_settings.dart';
import '../providers/settings_providers.dart';
import 'avatar_selection_sheet.dart';
import 'seriolab_avatar_view.dart';
import 'user_avatar_widget.dart';

/// Modal bottom sheet for editing user profile (avatar, name, username, bio).
class EditProfileSheet extends ConsumerStatefulWidget {
  const EditProfileSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const EditProfileSheet(),
    );
  }

  @override
  ConsumerState<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<EditProfileSheet> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late String _selectedAvatarId;
  late AvatarType _selectedAvatarType;
  late String? _selectedAvatarValue;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsControllerProvider);
    _displayNameController = TextEditingController(text: settings.displayName);
    _usernameController = TextEditingController(text: settings.username);
    _bioController = TextEditingController(text: settings.bio);
    _selectedAvatarId = settings.avatarId;
    _selectedAvatarType = settings.avatarType;
    _selectedAvatarValue = settings.avatarValue;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final cleanUsername = _usernameController.text
        .trim()
        .replaceAll('@', '')
        .toLowerCase();

    ref.read(settingsControllerProvider.notifier).updateProfile(
          displayName: _displayNameController.text.trim(),
          username: cleanUsername,
          bio: _bioController.text.trim(),
          avatarId: _selectedAvatarId,
          avatarType: _selectedAvatarType,
          avatarValue: _selectedAvatarValue,
        );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 20),
            SizedBox(width: 10),
            Text('Perfil atualizado com sucesso!'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag indicator
                const ModalDragHandle(topPadding: 0, bottomPadding: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const Text(
                      'Editar Perfil',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Guardar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Active avatar preview & selector
                Center(
                  child: Stack(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(40),
                        onTap: () async {
                          await AvatarSelectionSheet.show(context);
                          if (mounted) {
                            final current = ref.read(settingsControllerProvider);
                            setState(() {
                              _selectedAvatarId = current.avatarId;
                              _selectedAvatarType = current.avatarType;
                              _selectedAvatarValue = current.avatarValue;
                            });
                          }
                        },
                        child: UserAvatarWidget(
                          avatarId: _selectedAvatarId,
                          avatarType: _selectedAvatarType,
                          avatarValue: _selectedAvatarValue,
                          size: 78,
                          showGlow: true,
                          borderWidth: 2.5,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: InkWell(
                          onTap: () async {
                            await AvatarSelectionSheet.show(context);
                            if (mounted) {
                              final current = ref.read(settingsControllerProvider);
                              setState(() {
                                _selectedAvatarId = current.avatarId;
                                _selectedAvatarType = current.avatarType;
                                _selectedAvatarValue = current.avatarValue;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Center(
                  child: Text(
                    'Escolhe o teu ícone de perfil',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Avatar Presets Row
                SizedBox(
                  height: 64,
                  child: Center(
                    child: ListView.separated(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      itemCount: SeriolabAvatar.presets.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final avatar = SeriolabAvatar.presets[index];
                        final isSelected = _selectedAvatarType == AvatarType.preset &&
                            avatar.id == _selectedAvatarId;

                        return InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () {
                            setState(() {
                              _selectedAvatarId = avatar.id;
                              _selectedAvatarType = AvatarType.preset;
                              _selectedAvatarValue = avatar.id;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 2.2,
                              ),
                            ),
                            child: SeriolabAvatarView(
                              avatarId: avatar.id,
                              size: 44,
                              borderWidth: 0,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await AvatarSelectionSheet.show(context);
                      if (mounted) {
                        final current = ref.read(settingsControllerProvider);
                        setState(() {
                          _selectedAvatarId = current.avatarId;
                          _selectedAvatarType = current.avatarType;
                          _selectedAvatarValue = current.avatarValue;
                        });
                      }
                    },
                    icon: const Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    label: const Text(
                      'Mais opções (Séries TMDB ou Foto)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Form Fields
                const Text(
                  'Nome de Exibição',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _displayNameController,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    hintText: 'O teu nome',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'O nome não pode estar vazio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const Text(
                  'Nome de Utilizador',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Icons.alternate_email_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    hintText: 'username',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'O username não pode estar vazio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const Text(
                  'Bio Curta',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Uma breve frase sobre as tuas séries favoritas...',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
