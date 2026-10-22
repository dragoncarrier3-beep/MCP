import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../state/providers.dart';
import 'recs.dart';
import 'widgets.dart';

String greeting(DateTime instant) {
  final h = Sydney.local(instant).hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferBiometrics());
  }

  Future<void> _maybeOfferBiometrics() async {
    final s = ref.read(sessionProvider);
    if (s.biometricPrompted || !mounted) return;
    final on = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.face_retouching_natural_rounded, color: Brand.bronze, size: 36),
        title: const Text('Enable biometric unlock?'),
        content: Text(
          'Use Face ID, Touch ID or fingerprint to unlock Mosaic next time. You can change this in Settings.'
          '${kIsWeb ? '\n\nWeb preview: biometrics are simulated. No real biometric check takes place.' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Brand.navy), onPressed: () => Navigator.pop(c, true), child: const Text('Enable')),
        ],
      ),
    );
    ref.read(sessionProvider.notifier).setBiometric(on ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final pf = ref.watch(portfolioProvider);
    final alerts = ref.watch(unreadAlertsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Brand.bronze,
          onRefresh: () => ref.refresh(portfolioProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Semantics(header: true, child: Text('${greeting(Seed.asAt)}, ${Seed.client.firstName}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6))),
                    const SizedBox(height: 2),
                    Text(Sydney.dayLabel(Seed.asAt), style: TextStyle(color: context.pal.muted, fontSize: 13.5)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Alerts and notifications',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: () => openIn(context, 'notifications', back: 'Home'),
                  icon: Badge(isLabelVisible: alerts > 0, backgroundColor: Brand.bronze, label: Text('$alerts'), child: const Icon(Icons.notifications_none_rounded)),
                ),
                const SizedBox(width: 4),
                Semantics(
                  button: true,
                  label: 'Profile and settings',
                  child: InkWell(customBorder: const CircleBorder(), onTap: () => openIn(context, 'settings', back: 'Home'), child: Avatar(Seed.client.initials)),
                ),
              ]),
              const SizedBox(height: 16),
              AsyncBody<PortfolioSummary>(pf, onRetry: () => ref.invalidate(portfolioProvider), builder: (p) => _HomeBody(p)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody(this.p);
  final PortfolioSummary p;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = [...p.allPositions]..sort((a, b) => b.value.compareTo(a.value));
    final recs = ref.watch(recsProvider).value ?? [];
    final csl = recs.where((r) => r.id == 'rec-csl').firstOrNull;
    final topRec = (csl != null && csl.status == RecStatus.pending) ? csl : recs.where((r) => r.status == RecStatus.pending).firstOrNull;
    final mc = Seed.research.firstWhere((r) => r.type == ContentType.morningCall);
    final feat = Seed.research.firstWhere((r) => r.id == 'th-critical');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PortfolioCard(p),
      const SectionHeader('Allocation'),
      AllocationCard(p),
      const SectionHeader('By entity'),
      for (final e in p.entities)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: MCard(
            semantic: '${e.entity.name}, ${e.entity.type.label}, ${Fmt.aud(e.total)}',
            onTap: () => openIn(context, 'entity/${e.entity.id}', back: 'Home'),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: context.pal.bronzeTint, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.pal.bronzeBorder)),
                child: Icon(switch (e.entity.type) { EntityType.smsf => Icons.savings_outlined, EntityType.company => Icons.business_rounded, EntityType.individual => Icons.person_outline_rounded }, color: context.pal.bronze),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.entity.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(e.entity.type.label, style: TextStyle(color: context.pal.muted, fontSize: 12.5)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Fmt.aud(e.total, cents: false), style: numStyle(15)),
                Text('${(e.total / p.total * 100).toStringAsFixed(1)}% of total', style: TextStyle(color: context.pal.muted, fontSize: 12)),
              ]),
              Icon(Icons.chevron_right_rounded, color: context.pal.muted),
            ]),
          ),
        ),
      const SectionHeader('Total cash'),
      MCard(
        onTap: () => openIn(context, 'entity/smsf?seg=cash', back: 'Home'),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cash across all entities', style: TextStyle(color: context.pal.muted, fontSize: 13)),
              const SizedBox(height: 4),
              Text(Fmt.aud(p.allocation.cash), style: numStyle(22, weight: FontWeight.w700)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final e in p.entities) Text('${e.entity.type.label}  ${Fmt.aud(e.cashValue, cents: false)}', style: numStyle(12, weight: FontWeight.w500, color: context.pal.muted)),
          ]),
        ]),
      ),
      SectionHeader('Top holdings', action: 'See all', onAction: () => context.go('/holdings')),
      MCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          for (final pos in top.take(5)) HoldingRow(pos, back: 'Home'),
        ]),
      ),
      if (topRec != null) ...[
        SectionHeader('Top recommendation', action: 'See all', onAction: () => context.go('/recs')),
        PendingRecCard(topRec, back: 'Home'),
      ],
      SectionHeader('Research', action: 'See all', onAction: () => context.go('/markets')),
      _ResearchTile(mc, label: 'LATEST MORNING CALL'),
      const SizedBox(height: 10),
      _ResearchTile(feat, label: 'FEATURED RESEARCH'),
      SectionHeader('Recent trades', action: 'See all', onAction: () => openIn(context, 'trades', back: 'Home')),
      MCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [for (final t in Seed.trades.take(3)) TradeRow(t)])),
      const LegalFooter(),
    ]);
  }
}

