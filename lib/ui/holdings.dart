import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../state/providers.dart';
import 'home.dart';
import 'widgets.dart';

class HoldingsScreen extends ConsumerStatefulWidget {
  const HoldingsScreen({super.key});
  @override
  ConsumerState<HoldingsScreen> createState() => _HoldingsScreenState();
}

class _HoldingsScreenState extends ConsumerState<HoldingsScreen> {
  String seg = 'h';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          TabTitle('Holdings', trailing: [
            IconButton(tooltip: 'Alert settings', constraints: const BoxConstraints(minWidth: 44, minHeight: 44), onPressed: () => showAlertsSheet(context), icon: const Icon(Icons.notifications_none_rounded)),
            IconButton(tooltip: 'Add security to watchlist', constraints: const BoxConstraints(minWidth: 44, minHeight: 44), onPressed: () => openIn(context, 'search', back: 'Holdings'), icon: const Icon(Icons.add_rounded)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Segmented<String>(values: const ['h', 'w'], labels: const ['Holdings', 'Watchlist'], selected: seg, onChanged: (v) => setState(() => seg = v)),
          ),
          Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: seg == 'h' ? const _HoldingsList(key: ValueKey('h')) : const WatchlistView(key: ValueKey('w')))),
        ]),
      ),
    );
  }
}

class _HoldingsList extends ConsumerWidget {
  const _HoldingsList({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pf = ref.watch(portfolioProvider);
    final wl = ref.watch(watchlistProvider).value ?? [];
    return RefreshIndicator(
      color: Brand.bronze,
      onRefresh: () => ref.refresh(portfolioProvider.future),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), children: [
        AsyncBody<PortfolioSummary>(pf, onRetry: () => ref.invalidate(portfolioProvider), builder: (p) {
          final a = p.allocation;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              for (final (k, v, c) in [('Equities', a.equities, context.isDark ? const Color(0xFF6E9BD6) : Brand.navy), ('Structured', a.structured, Brand.bronze), ('Cash', a.cash, Brand.cash)])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: k == 'Cash' ? 0 : 8),
                    child: MCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(width: 18, height: 3, color: c),
                        const SizedBox(height: 8),
                        Text(k, style: TextStyle(color: context.pal.muted, fontSize: 12)),
                        const SizedBox(height: 2),
                        FittedBox(fit: BoxFit.scaleDown, child: Text(Fmt.aud(v, cents: false), style: numStyle(14.5))),
                        Text('${a.pct(v).toStringAsFixed(1)}%', style: numStyle(11.5, weight: FontWeight.w500, color: context.pal.muted)),
                      ]),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            const DelayedBadge(),
            for (final e in p.entities) ...[
              SectionHeader(e.entity.name, action: Fmt.aud(e.total, cents: false), onAction: () => openIn(context, 'entity/${e.entity.id}', back: 'Holdings')),
              MCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (final pos in e.positions)
                    HoldingRow(pos, back: 'Holdings', trailingAlert: _AlertBell(code: pos.security.code, on: wl.any((w) => w.code == pos.security.code && w.alerts))),
                  InkWell(
                    onTap: () => openIn(context, 'entity/${e.entity.id}', back: 'Holdings'),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Flexible(child: Text('View ${e.entity.type.label} detail · structured & cash', overflow: TextOverflow.ellipsis, style: TextStyle(color: context.pal.bronze, fontWeight: FontWeight.w600, fontSize: 13))),
                        Icon(Icons.chevron_right_rounded, color: context.pal.bronze, size: 18),
                      ]),
                    ),
                  ),
                ]),
              ),
            ],
          ]);
        }),
        const LegalFooter(),
      ]),
    );
  }
}

class _AlertBell extends ConsumerWidget {
  const _AlertBell({required this.code, required this.on});
  final String code;
  final bool on;
  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
        tooltip: on ? 'Turn off alerts for $code' : 'Turn on alerts for $code',
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: () async {
          try {
            await ref.read(watchlistProvider.notifier).setAlert(code, !on);
            if (context.mounted) toast(context, on ? 'Alerts off for $code' : 'Alerts on for $code');
          } catch (e) {
            if (context.mounted) toast(context, '$e', error: true);
          }
        },
        icon: Icon(on ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 21, color: on ? context.pal.bronze : context.pal.muted),
      );
}

