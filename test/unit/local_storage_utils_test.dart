import 'package:flutter_test/flutter_test.dart';
import 'package:series_app/core/utils/local_storage_utils.dart';

void main() {
  group('LocalStorageUtils', () {
    test('extractFilename handles absolute and relative paths', () {
      expect(
        LocalStorageUtils.extractFilename('/data/user/0/com.seriolab.app/cache/banner.jpg'),
        'banner.jpg',
      );
      expect(
        LocalStorageUtils.extractFilename('/Users/test/Documents/avatar.png'),
        'avatar.png',
      );
      expect(
        LocalStorageUtils.extractFilename('profile_banner_123.jpg'),
        'profile_banner_123.jpg',
      );
      expect(
        LocalStorageUtils.extractFilename(r'C:\Users\app\avatar.png'),
        'avatar.png',
      );
    });

    test('resolveFile safely resolves path synchronously', () {
      final file = LocalStorageUtils.resolveFile('my_avatar.png');
      expect(file, isNotNull);
      expect(file!.path.endsWith('my_avatar.png'), isTrue);
    });
  });
}
