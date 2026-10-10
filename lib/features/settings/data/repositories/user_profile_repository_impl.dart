import '../../../shows/domain/entities/show.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/user_profile_repository.dart';

/// Implementation of [UserProfileRepository] backed by [SettingsRepository].
class UserProfileRepositoryImpl implements UserProfileRepository {
  UserProfileRepositoryImpl(this._settingsRepo);

  final SettingsRepository _settingsRepo;

  @override
  Future<void> toggleFavorite(SeriesModel series) async {
    final current = await _settingsRepo.getSettings();
    final list = List<int>.from(current.favoritedShowIds);
    if (list.contains(series.id)) {
      list.remove(series.id);
    } else {
      list.add(series.id);
    }
    await _settingsRepo.saveSettings(current.copyWith(favoritedShowIds: list));
  }

  @override
  Future<void> setTopFiveSlot(int index, SeriesModel series) async {
    if (index < 0 || index >= 5) return;
    final current = await _settingsRepo.getSettings();
    final list = List<int>.from(current.favoriteShowIds);
    list.remove(series.id);
    if (index < list.length) {
      list[index] = series.id;
    } else {
      list.add(series.id);
    }
    final clamped = list.length > 5 ? list.sublist(0, 5) : list;
    await _settingsRepo.saveSettings(current.copyWith(favoriteShowIds: clamped));
  }

  @override
  Future<void> removeTopFiveSlot(int index) async {
    final current = await _settingsRepo.getSettings();
    final list = List<int>.from(current.favoriteShowIds);
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await _settingsRepo.saveSettings(current.copyWith(favoriteShowIds: list));
    }
  }

  @override
  Future<void> reorderTopFive(int oldIndex, int newIndex) async {
    final current = await _settingsRepo.getSettings();
    final list = List<int>.from(current.favoriteShowIds);
    if (oldIndex >= 0 && oldIndex < list.length) {
      final item = list.removeAt(oldIndex);
      final targetIndex = newIndex.clamp(0, list.length);
      list.insert(targetIndex, item);
      final clamped = list.length > 5 ? list.sublist(0, 5) : list;
      await _settingsRepo.saveSettings(current.copyWith(favoriteShowIds: clamped));
    }
  }
}
