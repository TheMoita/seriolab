import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seriolab/core/di/providers.dart';
import 'package:seriolab/core/widgets/modal_drag_handle.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:seriolab/features/reports/data/repositories/report_repository_impl.dart';
import 'package:seriolab/features/reports/domain/entities/report_model.dart';
import 'package:seriolab/features/reports/presentation/providers/report_providers.dart';
import 'package:seriolab/features/reports/presentation/widgets/report_bottom_sheet.dart';
import 'package:seriolab/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:seriolab/features/settings/presentation/providers/settings_providers.dart';
import 'package:seriolab/features/shows/data/datasources/mock/mock_show_remote_data_source.dart';
import 'package:seriolab/features/shows/data/repositories/episode_review_repository_impl.dart';
import 'package:seriolab/features/shows/data/repositories/show_repository_impl.dart';
import 'package:seriolab/features/shows/domain/entities/episode_review_model.dart';
import 'package:seriolab/features/shows/presentation/providers/episode_review_providers.dart';
import 'package:seriolab/features/shows/presentation/screens/episode_detail_screen.dart';
import 'package:seriolab/features/social/data/repositories/social_repository_impl.dart';
import 'package:seriolab/features/social/presentation/providers/social_providers.dart';
import 'package:seriolab/features/social/presentation/screens/user_profile_screen.dart';
import 'package:seriolab/features/tracking/data/repositories/in_memory_tracking_repository.dart';

class _FakeReportRepository implements ReportRepositoryImpl {
  _FakeReportRepository();

