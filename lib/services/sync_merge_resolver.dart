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
}