class WatchlistView extends ConsumerWidget {
  const WatchlistView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wl = ref.watch(watchlistProvider);
    return RefreshIndicator(
      color: Brand.bronze,
      onRefresh: () async => ref.invalidate(watchlistProvider),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0), children: [
        AsyncBody<List<WatchlistItem>>(wl, onRetry: () => ref.invalidate(watchlistProvider), builder: (items) {
          final watched = items.where((i) => i.watched).toList();
          if (watched.isEmpty) {
            return EmptyState(
              icon: Icons.star_outline_rounded,
              title: 'Your watchlist is empty',
              body: 'Add ASX securities to follow delayed prices and set alerts.',
              action: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Brand.navy), onPressed: () => openIn(context, 'search', back: 'Watchlist'), icon: const Icon(Icons.add_rounded), label: const Text('Add security')),
            );
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const DelayedBadge(),
            const SizedBox(height: 10),
            MCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (final i in watched)
                  Dismissible(
                    key: ValueKey('wl-${i.code}'),
                    direction: DismissDirection.endToStart,
                    background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Brand.loss, child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                    confirmDismiss: (_) async {
                      try {
                        await ref.read(watchlistProvider.notifier).remove(i.code);
                        if (context.mounted) toast(context, '${i.code} removed from watchlist');
                        return true;
                      } catch (e) {
                        if (context.mounted) toast(context, '$e', error: true);
                        return false;
                      }
                    },
                    child: _WatchRow(i),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            Text('Swipe left to remove. Tap a security for its chart.', style: TextStyle(color: context.pal.muted, fontSize: 12)),
          ]);
        }),
        const LegalFooter(),
      ]),
    );
  }
}

