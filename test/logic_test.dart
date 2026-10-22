import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_demo/core/format.dart';
import 'package:mosaic_demo/data/models.dart';
import 'package:mosaic_demo/data/repository.dart';
import 'package:mosaic_demo/data/seed.dart';
import 'package:mosaic_demo/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> makeContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  c.read(demoFlagsProvider.notifier).flags.latency = Duration.zero;
  addTearDown(c.dispose);
  return c;
}

double cents(double v) => (v * 100).roundToDouble() / 100;

void main() {
  group('Portfolio reconciliation', () {
    test('entity totals reconcile to portfolio total to the cent', () async {
      final c = await makeContainer();
      final p = await c.read(portfolioProvider.future);
      final sumEntities = p.entities.fold<double>(0, (a, e) => a + e.total);
      expect(cents(sumEntities), cents(p.total));
      final a = p.allocation;
      expect(cents(a.equities + a.structured + a.cash), cents(p.total));
      for (final e in p.entities) {
        expect(cents(e.equities + e.structuredValue + e.cashValue), cents(e.total));
      }
      expect(cents(a.pct(a.equities) + a.pct(a.structured) + a.pct(a.cash)), 100.0);
    });

    test('portfolio is approximately A\$2.85m and uses 14 equity positions', () async {
      final c = await makeContainer();
      final p = await c.read(portfolioProvider.future);
      expect(p.allPositions.length, 14);
      expect(p.total, closeTo(2850000, 5000));
    });

    test('P&L is market value minus cost base for every position', () async {
      final c = await makeContainer();
      final p = await c.read(portfolioProvider.future);
      for (final pos in p.allPositions) {
        expect(cents(pos.pnl), cents(pos.holding.units * pos.security.price - pos.holding.units * pos.holding.avgCost));
      }
    });

    test('BHP seeded daily move matches the -7.2% alert', () {
      expect(Seed.securities['BHP']!.changePct, closeTo(-7.2, 0.01));
    });
  });

  group('Formatting', () {
    test('currency and signed values', () {
      expect(Fmt.aud(2850224.6), 'A\$2,850,224.60');
      expect(Fmt.audSigned(1234.5), '+A\$1,234.50');
      expect(Fmt.audSigned(-1234.5), '−A\$1,234.50');
      expect(Fmt.pct(-7.2), '−7.20%');
      expect(Fmt.pct(0.81), '+0.81%');
    });

    test('Sydney time zone handles AEST and AEDT', () {
      // 20 Oct 2026 05:20 UTC is 4:20 pm AEDT.
      expect(Sydney.time(Seed.asAt), '4:20 pm AEDT');
      // 1 Jul 2026 06:00 UTC is 4:00 pm AEST.
      expect(Sydney.time(DateTime.utc(2026, 7, 1, 6)), '4:00 pm AEST');
      // DST begins 4 Oct 2026 at 02:00 AEST (3 Oct 16:00 UTC).
      expect(Sydney.isDst(DateTime.utc(2026, 10, 3, 15, 59)), isFalse);
      expect(Sydney.isDst(DateTime.utc(2026, 10, 3, 16, 0)), isTrue);
    });
  });

  test('chart ranges return different data ending at the delayed price', () async {
    final c = await makeContainer();
    final d = await c.read(historyProvider(('BHP', '1D')).future);
    final y = await c.read(historyProvider(('BHP', '1Y')).future);
    expect(d.points.length, greaterThanOrEqualTo(20));
    expect(y.points.length, greaterThanOrEqualTo(20));
    expect(d.last, Seed.securities['BHP']!.price);
    expect(y.last, Seed.securities['BHP']!.price);
    expect(d.first, isNot(y.first));
    expect(d.previousClose, Seed.securities['BHP']!.prevClose);
  });

  group('Watchlist and alerts', () {
    test('add and remove persists', () async {
      final c = await makeContainer();
      await c.read(watchlistProvider.future);
      await c.read(watchlistProvider.notifier).add('RIO');
      expect(c.read(watchlistProvider).value!.any((w) => w.code == 'RIO' && w.watched), isTrue);
      await c.read(watchlistProvider.notifier).remove('RIO');
      expect(c.read(watchlistProvider).value!.any((w) => w.code == 'RIO'), isFalse);
    });

    test('alert preference persists across a reload', () async {
      final c = await makeContainer();
      await c.read(watchlistProvider.future);
      await c.read(watchlistProvider.notifier).setAlert('BHP', true);
      c.invalidate(watchlistProvider);
      final reloaded = await c.read(watchlistProvider.future);
      expect(reloaded.firstWhere((w) => w.code == 'BHP').alerts, isTrue);

      await c.read(alertPrefsProvider.future);
      await c.read(alertPrefsProvider.notifier).save(const AlertPreference(announcements: false, priceMoves: true));
      c.invalidate(alertPrefsProvider);
      expect((await c.read(alertPrefsProvider.future)).announcements, isFalse);
    });
  });

  group('Recommendations', () {
    test('accept updates status after acknowledgement and records audit', () async {
      final c = await makeContainer();
      await c.read(recsProvider.future);
      expect(c.read(pendingCountProvider), 3);
      await c.read(recsProvider.notifier).act('rec-csl', RecStatus.accepted);
      expect(c.read(recsProvider).value!.firstWhere((r) => r.id == 'rec-csl').status, RecStatus.accepted);
      expect(c.read(pendingCountProvider), 2);
      expect(c.read(repoProvider).auditLog.first.action, 'recommendation.accepted');
    });

    test('decline updates status', () async {
      final c = await makeContainer();
      await c.read(recsProvider.future);
      await c.read(recsProvider.notifier).act('rec-googl', RecStatus.declined);
      expect(c.read(recsProvider).value!.firstWhere((r) => r.id == 'rec-googl').status, RecStatus.declined);
    });

    test('duplicate approval is prevented', () async {
      final c = await makeContainer();
      await c.read(recsProvider.future);
      final n = c.read(recsProvider.notifier);
      final first = n.act('rec-csl', RecStatus.accepted);
      await expectLater(n.act('rec-csl', RecStatus.accepted), throwsA(isA<RepoException>()));
      await first;
      await expectLater(n.act('rec-csl', RecStatus.declined), throwsA(isA<RepoException>()));
    });

    test('failed acknowledgement leaves the status unchanged', () async {
      final c = await makeContainer();
      await c.read(recsProvider.future);
      c.read(demoFlagsProvider.notifier).setFail(true);
      await expectLater(c.read(recsProvider.notifier).act('rec-csl', RecStatus.accepted), throwsA(isA<RepoException>()));
      expect(c.read(recsProvider).value!.firstWhere((r) => r.id == 'rec-csl').status, RecStatus.pending);
      expect(c.read(pendingCountProvider), 3);
    });
  });

  test('structured interest registration persists', () async {
    final c = await makeContainer();
    await c.read(offersProvider.future);
    await c.read(offersProvider.notifier).register('off-growth');
    c.invalidate(offersProvider);
    final o = await c.read(offersProvider.future);
    expect(o.firstWhere((x) => x.id == 'off-growth').status, OfferStatus.interestRegistered);
  });

  test('offers in the demo timeline are open at the as-at date', () {
    for (final o in Seed.offers) {
      expect(o.closes.isAfter(Seed.asAt), isTrue);
    }
  });

  group('Messaging', () {
    test('send adds a message and persists it', () async {
      final c = await makeContainer();
      final before = (await c.read(chatProvider('adviser').future)).length;
      await c.read(chatProvider('adviser').notifier).send('Hello from the test');
      final after = c.read(chatProvider('adviser')).value!;
      expect(after.length, before + 1);
      expect(after.last.delivery, Delivery.sent);
      c.invalidate(chatProvider('adviser'));
      final reloaded = await c.read(chatProvider('adviser').future);
      expect(reloaded.any((m) => m.body is TextBody && (m.body as TextBody).text == 'Hello from the test'), isTrue);
    });

    test('failed delivery keeps the message with a failed status', () async {
      final c = await makeContainer();
      await c.read(chatProvider('desk').future);
      c.read(demoFlagsProvider.notifier).setFail(true);
      await c.read(chatProvider('desk').notifier).send('Will fail');
      final last = c.read(chatProvider('desk')).value!.last;
      expect(last.delivery, Delivery.failed);
      expect((last.body as TextBody).text, 'Will fail');
    });

    test('drafts persist', () async {
      final c = await makeContainer();
      c.read(draftsProvider.notifier).set('adviser', 'Half-written');
      c.invalidate(draftsProvider);
      expect(c.read(draftsProvider)['adviser'], 'Half-written');
    });
  });

  group('Notifications', () {
    test('simulated announcement deep-links to the RIO quote and shows a banner', () async {
      final c = await makeContainer();
      c.read(notificationsProvider.notifier).simulate(AlertKind.announcement);
      final n = c.read(notificationsProvider).first;
      expect(n.route, startsWith('/holdings/quote/RIO'));
      expect(c.read(bannerProvider)?.id, n.id);
    });

    test('simulated adviser message bumps unread count', () async {
      final c = await makeContainer();
      final before = c.read(unreadTotalProvider);
      c.read(notificationsProvider.notifier).simulate(AlertKind.message);
      expect(c.read(unreadTotalProvider), before + 1);
    });
  });

  group('Session', () {
    test('token expiry signs out with a notice', () async {
      final c = await makeContainer();
      c.read(sessionProvider.notifier).startDemo();
      expect(c.read(sessionProvider).status, SessionStatus.active);
      c.read(sessionProvider.notifier).expireToken();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(sessionProvider).status, SessionStatus.signedOut);
      expect(c.read(sessionProvider).notice, contains('expired'));
    });

    test('logout clears protected demo data', () async {
      final c = await makeContainer();
      c.read(sessionProvider.notifier).startDemo();
      await c.read(recsProvider.future);
      await c.read(recsProvider.notifier).act('rec-csl', RecStatus.accepted);
      await c.read(sessionProvider.notifier).signOut();
      final prefs = c.read(prefsProvider);
      expect(prefs.getKeys().where((k) => k.startsWith('demo.')), isEmpty);
      final recs = await c.read(recsProvider.future);
      expect(recs.firstWhere((r) => r.id == 'rec-csl').status, RecStatus.pending);
    });

    test('lock and unlock', () async {
      final c = await makeContainer();
      final s = c.read(sessionProvider.notifier);
      s.startDemo();
      s.lock();
      expect(c.read(sessionProvider).status, SessionStatus.locked);
      s.unlock();
      expect(c.read(sessionProvider).status, SessionStatus.active);
    });
  });

  test('offline mode surfaces a network error', () async {
    final c = await makeContainer();
    c.read(demoFlagsProvider.notifier).setOffline(true);
    await expectLater(c.read(repoProvider).portfolio(), throwsA(isA<RepoException>()));
  });
}
