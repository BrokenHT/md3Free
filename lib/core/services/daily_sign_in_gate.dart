enum DailySignInResult { skipped, completed, failed, accountChanged }

/// A shared lock and durable, account-scoped completion ledger. Failed attempts
/// are never written as completed and can be retried on a later foreground entry.
class DailySignInGate {
  DailySignInGate({
    required this.readDay,
    required this.writeDay,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final Future<String?> Function(String account) readDay;
  final Future<void> Function(String account, String day) writeDay;
  final DateTime Function() clock;
  final Map<String, DateTime> _retryAfter = {};
  Future<DailySignInResult>? _running;
  bool get isRunning => _running != null;

  /// KuGou's daily entitlement uses the service's UTC+8 calendar, including when
  /// the device is travelling in another time zone.
  static String dayKey(DateTime time) {
    final day = time.toUtc().add(const Duration(hours: 8));
    return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }

  Future<void> markCompleted(String account, String day) =>
      writeDay(account, day);

  Future<DailySignInResult> run({
    required String account,
    required bool Function() isCurrentAccount,
    required Future<String> Function() resolveDay,
    required Future<bool> Function(String day) signIn,
  }) async {
    final pending = _running;
    if (pending != null) {
      await pending;
      if (!isCurrentAccount()) return DailySignInResult.accountChanged;
      // Recheck the ledger after the prior request, also when a new account
      // became active while that request was in flight.
    }
    if (_running != null) return DailySignInResult.skipped;
    final job = _run(account, isCurrentAccount, resolveDay, signIn);
    _running = job;
    try {
      return await job;
    } finally {
      if (identical(_running, job)) _running = null;
    }
  }

  Future<DailySignInResult> _run(
    String account,
    bool Function() current,
    Future<String> Function() resolveDay,
    Future<bool> Function(String) signIn,
  ) async {
    if (account.isEmpty || !current()) return DailySignInResult.skipped;
    try {
      final saved = await readDay(account);
      if (!current()) return DailySignInResult.accountChanged;
      if (saved == dayKey(clock())) return DailySignInResult.skipped;
      if (_retryAfter[account]?.isAfter(clock()) ?? false)
        return DailySignInResult.skipped;
      final day = await resolveDay();
      if (!current()) return DailySignInResult.accountChanged;
      if (saved == day) return DailySignInResult.skipped;
      final success = await signIn(day);
      if (!current()) return DailySignInResult.accountChanged;
      if (!success) {
        _retryAfter[account] = clock().add(const Duration(minutes: 1));
        return DailySignInResult.failed;
      }
      await writeDay(account, day);
      _retryAfter.remove(account);
      return DailySignInResult.completed;
    } catch (_) {
      _retryAfter[account] = clock().add(const Duration(minutes: 1));
      return DailySignInResult.failed;
    }
  }
}