class _ResearchTile extends StatelessWidget {
  const _ResearchTile(this.r, {required this.label});
  final ResearchContent r;
  final String label;
  @override
  Widget build(BuildContext context) => MCard(
        padding: const EdgeInsets.all(12),
        onTap: () => openIn(context, 'content/${r.id}', back: 'Home'),
        child: Row(children: [
          SizedBox(width: 76, child: HeroArt(hue: r.hue, height: 76, radius: 12, icon: r.audioUrl != null ? Icons.headphones_rounded : Icons.article_outlined)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(color: context.pal.bronze, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
              const SizedBox(height: 4),
              Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.25)),
              const SizedBox(height: 4),
              Text('${Sydney.date(r.published)} · ${r.minutes} min ${r.audioUrl != null ? 'listen' : 'read'}', style: TextStyle(color: context.pal.muted, fontSize: 12)),
            ]),
          ),
        ]),
      );
}

class PortfolioCard extends StatelessWidget {
  const PortfolioCard(this.p, {super.key});
  final PortfolioSummary p;
  @override
  Widget build(BuildContext context) {
    final up = p.dayChange >= 0;
    final pnlUp = p.unrealised >= 0;
    Widget metric(String label, String a, String b, bool positive) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(positive ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, color: positive ? const Color(0xFF7FE0A8) : const Color(0xFFFF9A8F), size: 20),
              Flexible(child: Text(a, style: numStyle(14.5, color: Colors.white))),
            ]),
            Padding(padding: const EdgeInsets.only(left: 20), child: Text(b, style: numStyle(12.5, color: positive ? const Color(0xFF7FE0A8) : const Color(0xFFFF9A8F)))),
          ]),
        );
    return Semantics(
      container: true,
      label: 'Total portfolio value ${Fmt.aud(p.total)}. Today ${Fmt.audSigned(p.dayChange)}, ${Fmt.pct(p.dayChangePct)}. Total profit and loss ${Fmt.audSigned(p.unrealised)}.',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2, Brand.blue], begin: Alignment.topLeft, end: Alignment.bottomRight, stops: [0, .55, 1]),
          boxShadow: [BoxShadow(color: Brand.navy.withValues(alpha: .25), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Total portfolio value', style: TextStyle(color: Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w500)),
            const Spacer(),
            Container(width: 24, height: 2, color: Brand.bronzeLight),
          ]),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(Fmt.aud(p.total), style: numStyle(34, weight: FontWeight.w800, color: Colors.white))),
          const SizedBox(height: 6),
          const DelayedBadge(onDark: true),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 14),
          Row(children: [
            metric('Today', Fmt.audSigned(p.dayChange), Fmt.pct(p.dayChangePct), up),
            const SizedBox(width: 12),
            metric('Total P&L', Fmt.audSigned(p.unrealised), Fmt.pct(p.unrealisedPct), pnlUp),
          ]),
        ]),
      ),
    );
  }
}

