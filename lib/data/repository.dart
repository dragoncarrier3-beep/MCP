import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'seed.dart';

class RepoException implements Exception {
  final String message;
  final bool authExpired;
  const RepoException(this.message, {this.authExpired = false});
  @override
  String toString() => message;
}

/// Contract shared by the mock and live implementations.
/// Mosaic desktop remains the system of record. The app never owns financial state.
abstract class MosaicRepository {
  Future<PortfolioSummary> portfolio();
  Future<Quote> quote(String code);
  Future<PriceHistory> history(String code, String range);
  Future<List<Announcement>> announcements(String code);
  Future<List<WatchlistItem>> watchlist();
  Future<List<WatchlistItem>> addToWatchlist(String code);
  Future<List<WatchlistItem>> removeFromWatchlist(String code);
  Future<List<WatchlistItem>> setSecurityAlert(String code, bool on);
  Future<List<ResearchContent>> research({ContentType? type, int page = 0, int pageSize = 6});
  Future<List<Recommendation>> recommendations();
  Future<Recommendation> actionRecommendation(String id, RecStatus status);
  Future<List<StructuredOffer>> offers();
  Future<StructuredOffer> registerInterest(String offerId);
  Future<List<ChatMessage>> messages(String threadId);
  Future<ChatMessage> sendMessage(String threadId, String text);
  Future<AlertPreference> alertPrefs();
  Future<AlertPreference> saveAlertPrefs(AlertPreference p);
  Future<void> registerDevice(String token);
  Future<void> unregisterDevice();
  List<AuditEvent> get auditLog;
}

/// Demo-mode toggles exposed in Settings so reviewers can see error states.
class DemoFlags {
  bool failActions = false;
  bool offline = false;
  Duration latency = const Duration(milliseconds: 650);
}

class MockMosaicRepository implements MosaicRepository {
  MockMosaicRepository(this.prefs, this.flags);
  final SharedPreferences prefs;
  final DemoFlags flags;
  final _audit = <AuditEvent>[];
  final _rand = Random(7);

  @override
  List<AuditEvent> get auditLog => List.unmodifiable(_audit);

  Future<void> _wait({bool action = false}) async {
    await Future.delayed(flags.latency);
    if (flags.offline) throw const RepoException('You appear to be offline. Check your connection and try again.');
    if (action && flags.failActions) throw const RepoException('The Mosaic service did not acknowledge this request (simulated error). Nothing was changed.');
  }

  void _auditEvent(String action, String subject) =>
      _audit.insert(0, AuditEvent(id: 'aud-${_audit.length + 1}', action: action, subject: subject, at: DateTime.now()));

  // ---------- Portfolio ----------
  @override
  Future<PortfolioSummary> portfolio() async {
    await _wait();
    final list = [
      for (final e in Seed.entities)
        EntitySummary(
          e,
          [for (final h in Seed.equities.where((h) => h.entityId == e.id)) Position(h, Seed.securities[h.code]!)],
          Seed.structured.where((s) => s.entityId == e.id).toList(),
          Seed.cash.where((c) => c.entityId == e.id).toList(),
        ),
    ];
    return PortfolioSummary(list, Seed.asAt);
  }

