import '../../../shows/domain/entities/show.dart';

/// Contract for managing user profile favorites and the Top 5 showcase.
abstract interface class UserProfileRepository {
  /// Toggles whether a series is marked as a user favorite.
  Future<void> toggleFavorite(SeriesModel series);

  /// Sets a specific slot (0 to 4) in the user's Top 5 favorites.
  Future<void> setTopFiveSlot(int index, SeriesModel series);

  /// Removes a series from a specific Top 5 slot.
  Future<void> removeTopFiveSlot(int index);

  /// Reorders a series in the Top 5 from [oldIndex] to [newIndex].
  Future<void> reorderTopFive(int oldIndex, int newIndex);
}