class AllocationCard extends StatelessWidget {
  const AllocationCard(this.p, {super.key});
  final PortfolioSummary p;
  @override
  Widget build(BuildContext context) {
    final a = p.allocation;
    final eqC = context.isDark ? const Color(0xFF6E9BD6) : Brand.navy;
    final items = [('Equities', a.equities, eqC), ('Structured', a.structured, Brand.bronze), ('Cash', a.cash, Brand.cash)];
    return MCard(
      child: Row(children: [
        Semantics(
          label: 'Allocation donut chart. ${items.map((i) => '${i.$1} ${a.pct(i.$2).toStringAsFixed(1)} percent').join(', ')}',
          child: SizedBox(
            width: 128,
            height: 128,
            child: Stack(alignment: Alignment.center, children: [
              PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 42,
                startDegreeOffset: -90,
                sections: [for (final i in items) PieChartSectionData(value: i.$2, color: i.$3, radius: 20, showTitle: false)],
              )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${p.accountCount}', style: numStyle(20, weight: FontWeight.w800)),
                Text('accounts', style: TextStyle(fontSize: 11, color: context.pal.muted)),
              ]),
            ]),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(children: [
            for (final i in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: i.$3, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    Text(Fmt.aud(i.$2, cents: false), style: numStyle(11.5, weight: FontWeight.w500, color: context.pal.muted)),
                  ])),
                  Text('${a.pct(i.$2).toStringAsFixed(1)}%', style: numStyle(14)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class HoldingRow extends StatelessWidget {
  const HoldingRow(this.pos, {super.key, required this.back, this.trailingAlert});
  final Position pos;
  final String back;
  final Widget? trailingAlert;
  @override
  Widget build(BuildContext context) {
    final s = pos.security;
    return Semantics(
      button: true,
      label: '${s.code}, ${s.name}, value ${Fmt.aud(pos.value)}, today ${Fmt.pct(s.changePct)}',
      excludeSemantics: trailingAlert == null,
      child: InkWell(
        onTap: () => openIn(context, 'quote/${s.code}', back: back),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            TickerTile(s.code),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.code, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.pal.muted, fontSize: 12.5)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(Fmt.aud(pos.value, cents: false), style: numStyle(14.5)),
              const SizedBox(height: 3),
              ChangePill(s.changePct, small: true),
            ]),
            if (trailingAlert != null) trailingAlert!,
          ]),
        ),
      ),
    );
  }
}

class TradeRow extends StatelessWidget {
  const TradeRow(this.t, {super.key});
  final Trade t;
  @override
  Widget build(BuildContext context) {
    final buy = t.side == 'BUY';
    final ent = Seed.entities.firstWhere((e) => e.id == t.entityId);
    return Semantics(
      button: true,
      label: '${t.side} ${t.qty} ${t.code} at ${Fmt.aud(t.price)}, ${ent.name}, ${Sydney.date(t.date)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => openIn(context, 'quote/${t.code}', back: 'Trades'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Container(
              width: 46,
              padding: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: buy ? context.pal.gainBg : context.pal.lossBg, borderRadius: BorderRadius.circular(7)),
              child: Text(t.side, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: buy ? context.pal.gain : context.pal.loss)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${Fmt.units(t.qty)} ${t.code} @ ${Fmt.aud(t.price)}', style: numStyle(14)),
                Text(ent.name, style: TextStyle(color: context.pal.muted, fontSize: 12)),
              ]),
            ),
            Text(Sydney.date(t.date), style: TextStyle(color: context.pal.muted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class TradesScreen extends StatelessWidget {
  const TradesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const MAppBar(title: 'Recent trades'),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          MCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [for (final t in Seed.trades) TradeRow(t)])),
          const SizedBox(height: 10),
          Text('Trade history is read-only. Orders are placed with your adviser, not in the app.', style: TextStyle(color: context.pal.muted, fontSize: 12.5)),
          const LegalFooter(),
        ]),
      );
}

class EntityScreen extends ConsumerStatefulWidget {
  const EntityScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<EntityScreen> createState() => _EntityScreenState();
}

class _EntityScreenState extends ConsumerState<EntityScreen> {
  late String seg = GoRouterState.of(context).uri.queryParameters['seg'] ?? 'eq';