class _WatchRow extends ConsumerWidget {
  const _WatchRow(this.i);
  final WatchlistItem i;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = Seed.securities[i.code]!;
    return InkWell(
      onTap: () => openIn(context, 'quote/${s.code}', back: 'Watchlist'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
        child: Row(children: [
          TickerTile(s.code, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.code, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.pal.muted, fontSize: 12.5)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Fmt.aud(s.price), style: numStyle(14.5)),
            const SizedBox(height: 3),
            ChangePill(s.changePct, small: true),
          ]),
          Semantics(
            label: 'Alerts for ${s.code}',
            child: Switch(
              value: i.alerts,
              onChanged: (v) async {
                try {
                  await ref.read(watchlistProvider.notifier).setAlert(i.code, v);
                } catch (e) {
                  if (context.mounted) toast(context, '$e', error: true);
                }
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String q = '';
  final _busy = <String>{};

  @override
  Widget build(BuildContext context) {
    final wl = ref.watch(watchlistProvider).value ?? [];
    final results = Seed.securities.values.where((s) => q.isEmpty || s.code.toLowerCase().contains(q.toLowerCase()) || s.name.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      appBar: const MAppBar(title: 'Add security'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            key: const Key('search-field'),
            autofocus: true,
            onChanged: (v) => setState(() => q = v),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search ASX code or company'),
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? EmptyState(icon: Icons.search_off_rounded, title: 'No matches', body: 'No ASX security matches "$q" in this demo universe.')
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (c, i) {
                    final s = results[i];
                    final added = wl.any((w) => w.code == s.code && w.watched);
                    final busy = _busy.contains(s.code);
                    return ListTile(
                      onTap: () => openIn(context, 'quote/${s.code}', back: 'Search'),
                      leading: TickerTile(s.code, size: 38),
                      title: Text(s.code, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: busy
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : IconButton(
                              tooltip: added ? '${s.code} is on your watchlist' : 'Add ${s.code} to watchlist',
                              onPressed: added
                                  ? null
                                  : () async {
                                      setState(() => _busy.add(s.code));
                                      try {
                                        await ref.read(watchlistProvider.notifier).add(s.code);
                                        if (context.mounted) toast(context, '${s.code} added to watchlist');
                                      } catch (e) {
                                        if (context.mounted) toast(context, '$e', error: true);
                                      } finally {
                                        if (mounted) setState(() => _busy.remove(s.code));
                                      }
                                    },
                              icon: Icon(added ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: added ? context.pal.gain : context.pal.bronze),
                            ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

Future<void> showAlertsSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (c) => DraggableScrollableSheet(expand: false, initialChildSize: .82, maxChildSize: .95, builder: (c, sc) => _AlertsSheet(sc, parent: context)),
    );

class _AlertsSheet extends ConsumerWidget {
  const _AlertsSheet(this.sc, {required this.parent});
  final ScrollController sc;
  final BuildContext parent;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(alertPrefsProvider).value ?? const AlertPreference();
    final wl = ref.watch(watchlistProvider).value ?? [];
    final codes = {...Seed.equities.map((e) => e.code), ...wl.where((w) => w.watched).map((w) => w.code)}.toList()..sort();
    final events = ref.watch(notificationsProvider).where((n) => n.kind == AlertKind.priceMove || n.kind == AlertKind.announcement).take(4).toList();
    final p = context.pal;

    Future<void> save(AlertPreference np) async {
      try {
        await ref.read(alertPrefsProvider.notifier).save(np);
      } catch (e) {
        if (context.mounted) toast(context, '$e', error: true);
      }
    }

    return ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
      const Text('Alerts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('Push alerts for securities you hold or watch.', style: TextStyle(color: p.muted)),
      const SizedBox(height: 14),
      MCard(
        color: p.bg,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Column(children: [
          SwitchListTile(key: const Key('pref-ann'), contentPadding: EdgeInsets.zero, value: prefs.announcements, onChanged: (v) => save(prefs.copyWith(announcements: v)), title: const Text('Company-sensitive announcements', style: TextStyle(fontWeight: FontWeight.w600)), subtitle: const Text('ASX price-sensitive releases')),
          Divider(color: p.border, height: 1),
          SwitchListTile(key: const Key('pref-price'), contentPadding: EdgeInsets.zero, value: prefs.priceMoves, onChanged: (v) => save(prefs.copyWith(priceMoves: v)), title: const Text('Price moves of ±7%', style: TextStyle(fontWeight: FontWeight.w600)), subtitle: const Text('Versus previous official close, on 20 min delayed data')),
        ]),
      ),
      const SectionHeader('Recent alerts'),
      for (final n in events)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MCard(
            color: p.bg,
            padding: const EdgeInsets.all(12),
            onTap: () {
              ref.read(notificationsProvider.notifier).markRead(n.id);
              Navigator.pop(context);
              parent.go(n.route);
            },
            child: Row(children: [
              Icon(n.kind == AlertKind.priceMove ? Icons.trending_down_rounded : Icons.campaign_outlined, color: n.kind == AlertKind.priceMove ? p.loss : p.bronze),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${Sydney.stamp(n.at)} · 20 min delayed', style: TextStyle(color: p.muted, fontSize: 11.5)),
              ])),
              Icon(Icons.chevron_right_rounded, color: p.muted),
            ]),
          ),
        ),
      const SectionHeader('Per-security alerts'),
      MCard(
        color: p.bg,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Column(children: [
          for (final c in codes)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: wl.any((w) => w.code == c && w.alerts),
              onChanged: (v) async {
                try {
                  await ref.read(watchlistProvider.notifier).setAlert(c, v);
                } catch (e) {
                  if (context.mounted) toast(context, '$e', error: true);
                }
              },
              secondary: TickerTile(c, size: 32),
              title: Text(c, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(Seed.securities[c]!.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      Text(
        'How alerts work: MPC\'s servers decide when to alert, using MPC-provided delayed market data and the K.ai event feed. You are alerted only for securities you hold or watch, with that alert type enabled, once per security, alert type, event and trading day. The app itself does not monitor markets. In this demo, alerts are simulated.',
        style: TextStyle(color: p.muted, fontSize: 12, height: 1.45),
      ),
    ]);
  }
}