  final List<ReportModel> submitted = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> submitReport(ReportModel report) async {
    submitted.add(report);
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_PT', null);
  });

  group('ReportModel Tests', () {
    test('serializes and deserializes correctly', () {
      final now = DateTime(2026, 10, 11, 15, 30);
      final model = ReportModel(
        id: 'rep_123',
        reporterUserId: 'user_a',
        targetType: ReportTargetType.comment,
        targetId: 'rev_999',
        reportedUserId: 'user_b',
        reason: 'Discurso de ódio ou ofensivo',
        details: 'Comentário muito ofensivo',
        createdAt: now,
        status: ReportStatus.pending,
      );

      final json = model.toJson();
      expect(json['id'], 'rep_123');
      expect(json['reporterUserId'], 'user_a');
      expect(json['targetType'], 'comment');
      expect(json['targetId'], 'rev_999');
      expect(json['reportedUserId'], 'user_b');
      expect(json['reason'], 'Discurso de ódio ou ofensivo');
      expect(json['details'], 'Comentário muito ofensivo');
      expect(json['status'], 'pending');

      final fromJson = ReportModel.fromJson(json);
      expect(fromJson.id, 'rep_123');
      expect(fromJson.targetType, ReportTargetType.comment);
      expect(fromJson.status, ReportStatus.pending);

      final firestoreMap = model.toFirestore();
      expect(firestoreMap['id'], 'rep_123');
      expect(firestoreMap['targetType'], 'comment');
      expect(firestoreMap.containsKey('createdAt'), isTrue);
    });

    test('copyWith updates properties properly', () {
      final model = ReportModel(
        id: 'rep_1',
        reporterUserId: 'u1',
        targetType: ReportTargetType.userProfile,
        targetId: 'u2',
        reportedUserId: 'u2',
        reason: 'Spam',
        createdAt: DateTime.now(),
      );

      final updated = model.copyWith(
        status: ReportStatus.resolved,
        details: 'Resolvido pelo moderador',
      );

      expect(updated.status, ReportStatus.resolved);
      expect(updated.details, 'Resolvido pelo moderador');
      expect(updated.id, 'rep_1');
    });
  });

  group('ReportRepositoryImpl Tests', () {
    test('submits report and saves to local storage without throwing', () async {
      final inMemoryRepo = InMemoryTrackingRepository();
      final reportRepo = ReportRepositoryImpl(
        trackingRepository: inMemoryRepo,
      );

      final model = ReportModel(
        id: 'rep_test',
        reporterUserId: 'u1',
        targetType: ReportTargetType.comment,
        targetId: 'c1',
        reportedUserId: 'u2',
        reason: 'Spam ou publicidade',
        createdAt: DateTime.now(),
      );

      await reportRepo.submitReport(model);

      final stored = await inMemoryRepo.readMeta('report_rep_test');
      expect(stored, isNotNull);
      expect(stored, contains('rep_test'));
      expect(stored, contains('Spam ou publicidade'));
    });
  });

  group('ReportBottomSheet UI Tests', () {
    testWidgets('renders comment report sheet with drag handle, comment reasons and submits',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeRepo = _FakeReportRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reportRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showReportBottomSheet(
                      context: context,
                      targetType: ReportTargetType.comment,
                      targetId: 'review_42',
                      reportedUserId: 'author_99',
                      reportedUsername: 'bad_actor',
                    );
                  },
                  child: const Text('Abrir Denúncia'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir Denúncia'));
      await tester.pumpAndSettle();

      // Drag handle
      expect(find.byType(ModalDragHandle), findsOneWidget);

      // Title & Subtitle
      expect(find.text('Denunciar Comentário'), findsOneWidget);
      expect(
        find.text('Ajuda-nos a manter a comunidade do Seriolab segura.'),
        findsOneWidget,
      );

      // Comment-specific reasons
      expect(find.text('Discurso de ódio ou ofensivo'), findsOneWidget);
      expect(find.text('Spam ou publicidade'), findsOneWidget);
      expect(find.text('Spoilers não sinalizados'), findsOneWidget);
      expect(find.text('Outro motivo'), findsOneWidget);

      // Select 'Spoilers não sinalizados'
      await tester.tap(find.text('Spoilers não sinalizados'));
      await tester.pumpAndSettle();

      // Enter additional details
      await tester.enterText(
        find.byType(TextField),
        'Revelou o final da temporada no comentário!',
      );
      await tester.pumpAndSettle();

      // Submit
      final submitButton = find.widgetWithText(ElevatedButton, 'Submeter Denúncia');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify report was submitted to repo
      expect(fakeRepo.submitted.length, 1);
      final report = fakeRepo.submitted.first;
      expect(report.targetType, ReportTargetType.comment);
      expect(report.targetId, 'review_42');
      expect(report.reportedUserId, 'author_99');
      expect(report.reason, 'Spoilers não sinalizados');
      expect(report.details, 'Revelou o final da temporada no comentário!');

      // SnackBar feedback is rendered
      expect(
        find.text(
          'Denúncia enviada com sucesso. Obrigado por manteres a comunidade segura.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders user profile report sheet with profile-specific reasons and cancel',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showReportBottomSheet(
                      context: context,
                      targetType: ReportTargetType.userProfile,
                      targetId: 'user_target',
                      reportedUserId: 'user_target',
                    );
                  },
                  child: const Text('Abrir Denúncia Perfil'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir Denúncia Perfil'));
      await tester.pumpAndSettle();

      // Title
      expect(find.text('Denunciar Perfil'), findsOneWidget);

      // Profile-specific reasons
      expect(find.text('Foto, avatar ou banner impróprio'), findsOneWidget);
      expect(find.text('Nickname ou biografia inadequada'), findsOneWidget);
      expect(find.text('Spam ou publicidade'), findsOneWidget);
      expect(find.text('Outro motivo'), findsOneWidget);

      // Tap 'Cancelar'
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Sheet is dismissed
      expect(find.text('Denunciar Perfil'), findsNothing);
    });
  });

  group('UserProfileScreen Reporting Integration', () {
    testWidgets('renders options button and report action for other users',
        (tester) async {
      final trackingRepo = InMemoryTrackingRepository();
      final settingsRepo = SettingsRepositoryImpl(trackingRepo);
      final socialRepo = SocialRepositoryImpl(
        settingsRepo: settingsRepo,
        trackingRepo: trackingRepo,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(trackingRepo),
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
            socialRepositoryProvider.overrideWithValue(socialRepo),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(userId: 'user_marta'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Displays user profile header
      expect(find.text('Marta Silva'), findsOneWidget);
      expect(find.text('@martas'), findsOneWidget);

      // Report flag button next to follow action button
      expect(find.byTooltip('Denunciar utilizador'), findsOneWidget);

      // 3-dots more options in top-right banner
      expect(find.byTooltip('Mais opções'), findsOneWidget);
    });
  });

  group('EpisodeDetailScreen Reporting Integration', () {
    testWidgets('allows reporting other user comment and hides it locally',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final inMemoryRepo = InMemoryTrackingRepository();
      final testRepo = ShowRepositoryImpl(
        remote: MockShowRemoteDataSource(latency: Duration.zero),
        isUsingMockData: true,
      );

      final fakeReportRepo = _FakeReportRepository();

      // Seed a review by another user
      final review = EpisodeReviewModel(
        id: 'rev_test_1',
        episodeKeyString: '100088_s1_e1',
        userId: 'other_user',
        username: 'other_user',
        userDisplayName: 'Outro Utilizador',
        comment: 'Comentário problemático para denunciar',
        createdAt: DateTime.now(),
      );
      final epReviewRepo = EpisodeReviewRepositoryImpl(inMemoryRepo);
      await epReviewRepo.addReview(review);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trackingRepositoryProvider.overrideWithValue(inMemoryRepo),
            showRepositoryProvider.overrideWithValue(testRepo),
            episodeReviewRepositoryProvider.overrideWithValue(epReviewRepo),
            reportRepositoryProvider.overrideWithValue(fakeReportRepo),
          ],
          child: const MaterialApp(
            home: EpisodeDetailScreen(
              seriesId: 100088,
              seasonNumber: 1,
              episodeNumber: 1,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll down to Community section
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Comment should be displayed
      final commentFinder = find.text('Comentário problemático para denunciar');
      expect(commentFinder, findsOneWidget);

      // Tap comment options menu (3 dots)
      final optionsButton = find.byTooltip('Opções do comentário');
      expect(optionsButton, findsOneWidget);
      await tester.tap(optionsButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap 'Denunciar comentário'
      expect(find.text('Denunciar comentário'), findsOneWidget);
      await tester.tap(find.text('Denunciar comentário'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Report sheet opened
      expect(find.text('Denunciar Comentário'), findsOneWidget);

      // Submit report
      final submitButton = find.widgetWithText(ElevatedButton, 'Submeter Denúncia');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify report was submitted
      expect(fakeReportRepo.submitted.length, 1);
      expect(fakeReportRepo.submitted.first.targetId, 'rev_test_1');

      // The comment is now hidden locally from the screen
      expect(find.text('Comentário problemático para denunciar'), findsNothing);
    });
  });
}