  @override
  Widget build(BuildContext context) {
    final pf = ref.watch(portfolioProvider);
    return Scaffold(
      appBar: const MAppBar(),
      body: AsyncBody<PortfolioSummary>(pf, onRetry: () => ref.invalidate(portfolioProvider), builder: (p) {
        final e = p.byId(widget.id);
        final pal = context.pal;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), children: [
          Text(e.entity.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Row(children: [
            DemoTag(e.entity.type.label.toUpperCase()),
            const SizedBox(width: 8),
            Text('HIN ${e.entity.maskedHin}', style: numStyle(12.5, weight: FontWeight.w500, color: pal.muted)),
          ]),
          const SizedBox(height: 14),
          MCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total value', style: TextStyle(color: pal.muted, fontSize: 13)),
              Text(Fmt.aud(e.total), style: numStyle(28, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              const DelayedBadge(),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _kv(context, 'Today', Fmt.audSigned(e.dayChange), e.dayChange >= 0)),
                Expanded(child: _kv(context, 'Unrealised P&L', Fmt.audSigned(e.unrealised), e.unrealised >= 0)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          Segmented<String>(values: const ['eq', 'st', 'cash'], labels: const ['Equities', 'Structured', 'Cash'], selected: seg, onChanged: (v) => setState(() => seg = v)),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: KeyedSubtree(
              key: ValueKey(seg),
              child: switch (seg) {
                'eq' => Column(children: [for (final pos in e.positions) _EquityCard(pos, back: e.entity.type.label)]),
                'st' => Column(children: [for (final s in e.structured) _StructuredCard(s)]),
                _ => Column(children: [for (final c in e.cash) _CashCard(c)]),
              },
            ),
          ),
          const LegalFooter(),
        ]);
      }),
    );
  }

  Widget _kv(BuildContext c, String k, String v, bool up) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: TextStyle(color: c.pal.muted, fontSize: 12.5)),
        const SizedBox(height: 2),
        ChangeText(v, up, size: 15),
      ]);
}

class _EquityCard extends StatelessWidget {
  const _EquityCard(this.pos, {required this.back});
  final String back;
  final Position pos;
  @override
  Widget build(BuildContext context) {
    final s = pos.security;
    final p = context.pal;
    Widget cell(String k, String v, {Color? c}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: TextStyle(color: p.muted, fontSize: 11.5)),
            const SizedBox(height: 2),
            Text(v, style: numStyle(13.5, color: c)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MCard(
        semantic: '${s.code}, ${Fmt.units(pos.holding.units)} units, market value ${Fmt.aud(pos.value)}, unrealised ${Fmt.audSigned(pos.pnl)}',
        onTap: () => openIn(context, 'quote/${s.code}', back: back),
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            TickerTile(s.code, size: 38),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.code, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(Fmt.aud(pos.value), style: numStyle(14.5)),
              ChangeText('${Fmt.audSigned(pos.pnl)} (${Fmt.pct(pos.pnlPct)})', pos.pnl >= 0, size: 12),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            cell('Units', Fmt.units(pos.holding.units)),
            cell('Avg cost', Fmt.aud(pos.holding.avgCost)),
            cell('Price', Fmt.aud(s.price)),
            cell('Today', Fmt.pct(s.changePct), c: s.change >= 0 ? p.gain : p.loss),
          ]),
        ]),
      ),
    );
  }
}

class _StructuredCard extends StatelessWidget {
  const _StructuredCard(this.s);
  final StructuredHolding s;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: MCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DemoTag(s.type.toUpperCase()),
            const SizedBox(height: 8),
            Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            _row(context, 'Investment amount', Fmt.aud(s.invested)),
            _row(context, 'Current value', Fmt.aud(s.currentValue)),
            _row(context, 'Maturity', Sydney.date(s.maturity)),
            _row(context, 'Profit / loss', '${Fmt.audSigned(s.pnl)} (${Fmt.pct(s.pnl / s.invested * 100)})', color: s.pnl >= 0 ? context.pal.gain : context.pal.loss),
            const SizedBox(height: 8),
            Text('Indicative valuation from issuer. $structuredWarning', style: TextStyle(color: context.pal.muted, fontSize: 11.5)),
          ]),
        ),
      );
}

Widget _row(BuildContext c, String k, String v, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Expanded(child: Text(k, style: TextStyle(color: c.pal.muted, fontSize: 13.5))), Text(v, style: numStyle(14, color: color))]),
    );

class _CashCard extends StatelessWidget {
  const _CashCard(this.c);
  final CashAccount c;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: MCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              if (c.availableToTrade)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: context.pal.gainBg, borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_rounded, size: 13, color: context.pal.gain), const SizedBox(width: 3), Text('Available to trade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.pal.gain))]),
                ),
            ]),
            const SizedBox(height: 10),
            _row(context, 'Balance', Fmt.aud(c.balance)),
            if (c.ratePct != null) _row(context, 'Interest rate', '${c.ratePct!.toStringAsFixed(2)}% p.a.'),
          ]),
        ),
      );
}
