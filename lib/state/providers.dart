import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../data/seed.dart';

final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('override in main'));

// ---------------- Demo flags ----------------
class DemoFlagsState {
  final bool failActions, offline;
  const DemoFlagsState({this.failActions = false, this.offline = false});
}

class DemoFlagsNotifier extends Notifier<DemoFlagsState> {
  final flags = DemoFlags();
  @override
  DemoFlagsState build() => const DemoFlagsState();
  void setFail(bool v) {
    flags.failActions = v;
    state = DemoFlagsState(failActions: v, offline: state.offline);
  }

  void setOffline(bool v) {
    flags.offline = v;
    state = DemoFlagsState(failActions: state.failActions, offline: v);
  }
}

final demoFlagsProvider = NotifierProvider<DemoFlagsNotifier, DemoFlagsState>(DemoFlagsNotifier.new);

final repoProvider = Provider<MockMosaicRepository>((ref) {
  return MockMosaicRepository(ref.watch(prefsProvider), ref.read(demoFlagsProvider.notifier).flags);
});

// ---------------- Theme ----------------
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final v = ref.read(prefsProvider).getString('ui.theme');
    return ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.light);
  }

  void set(ThemeMode m) {
    state = m;
    ref.read(prefsProvider).setString('ui.theme', m.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// ---------------- Session ----------------
enum SessionStatus { signedOut, active, locked }

class SessionState {
  final SessionStatus status;
  final bool biometricEnabled, biometricPrompted;
  final String? notice;
  const SessionState({this.status = SessionStatus.signedOut, this.biometricEnabled = false, this.biometricPrompted = false, this.notice});
  SessionState copyWith({SessionStatus? status, bool? biometricEnabled, bool? biometricPrompted, String? notice, bool clearNotice = false}) => SessionState(
        status: status ?? this.status,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        biometricPrompted: biometricPrompted ?? this.biometricPrompted,
        notice: clearNotice ? null : (notice ?? this.notice),
      );
}

/// Session rules: lock after 5 min in background; sign out after 30 min of
/// inactivity or on token expiry, whichever comes first.
/// In production the access/refresh tokens live in Keychain/Keystore via
/// flutter_secure_storage. The demo issues no real tokens.
class SessionNotifier extends Notifier<SessionState> {
  static const backgroundLock = Duration(minutes: 5);
  static const inactivityLimit = Duration(minutes: 30);
  Timer? _idle;
  DateTime? _backgroundedAt;

  @override
  SessionState build() {
    ref.onDispose(() => _idle?.cancel());
    final p = ref.read(prefsProvider);
    return SessionState(biometricEnabled: p.getBool('session.bio') ?? false, biometricPrompted: p.getBool('session.bioPrompted') ?? false);
  }

  void startDemo() {
    state = state.copyWith(status: SessionStatus.active, clearNotice: true);
    touch();
  }

  void touch() {
    if (state.status != SessionStatus.active) return;
    _idle?.cancel();
    _idle = Timer(inactivityLimit, () => signOut(notice: 'You were signed out after 30 minutes of inactivity.'));
  }

  void lock() {
    if (state.status == SessionStatus.active) state = state.copyWith(status: SessionStatus.locked);
  }

  void unlock() {
    state = state.copyWith(status: SessionStatus.active, clearNotice: true);
    touch();
  }

  void onBackground() => _backgroundedAt = DateTime.now();
  void onForeground() {
    final b = _backgroundedAt;
    _backgroundedAt = null;
    if (b != null && DateTime.now().difference(b) >= backgroundLock) lock();
  }

  void setBiometric(bool on) {
    final p = ref.read(prefsProvider);
    p.setBool('session.bio', on);
    p.setBool('session.bioPrompted', true);
    state = state.copyWith(biometricEnabled: on, biometricPrompted: true);
  }

  void expireToken() => signOut(notice: 'Your session expired. Please sign in again.');

  Future<void> signOut({String? notice}) async {
    _idle?.cancel();
    await ref.read(repoProvider).unregisterDevice();
    await ref.read(repoProvider).clearProtected();
    ref.invalidate(portfolioProvider);
    ref.invalidate(watchlistProvider);
    ref.invalidate(recsProvider);
    ref.invalidate(offersProvider);
    ref.invalidate(chatProvider);
    ref.invalidate(unreadProvider);
    ref.invalidate(draftsProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(alertPrefsProvider);
    state = state.copyWith(status: SessionStatus.signedOut, notice: notice, clearNotice: notice == null);
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

// ---------------- Portfolio ----------------
final portfolioProvider = FutureProvider<PortfolioSummary>((ref) => ref.watch(repoProvider).portfolio());

final quoteProvider = FutureProvider.family<Quote, String>((ref, code) => ref.watch(repoProvider).quote(code));

final historyProvider = FutureProvider.family<PriceHistory, (String, String)>((ref, k) => ref.watch(repoProvider).history(k.$1, k.$2));

final announcementsProvider = FutureProvider.family<List<Announcement>, String>((ref, code) => ref.watch(repoProvider).announcements(code));

// ---------------- Watchlist ----------------
class WatchlistNotifier extends AsyncNotifier<List<WatchlistItem>> {
  final busy = <String>{};
  @override
  Future<List<WatchlistItem>> build() => ref.read(repoProvider).watchlist();

  Future<void> _run(String code, Future<List<WatchlistItem>> Function() f) async {
    if (busy.contains(code)) return;
    busy.add(code);
    try {
      state = AsyncData(await f());
    } finally {
      busy.remove(code);
    }
  }

  Future<void> add(String code) => _run(code, () => ref.read(repoProvider).addToWatchlist(code));
  Future<void> remove(String code) => _run(code, () => ref.read(repoProvider).removeFromWatchlist(code));
  Future<void> setAlert(String code, bool on) => _run(code, () => ref.read(repoProvider).setSecurityAlert(code, on));
}

final watchlistProvider = AsyncNotifierProvider<WatchlistNotifier, List<WatchlistItem>>(WatchlistNotifier.new);

// ---------------- Alerts preferences ----------------
class AlertPrefsNotifier extends AsyncNotifier<AlertPreference> {
  @override
  Future<AlertPreference> build() => ref.read(repoProvider).alertPrefs();
  Future<void> save(AlertPreference p) async {
    final prev = state;
    state = AsyncData(p); // Safe, reversible optimistic toggle.
    try {
      await ref.read(repoProvider).saveAlertPrefs(p);
    } catch (e) {
      state = prev;
      rethrow;
    }
  }
}

final alertPrefsProvider = AsyncNotifierProvider<AlertPrefsNotifier, AlertPreference>(AlertPrefsNotifier.new);

// ---------------- Recommendations ----------------
class RecsNotifier extends AsyncNotifier<List<Recommendation>> {
  final inFlight = <String>{};
  @override
  Future<List<Recommendation>> build() => ref.read(repoProvider).recommendations();

  /// Status changes only after the repository acknowledges. No optimistic update.
  Future<void> act(String id, RecStatus s) async {
    if (inFlight.contains(id)) throw const RepoException('This request is already being sent.');
    inFlight.add(id);
    try {
      final updated = await ref.read(repoProvider).actionRecommendation(id, s);
      state = AsyncData([for (final r in state.value ?? <Recommendation>[]) r.id == id ? updated : r]);
    } finally {
      inFlight.remove(id);
    }
  }
}

final recsProvider = AsyncNotifierProvider<RecsNotifier, List<Recommendation>>(RecsNotifier.new);

final pendingCountProvider = Provider<int>((ref) => ref.watch(recsProvider).value?.where((r) => r.status == RecStatus.pending).length ?? 3);

// ---------------- Structured offers ----------------
class OffersNotifier extends AsyncNotifier<List<StructuredOffer>> {
  final inFlight = <String>{};
  @override
  Future<List<StructuredOffer>> build() => ref.read(repoProvider).offers();
  Future<void> register(String id) async {
    if (inFlight.contains(id)) return;
    inFlight.add(id);
    try {
      final o = await ref.read(repoProvider).registerInterest(id);
      state = AsyncData([for (final x in state.value ?? <StructuredOffer>[]) x.id == id ? o : x]);
    } finally {
      inFlight.remove(id);
    }
  }
}

final offersProvider = AsyncNotifierProvider<OffersNotifier, List<StructuredOffer>>(OffersNotifier.new);

// ---------------- Messages ----------------
class UnreadNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {'adviser': 1, 'desk': 1};
  void clear(String t) => state = {...state, t: 0};
  void bump(String t) => state = {...state, t: (state[t] ?? 0) + 1};
}

final unreadProvider = NotifierProvider<UnreadNotifier, Map<String, int>>(UnreadNotifier.new);
final unreadTotalProvider = Provider<int>((ref) => ref.watch(unreadProvider).values.fold(0, (a, b) => a + b));

class DraftsNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => Map<String, String>.from(jsonDecode(ref.read(prefsProvider).getString('demo.drafts') ?? '{}'));
  void set(String thread, String text) {
    state = {...state, thread: text};
    ref.read(prefsProvider).setString('demo.drafts', jsonEncode(state));
  }
}

final draftsProvider = NotifierProvider<DraftsNotifier, Map<String, String>>(DraftsNotifier.new);

/// Typing indicator per thread (simulated adviser reply).
final typingProvider = StateProvider.family<bool, String>((_, __) => false);

class ChatNotifier extends FamilyAsyncNotifier<List<ChatMessage>, String> {
  @override
  Future<List<ChatMessage>> build(String threadId) => ref.read(repoProvider).messages(threadId);

  void _put(ChatMessage m) {
    final l = [...?state.value];
    final i = l.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      l[i] = m;
    } else {
      l.add(m);
    }
    state = AsyncData(l);
  }

  /// Optimistic local bubble ("sending"), confirmed by repository ack.
  /// Failed messages stay in the thread with a retry action. Never silently lost.
  Future<void> send(String text, {String? retryId}) async {
    final repo = ref.read(repoProvider);
    final localId = retryId ?? 'local-${DateTime.now().microsecondsSinceEpoch}';
    final pending = ChatMessage(id: localId, threadId: arg, sender: Sender.client, body: TextBody(text), at: DateTime.now(), delivery: Delivery.sending, simulated: true);
    _put(pending);
    try {
      final sent = await repo.sendMessage(arg, text);
      state = AsyncData([for (final m in state.value!) if (m.id != localId) m, sent]);
      _simulateReceipts(sent);
    } catch (_) {
      _put(pending.withDelivery(Delivery.failed));
    }
  }

  void _simulateReceipts(ChatMessage m) {
    final repo = ref.read(repoProvider);
    Future.delayed(const Duration(milliseconds: 1200), () {
      final d = m.withDelivery(Delivery.delivered);
      _put(d);
      repo.persistMessage(d);
    });
    Future.delayed(const Duration(milliseconds: 2600), () {
      final r = m.withDelivery(Delivery.read);
      _put(r);
      repo.persistMessage(r);
      ref.read(typingProvider(arg).notifier).state = true;
    });
    Future.delayed(const Duration(milliseconds: 5200), () {
      ref.read(typingProvider(arg).notifier).state = false;
      final reply = ChatMessage(
        id: 'r${DateTime.now().microsecondsSinceEpoch}',
        threadId: arg,
        sender: Sender.staff,
        body: const TextBody('Thanks Alex, I\'ll come back to you shortly. (Simulated demo reply. No real adviser received your message.)'),
        at: DateTime.now(),
        simulated: true,
      );
      _put(reply);
      repo.persistMessage(reply);
    });
  }
}

final chatProvider = AsyncNotifierProvider.family<ChatNotifier, List<ChatMessage>, String>(ChatNotifier.new);

// ---------------- Notifications ----------------
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  final _dedupe = <String>{};
  @override
  List<AppNotification> build() => [...Seed.notifications];

  void markRead(String id) => state = [for (final n in state) n.id == id ? n.markRead() : n];

  /// Mirrors server de-dupe key: client + security + type + event + trading date.
  bool _push(AppNotification n, String dedupeKey) {
    if (_dedupe.contains(dedupeKey)) return false;
    _dedupe.add(dedupeKey);
    state = [n, ...state];
    ref.read(bannerProvider.notifier).state = n;
    return true;
  }

  void simulate(AlertKind k) {
    final now = DateTime.now();
    final id = 'sim-${now.millisecondsSinceEpoch}';
    switch (k) {
      case AlertKind.priceMove:
        _push(AppNotification(id: id, kind: k, title: 'FMG down 7.4% today', body: 'Fortescue moved −7.40% vs previous close (simulated, 20 min delayed).', route: '/holdings/quote/FMG?back=Alerts', at: now, simulated: true), 'demo-001|FMG|price|${now.millisecond}');
      case AlertKind.announcement:
        _push(AppNotification(id: id, kind: k, title: 'RIO: price-sensitive announcement', body: 'Third quarter operations review and revised shipments guidance (simulated).', route: '/holdings/quote/RIO?back=Alerts', at: now, simulated: true), 'demo-001|RIO|ann|${now.millisecond}');
      case AlertKind.recommendation:
        _push(AppNotification(id: id, kind: k, title: 'New recommendation: WTC ACCUMULATE', body: 'Your adviser shared a High Conviction idea (simulated).', route: '/recs/rec/rec-wtc?back=Alerts', at: now, simulated: true), 'demo-001|WTC|rec|${now.millisecond}');
      case AlertKind.message:
        ref.read(unreadProvider.notifier).bump('adviser');
        _push(AppNotification(id: id, kind: k, title: 'Message from Your Adviser', body: 'Simulated demo message. No real adviser sent this.', route: '/messages/chat/adviser?back=Alerts', at: now, simulated: true), 'demo-001|msg|$id');
    }
  }
}

final notificationsProvider = NotifierProvider<NotificationsNotifier, List<AppNotification>>(NotificationsNotifier.new);
final bannerProvider = StateProvider<AppNotification?>((_) => null);
final unreadAlertsProvider = Provider<int>((ref) => ref.watch(notificationsProvider).where((n) => !n.read).length);