  @override
  Future<Quote> quote(String code) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final s = Seed.securities[code];
    if (s == null) throw RepoException('No quote available for $code.');
    return Quote(s, Seed.asAt);
  }

  /// Deterministic random walk that ends exactly at the delayed price.
  @override
  Future<PriceHistory> history(String code, String range) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final s = Seed.securities[code]!;
    final seed = code.codeUnits.fold<int>(range.hashCode, (a, c) => a * 31 + c);
    final r = Random(seed);
    late int n;
    late Duration step;
    late double start;
    switch (range) {
      case '1D':
        n = 25;
        step = const Duration(minutes: 15);
        start = s.prevClose;
      case '1M':
        n = 22;
        step = const Duration(days: 1);
        start = s.price * (1 + (r.nextDouble() - .45) * .10);
      case '3M':
        n = 64;
        step = const Duration(days: 1);
        start = s.price * (1 + (r.nextDouble() - .5) * .18);
      default:
        n = 52;
        step = const Duration(days: 7);
        start = s.price * (1 + (r.nextDouble() - .55) * .32);
    }
    final raw = <double>[start];
    for (var i = 1; i < n; i++) {
      raw.add(raw.last * (1 + (r.nextDouble() - .5) * (range == '1D' ? .006 : .028)));
    }
    // Bend the walk so it starts at `start` and ends at today's price.
    final drift = s.price - raw.last;
    final pts = <PricePoint>[];
    final end = range == '1D' ? DateTime.utc(2026, 10, 19, 23, 0).add(step * (n - 1)) : Seed.asAt;
    for (var i = 0; i < n; i++) {
      final v = raw[i] + drift * (i / (n - 1));
      pts.add(PricePoint(end.subtract(step * (n - 1 - i)), double.parse(v.toStringAsFixed(2))));
    }
    return PriceHistory(code, range, pts, previousClose: range == '1D' ? s.prevClose : null);
  }

  @override
  Future<List<Announcement>> announcements(String code) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final list = Seed.announcements.where((a) => a.code == code).toList()..sort((a, b) => b.at.compareTo(a.at));
    if (list.isEmpty) {
      return [Announcement(id: 'ann-$code-gen', code: code, title: 'Appendix 4C – quarterly cash flow report', at: Seed.aedt(10, 15, 8, 30), body: 'Fictional demo announcement.', pages: 6)];
    }
    return list;
  }

  // ---------- Watchlist ----------
  static const _wlKey = 'demo.watchlist';
  List<WatchlistItem> _readWl() {
    final raw = prefs.getString(_wlKey);
    if (raw == null) return [for (final c in Seed.watchlist) WatchlistItem(c, alerts: c == 'CSL')];
    return [for (final j in jsonDecode(raw) as List) WatchlistItem.fromJson(j)];
  }

  Future<List<WatchlistItem>> _writeWl(List<WatchlistItem> l) async {
    await prefs.setString(_wlKey, jsonEncode([for (final i in l) i.toJson()]));
    return l;
  }

  @override
  Future<List<WatchlistItem>> watchlist() async {
    await _wait();
    return _readWl();
  }

  @override
  Future<List<WatchlistItem>> addToWatchlist(String code) async {
    await _wait(action: true);
    final l = _readWl();
    final i = l.indexWhere((e) => e.code == code);
    if (i >= 0) {
      l[i] = l[i].copyWith(watched: true);
    } else {
      l.add(WatchlistItem(code));
    }
    return _writeWl(l);
  }

  @override
  Future<List<WatchlistItem>> removeFromWatchlist(String code) async {
    await _wait(action: true);
    final l = _readWl();
    final i = l.indexWhere((e) => e.code == code);
    if (i >= 0) {
      // Keep alert preference if it is on; otherwise drop the entry entirely.
      if (l[i].alerts) {
        l[i] = l[i].copyWith(watched: false);
      } else {
        l.removeAt(i);
      }
    }
    return _writeWl(l);
  }

  @override
  Future<List<WatchlistItem>> setSecurityAlert(String code, bool on) async {
    await _wait(action: true);
    final l = _readWl();
    final i = l.indexWhere((e) => e.code == code);
    if (i >= 0) {
      l[i] = l[i].copyWith(alerts: on);
      if (!on && !l[i].watched) l.removeAt(i);
    } else if (on) {
      // Alerts on a held security that is not on the watchlist.
      l.add(WatchlistItem(code, alerts: true, watched: false));
    }
    return _writeWl(l);
  }

  // ---------- Research (paginated) ----------
  @override
  Future<List<ResearchContent>> research({ContentType? type, int page = 0, int pageSize = 6}) async {
    await _wait();
    final all = Seed.research.where((r) => type == null || r.type == type).toList()..sort((a, b) => b.published.compareTo(a.published));
    return all.skip(page * pageSize).take(pageSize).toList();
  }

  // ---------- Recommendations ----------
  static const _recKey = 'demo.recs';
  Map<String, dynamic> get _recState => jsonDecode(prefs.getString(_recKey) ?? '{}');

  @override
  Future<List<Recommendation>> recommendations() async {
    await _wait();
    final st = _recState;
    return [
      for (final r in Seed.recommendations)
        if (st[r.id] != null) r.withStatus(RecStatus.values.byName(st[r.id]['s']), DateTime.parse(st[r.id]['at'])) else r,
    ];
  }

  @override
  Future<Recommendation> actionRecommendation(String id, RecStatus status) async {
    await _wait(action: true);
    final st = _recState;
    if (st[id] != null) throw const RepoException('This recommendation has already been actioned.');
    final at = DateTime.now();
    st[id] = {'s': status.name, 'at': at.toIso8601String()};
    await prefs.setString(_recKey, jsonEncode(st));
    _auditEvent('recommendation.${status.name}', id);
    return Seed.recommendations.firstWhere((r) => r.id == id).withStatus(status, at);
  }

  // ---------- Structured offers ----------
  static const _offKey = 'demo.offers';
  @override
  Future<List<StructuredOffer>> offers() async {
    await _wait();
    final reg = prefs.getStringList(_offKey) ?? [];
    return [for (final o in Seed.offers) reg.contains(o.id) ? o.withStatus(OfferStatus.interestRegistered) : o];
  }

  @override
  Future<StructuredOffer> registerInterest(String offerId) async {
    await _wait(action: true);
    final reg = prefs.getStringList(_offKey) ?? [];
    if (!reg.contains(offerId)) reg.add(offerId);
    await prefs.setStringList(_offKey, reg);
    _auditEvent('offer.interest_registered', offerId);
    return Seed.offers.firstWhere((o) => o.id == offerId).withStatus(OfferStatus.interestRegistered);
  }

  // ---------- Chat ----------
  String _msgKey(String t) => 'demo.msgs.$t';
  @override
  Future<List<ChatMessage>> messages(String threadId) async {
    await _wait();
    final local = [for (final j in jsonDecode(prefs.getString(_msgKey(threadId)) ?? '[]') as List) ChatMessage.fromJson(j)];
    return [...Seed.messages.where((m) => m.threadId == threadId), ...local];
  }

  @override
  Future<ChatMessage> sendMessage(String threadId, String text) async {
    await Future.delayed(Duration(milliseconds: 500 + _rand.nextInt(400)));
    if (flags.offline || flags.failActions) throw const RepoException('Message not sent (simulated failure). Tap to retry.');
    final m = ChatMessage(id: 'c${DateTime.now().microsecondsSinceEpoch}', threadId: threadId, sender: Sender.client, body: TextBody(text), at: DateTime.now(), delivery: Delivery.sent, simulated: true);
    await _persistMsg(m);
    return m;
  }

  Future<void> _persistMsg(ChatMessage m) async {
    final raw = jsonDecode(prefs.getString(_msgKey(m.threadId)) ?? '[]') as List;
    raw.removeWhere((j) => j['id'] == m.id);
    raw.add(m.toJson());
    await prefs.setString(_msgKey(m.threadId), jsonEncode(raw));
  }

  Future<void> persistMessage(ChatMessage m) => _persistMsg(m);

  // ---------- Alerts ----------
  static const _prefKey = 'demo.alertprefs';
  @override
  Future<AlertPreference> alertPrefs() async {
    final raw = prefs.getString(_prefKey);
    if (raw == null) return const AlertPreference();
    final j = jsonDecode(raw);
    return AlertPreference(announcements: j['a'], priceMoves: j['p']);
  }

  @override
  Future<AlertPreference> saveAlertPrefs(AlertPreference p) async {
    await _wait(action: true);
    await prefs.setString(_prefKey, jsonEncode({'a': p.announcements, 'p': p.priceMoves}));
    return p;
  }

  @override
  Future<void> registerDevice(String token) async {}
  @override
  Future<void> unregisterDevice() async {}

  /// Logout: clear all protected demo data.
  Future<void> clearProtected() async {
    for (final k in prefs.getKeys().where((k) => k.startsWith('demo.')).toList()) {
      await prefs.remove(k);
    }
    _audit.clear();
  }
}

