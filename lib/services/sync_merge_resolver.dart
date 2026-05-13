class SyncMergeResolver {
  const SyncMergeResolver._();

  static T newest<T>({
    required T local,
    required T remote,
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
  }) {
    return remoteUpdatedAt.isAfter(localUpdatedAt) ? remote : local;
  }

  static bool remoteWins({
    required DateTime localUpdatedAt,
    required DateTime remoteUpdatedAt,
    DateTime? localDeletedAt,
    DateTime? remoteDeletedAt,
  }) {
    final localClock =
        localDeletedAt != null && localDeletedAt.isAfter(localUpdatedAt)
        ? localDeletedAt
        : localUpdatedAt;
    final remoteClock =
        remoteDeletedAt != null && remoteDeletedAt.isAfter(remoteUpdatedAt)
        ? remoteDeletedAt
        : remoteUpdatedAt;
    return remoteClock.isAfter(localClock);
  }
}
