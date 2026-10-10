import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/local_storage_utils.dart';
import '../../../shows/domain/entities/show.dart';
import '../../domain/entities/user_settings.dart';
import '../providers/settings_providers.dart';
import 'seriolab_avatar_view.dart';
import 'user_avatar_widget.dart';

/// Modal bottom sheet allowing users to choose an avatar from 3 sources:
/// 1. Thematic preset cinema & series icons
/// 2. TMDB TV show images (posters, backdrops, actor headshots)
/// 3. Custom photo upload via camera or gallery
class AvatarSelectionSheet extends ConsumerStatefulWidget {
  const AvatarSelectionSheet({
    super.key,
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;

  static Future<void> show(BuildContext context, {int initialTabIndex = 0}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AvatarSelectionSheet(initialTabIndex: initialTabIndex),
    );
  }

  @override
  ConsumerState<AvatarSelectionSheet> createState() =>
      _AvatarSelectionSheetState();
}

class _AvatarSelectionSheetState extends ConsumerState<AvatarSelectionSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // TMDB Series Picker State
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLoadingDetails = false;
  String? _seriesErrorMessage;
  List<ShowSummary> _searchResults = [];
  ShowDetails? _selectedShow;

  // Custom Photo State
  bool _isProcessingImage = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _loadInitialSuggestions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSuggestions() async {
    try {
      final repo = ref.read(showRepositoryProvider);
      final suggestions = await repo.getPopularThisWeek();
      if (mounted && _searchResults.isEmpty && _searchController.text.isEmpty) {
        setState(() {
          _searchResults = suggestions.take(12).toList();
        });
      }
    } catch (_) {
      // Non-critical: suggestions fail silently
    }
  }

  Future<void> _searchSeries(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      await _loadInitialSuggestions();
      return;
    }

    setState(() {
      _isSearching = true;
      _seriesErrorMessage = null;
      _selectedShow = null;
    });

