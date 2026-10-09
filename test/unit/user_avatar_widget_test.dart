import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:series_app/features/settings/domain/entities/user_settings.dart';
import 'package:series_app/features/settings/presentation/widgets/seriolab_avatar_view.dart';
import 'package:series_app/features/settings/presentation/widgets/user_avatar_widget.dart';

void main() {
  group('UserAvatarWidget', () {
    testWidgets('renders preset avatar icon correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatarWidget(
              avatarType: AvatarType.preset,
              avatarValue: 'iris',
              avatarId: 'iris',
            ),
          ),
        ),
      );

      expect(find.byType(SeriolabAvatarView), findsOneWidget);
      expect(find.byIcon(Icons.movie_filter_rounded), findsOneWidget);
    });

    testWidgets('falls back to default preset when local file does not exist',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatarWidget(
              avatarType: AvatarType.localFile,
              avatarValue: '/invalid/path/nonexistent.jpg',
              avatarId: 'tv_retro',
            ),
          ),
        ),
      );

      expect(find.byType(SeriolabAvatarView), findsOneWidget);
      expect(find.byIcon(Icons.tv_rounded), findsOneWidget);
    });

    testWidgets('renders networkUrl with fallback icon on error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatarWidget(
              avatarType: AvatarType.networkUrl,
              avatarValue: 'https://invalid-host-for-avatar-test.local/image.png',
              avatarId: 'tv_retro',
            ),
          ),
        ),
      );

      // Should render without throwing exceptions
      expect(find.byType(UserAvatarWidget), findsOneWidget);
    });

    testWidgets('factory fromSettings works with default UserSettings',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserAvatarWidget.fromSettings(
              settings: UserSettings.defaultSettings,
              size: 60,
            ),
          ),
        ),
      );

      expect(find.byType(UserAvatarWidget), findsOneWidget);
      expect(find.byType(SeriolabAvatarView), findsOneWidget);
    });
  });
}
