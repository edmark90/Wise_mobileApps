/// Central registry of cache keys used by the SWR cache.
///
/// Keep every key here so it is trivial to see which resources are cached,
/// which TTLs they use, and to invalidate them after mutations.
abstract final class CacheKeys {
  /// Upcoming collection schedules (7-day window).
  static const String schedules = 'collection_schedules';

  /// Current user's profile.
  static const String profile = 'user_profile';
}