    try {
      final repo = ref.read(showRepositoryProvider);
      final results = await repo.search(trimmed);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _seriesErrorMessage = 'Erro ao pesquisar séries: $e';
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _selectShow(int showId) async {
    setState(() {
      _isLoadingDetails = true;
      _seriesErrorMessage = null;
    });

    try {
      final repo = ref.read(showRepositoryProvider);
      final details = await repo.getShowDetails(showId);
      if (mounted) {
        setState(() {
          _selectedShow = details;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _seriesErrorMessage = 'Erro ao carregar detalhes da série: $e';
          _isLoadingDetails = false;
        });
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isProcessingImage = true);

    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked == null) {
        if (mounted) setState(() => _isProcessingImage = false);
        return;
      }

      final savedRelativePath = await LocalStorageUtils.copyToDocumentsDirectory(
        picked.path,
        'avatar',
      );

      await ref.read(settingsControllerProvider.notifier).setAvatarLocalFile(savedRelativePath);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil atualizada com sucesso!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao processar foto: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personalizar Avatar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ícones temáticos, imagens de séries ou a tua foto',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: AppColors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tabs Bar
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.outline.withValues(alpha: 0.5)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.auto_awesome_rounded, size: 18),
                    text: 'Ícones',
                  ),
                  Tab(
                    icon: Icon(Icons.tv_rounded, size: 18),
                    text: 'De Séries',
                  ),
                  Tab(
                    icon: Icon(Icons.add_a_photo_rounded, size: 18),
                    text: 'Carregar Foto',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPresetsTab(settings),
                  _buildSeriesPickerTab(),
                  _buildUploadPhotoTab(settings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Presets Tab
  // ---------------------------------------------------------------------------
  Widget _buildPresetsTab(UserSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Current avatar preview banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              UserAvatarWidget.fromSettings(
                settings: settings,
                size: 46,
                showGlow: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Avatar Atual',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      settings.avatarType == AvatarType.preset
                          ? SeriolabAvatar.getById(settings.avatarId).name
                          : (settings.avatarType == AvatarType.networkUrl
                              ? 'Imagem de Série'
                              : 'Foto Pessoal'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Grid of presets
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: 0.82,
            ),
            itemCount: SeriolabAvatar.presets.length,
            itemBuilder: (context, index) {
              final avatar = SeriolabAvatar.presets[index];
              final isSelected = settings.avatarType == AvatarType.preset &&
                  settings.avatarId == avatar.id;

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  await ref
                      .read(settingsControllerProvider.notifier)
                      .setAvatarPreset(avatar.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Avatar "${avatar.name}" selecionado!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.outline.withValues(alpha: 0.5),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SeriolabAvatarView(
                        avatarId: avatar.id,
                        size: 52,
                        showGlow: isSelected,
                        borderWidth: isSelected ? 2 : 1.5,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        avatar.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        avatar.seriesInspiration,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Series Picker Tab (TMDB Search & Image Gallery)
  // ---------------------------------------------------------------------------
  Widget _buildSeriesPickerTab() {
    if (_selectedShow != null) {
      return _buildSelectedShowImagesView(_selectedShow!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Input Bar
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outline.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _searchSeries,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar série (ex.: Breaking Bad, Arcane)...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  color: AppColors.textSecondary,
                  onPressed: () {
                    _searchController.clear();
                    _searchSeries('');
                  },
                ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  color: AppColors.primary,
                  onPressed: () => _searchSeries(_searchController.text),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_seriesErrorMessage != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _seriesErrorMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (_isSearching || _isLoadingDetails)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'A pesquisar no catálogo do TMDB...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_searchResults.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tv_off_rounded,
                    size: 48,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nenhuma série encontrada',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tenta pesquisar por outro nome ou termo.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: _searchResults.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final show = _searchResults[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _selectShow(show.id),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.outline.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Mini poster thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: show.posterUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: show.posterUrl!,
                                  width: 44,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 44,
                                    height: 60,
                                    color: AppColors.surface,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    width: 44,
                                    height: 60,
                                    color: AppColors.surface,
                                    child: const Icon(
                                      Icons.broken_image_rounded,
                                      size: 20,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 44,
                                  height: 60,
                                  color: AppColors.surface,
                                  child: const Icon(
                                    Icons.movie_rounded,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        // Show info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                show.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (show.firstAirDate != null) ...[
                                    Text(
                                      '${show.firstAirDate!.year}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: Color(0xFFFBBF24),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    show.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// Displays posters, backdrops, and cast images from the selected TMDB show.
  Widget _buildSelectedShowImagesView(ShowDetails show) {
    final images = <({String url, String label, String category})>[];

    if (show.posterUrl != null && show.posterUrl!.isNotEmpty) {
      images.add((
        url: show.posterUrl!,
        label: 'Poster Oficial',
        category: 'Poster',
      ));
    }

    if (show.backdropUrl != null && show.backdropUrl!.isNotEmpty) {
      images.add((
        url: show.backdropUrl!,
        label: 'Cenário Principal',
        category: 'Backdrop',
      ));
    }

    for (final member in show.cast) {
      if (member.profileUrl != null && member.profileUrl!.isNotEmpty) {
        images.add((
          url: member.profileUrl!,
          label: member.name,
          category: member.character.isNotEmpty ? member.character : 'Elenco',
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Return & Title bar
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() => _selectedShow = null);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Voltar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Text(
              show.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Toca numa imagem para defini-la como o teu novo avatar:',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 12),

        if (images.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'Nenhuma imagem de alta qualidade disponível para esta série.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final item = images[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .setAvatarNetworkUrl(item.url);

                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Avatar atualizado a partir de ${show.name} (${item.label})!',
                          ),
                          backgroundColor: const Color(0xFF38BDF8),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.outline.withValues(alpha: 0.5),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CachedNetworkImage(
                            imageUrl: item.url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.surface,
                              child: const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.surface,
                              child: const Icon(
                                Icons.broken_image_rounded,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 5,
                          ),
                          color: AppColors.surface.withValues(alpha: 0.85),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                item.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Upload Photo Tab (Gallery / Camera via image_picker)
  // ---------------------------------------------------------------------------
  Widget _buildUploadPhotoTab(UserSettings settings) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Stack(
              children: [
                UserAvatarWidget.fromSettings(
                  settings: settings,
                  size: 96,
                  showGlow: true,
                  borderWidth: 3,
                ),
                if (_isProcessingImage)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppColors.primary),
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
              'Escolhe uma foto pessoal para o teu perfil',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Option 1: Gallery
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isProcessingImage
                ? null
                : () => _pickImage(ImageSource.gallery),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.outline.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C5CFC).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: Color(0xFF7C5CFC),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Escolher da Galeria',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Carregar foto guardada no teu telemóvel',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Option 2: Camera
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isProcessingImage
                ? null
                : () => _pickImage(ImageSource.camera),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.outline.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      color: Color(0xFF38BDF8),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tirar com a Câmara',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Tirar uma nova fotografia agora mesmo',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
