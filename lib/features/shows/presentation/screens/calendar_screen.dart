import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/show.dart';
import '../providers/show_providers.dart';
import 'show_detail_screen.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key, this.onExploreTap});

  final VoidCallback? onExploreTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingEpisodesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Atualizar agenda',
            onPressed: () => ref.refresh(upcomingEpisodesProvider),
          ),
        ],
      ),
      body: upcomingAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => EmptyState(
          icon: Icons.calendar_today_rounded,
          title: 'Erro ao carregar agenda',
          message: err.toString(),
          actionLabel: 'Tentar novamente',
          onAction: () => ref.refresh(upcomingEpisodesProvider),
        ),
        data: (episodes) {
          if (episodes.isEmpty) {
            return EmptyState(
              icon: Icons.event_busy_rounded,
              title: 'Sem episódios futuros agendados',
              message:
                  'As séries que estás a acompanhar não têm episódios previstos nos próximos 60 dias, ou ainda não adicionaste séries à tua lista.',
              actionLabel: 'Explorar séries',
              onAction: onExploreTap,
            );
          }

          // Group by air date (day-only)
          final grouped = <DateTime, List<UpcomingEpisode>>{};
          for (final ep in episodes) {
            final date = ep.episode.airDate;
            if (date != null) {
              final dayKey = Formatters.dateOnly(date);
              (grouped[dayKey] ??= []).add(ep);
            }
          }

          final sortedDays = grouped.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: sortedDays.length,
            itemBuilder: (context, idx) {
              final day = sortedDays[idx];
              final dayEpisodes = grouped[day]!;
              final headerTitle = Formatters.relativeDayHeader(day);
              final countdownText = Formatters.countdown(day);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day Header with Countdown Badge
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          headerTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.secondary.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            countdownText,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Episodes for this day
                  ...dayEpisodes.map(
                    (item) => _UpcomingEpisodeCard(item: item),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _UpcomingEpisodeCard extends StatelessWidget {
  const _UpcomingEpisodeCard({required this.item});

  final UpcomingEpisode item;

  @override
  Widget build(BuildContext context) {
    final ep = item.episode;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline, width: 0.6),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ShowDetailScreen(showId: item.showId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Show Poster
              AppNetworkImage(
                imageUrl: item.posterUrl,
                width: 54,
                height: 80,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 14),
              // Episode Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.showName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (item.network != null)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.outline,
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              item.network!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Episode Code & Premiere Badge
                    Row(
                      children: [
                        Text(
                          ep.code,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                          ),
                        ),
                        if (item.isSeasonPremiere) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'ESTREIA',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ep.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
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
    );
  }
}