/// Live adapter skeleton for MPC's Mosaic APIs. Endpoint paths are placeholders
/// until MPC's technical lead supplies the API documentation.
/// Not used in the demo build.
class LiveMosaicRepository implements MosaicRepository {
  LiveMosaicRepository({required String baseUrl, required Future<String?> Function() accessToken, required Future<bool> Function() refresh})
      : _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 15))) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) async {
        final t = await accessToken();
        if (t != null) o.headers['Authorization'] = 'Bearer $t';
        h.next(o);
      },
      onError: (e, h) async {
        if (e.response?.statusCode == 401 && await refresh()) {
          final t = await accessToken();
          final req = e.requestOptions..headers['Authorization'] = 'Bearer $t';
          return h.resolve(await _dio.fetch(req));
        }
        h.next(e);
      },
    ));
  }
  final Dio _dio;

  Never _todo(String endpoint) => throw UnimplementedError('Map $endpoint once Mosaic API docs are supplied.');

  @override
  Future<PortfolioSummary> portfolio() async => _todo('GET /v1/portfolio');
  @override
  Future<Quote> quote(String code) async => _todo('GET /v1/quotes/$code');
  @override
  Future<PriceHistory> history(String code, String range) async => _todo('GET /v1/quotes/$code/history?range=$range');
  @override
  Future<List<Announcement>> announcements(String code) async => _todo('GET /v1/securities/$code/announcements');
  @override
  Future<List<WatchlistItem>> watchlist() async => _todo('GET /v1/watchlist');
  @override
  Future<List<WatchlistItem>> addToWatchlist(String code) async => _todo('POST /v1/watchlist');
  @override
  Future<List<WatchlistItem>> removeFromWatchlist(String code) async => _todo('DELETE /v1/watchlist/$code');
  @override
  Future<List<WatchlistItem>> setSecurityAlert(String code, bool on) async => _todo('PUT /v1/alerts/securities/$code');
  @override
  Future<List<ResearchContent>> research({ContentType? type, int page = 0, int pageSize = 6}) async => _todo('GET /v1/content');
  @override
  Future<List<Recommendation>> recommendations() async => _todo('GET /v1/recommendations');
  @override
  Future<Recommendation> actionRecommendation(String id, RecStatus status) async => _todo('POST /v1/recommendations/$id/actions');
  @override
  Future<List<StructuredOffer>> offers() async => _todo('GET /v1/structured-offers');
  @override
  Future<StructuredOffer> registerInterest(String offerId) async => _todo('POST /v1/structured-offers/$offerId/interest');
  @override
  Future<List<ChatMessage>> messages(String threadId) async => _todo('GET /v1/threads/$threadId/messages');
  @override
  Future<ChatMessage> sendMessage(String threadId, String text) async => _todo('POST /v1/threads/$threadId/messages');
  @override
  Future<AlertPreference> alertPrefs() async => _todo('GET /v1/alerts/preferences');
  @override
  Future<AlertPreference> saveAlertPrefs(AlertPreference p) async => _todo('PUT /v1/alerts/preferences');
  @override
  Future<void> registerDevice(String token) async => _dio.post('/v1/devices', data: {'token': token});
  @override
  Future<void> unregisterDevice() async => _dio.delete('/v1/devices/current');
  @override
  List<AuditEvent> get auditLog => const [];
}

/// Chat transport: WebSocket in production with a polling fallback.
abstract class ChatTransport {
  Stream<ChatMessage> incoming(String threadId);
  Future<void> close();
}

class PollingChatTransport implements ChatTransport {
  PollingChatTransport(this.repo, {this.interval = const Duration(seconds: 15)});
  final MosaicRepository repo;
  final Duration interval;
  final _ctrl = StreamController<ChatMessage>.broadcast();
  Timer? _timer;

  @override
  Stream<ChatMessage> incoming(String threadId) {
    _timer ??= Timer.periodic(interval, (_) async {
      // In live mode: fetch messages since last cursor and push new ones.
    });
    return _ctrl.stream.where((m) => m.threadId == threadId);
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _ctrl.close();
  }
}
