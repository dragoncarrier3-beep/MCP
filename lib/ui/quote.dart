import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../state/providers.dart';
import 'widgets.dart';

class QuoteScreen extends ConsumerStatefulWidget {
  const QuoteScreen({super.key, required this.code});
  final String code;
  @override
  ConsumerState<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends ConsumerState<QuoteScreen> {
  String range = '1D';
  bool _wlBusy = false, _alertBusy = false;

  Future<void> _toggleWatch(bool inList) async {
    setState(() => _wlBusy = true);
    try {
      final n = ref.read(watchlistProvider.notifier);
      inList ? await n.remove(widget.code) : await n.add(widget.code);
      if (mounted) toast(context, inList ? '${widget.code} removed from watchlist' : '${widget.code} added to watchlist');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _wlBusy = false);
    }
  }

  Future<void> _toggleAlert(bool on) async {
    setState(() => _alertBusy = true);
    try {
      await ref.read(watchlistProvider.notifier).setAlert(widget.code, on);
      if (mounted) toast(context, on ? 'Alerts on for ${widget.code}: ±7% moves and price-sensitive announcements' : 'Alerts off for ${widget.code}');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _alertBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(quoteProvider(widget.code));
    final wl = ref.watch(watchlistProvider).value ?? [];
    final item = wl.where((w) => w.code == widget.code).firstOrNull;
    final inList = item?.watched ?? false;
    final alertsOn = item?.alerts ?? false;
    return Scaffold(
      appBar: MAppBar(actions: [
        IconButton(
          tooltip: alertsOn ? 'Turn off alerts for ${widget.code}' : 'Turn on alerts for ${widget.code}',
          onPressed: _alertBusy ? null : () => _toggleAlert(!alertsOn),
          icon: Icon(alertsOn ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, color: alertsOn ? context.pal.bronze : null),
        ),
      ]),
      body: AsyncBody<Quote>(q, onRetry: () => ref.invalidate(quoteProvider(widget.code)), builder: (quote) {
        final s = quote.security;
        final p = context.pal;
        final up = s.change >= 0;
        return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), children: [
          Row(children: [
            TickerTile(s.code, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(s.code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Text(s.exchange, style: TextStyle(color: p.muted, fontWeight: FontWeight.w600)),
                ]),
                Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(s.sector, style: TextStyle(color: p.muted, fontSize: 12.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Semantics(
            label: '${s.code} delayed price ${Fmt.aud(s.price)}, ${up ? 'up' : 'down'} ${Fmt.aud(s.change.abs())}, ${Fmt.pct(s.changePct)} today',
            excludeSemantics: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(Fmt.aud(s.price), style: numStyle(34, weight: FontWeight.w800)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  ChangeText(Fmt.audSigned(s.change), up, size: 15),
                  const SizedBox(width: 6),
                  ChangePill(s.changePct),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          DelayedBadge(asAt: quote.asAt),
          const SizedBox(height: 16),
          MCard(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
            child: Column(children: [
              _Chart(code: s.code, range: range, prevClose: s.prevClose),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Segmented<String>(key: const Key('range'), values: const ['1D', '1M', '3M', '1Y'], labels: const ['1D', '1M', '3M', '1Y'], selected: range, onChanged: (v) => setState(() => range = v)),
              ),
            ]),
          ),
          const SectionHeader('Key statistics'),
          MCard(
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.9,
              children: [
                _stat(context, 'Open', Fmt.price(s.open)),
                _stat(context, 'High', Fmt.price(s.high)),
                _stat(context, 'Low', Fmt.price(s.low)),
                _stat(context, 'Volume', Fmt.compact(s.volume)),
                _stat(context, 'Market cap', 'A\$${s.marketCapB.toStringAsFixed(1)}B'),
                _stat(context, 'Yield', s.yieldPct == 0 ? '—' : '${s.yieldPct.toStringAsFixed(1)}%'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('watch-toggle'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: p.text, side: BorderSide(color: p.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _wlBusy ? null : () => _toggleWatch(inList),
                icon: _wlBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(inList ? Icons.star_rounded : Icons.star_outline_rounded, color: p.bronze),
                label: Text(inList ? 'Remove from Watchlist' : 'Add to Watchlist', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton('Ask Adviser', icon: Icons.chat_bubble_outline_rounded, onPressed: () {
                final draft = Uri.encodeComponent('Hi, could we talk about ${s.code}?');
                context.go('/messages/chat/adviser?draft=$draft&back=Messages');
              }),
            ),
          ]),
          const SizedBox(height: 10),
          MCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: SwitchListTile(
              key: const Key('alert-switch'),
              contentPadding: EdgeInsets.zero,
              value: alertsOn,
              onChanged: _alertBusy ? null : _toggleAlert,
              title: Text('Alerts for ${s.code}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('±7% price moves and price-sensitive announcements', style: TextStyle(color: p.muted, fontSize: 12.5)),
            ),
          ),
          const SectionHeader('Announcements'),
          _Announcements(code: s.code),
          const LegalFooter(extra: ['Prices are 20 minutes delayed and fictional in this demo. No orders can be placed in Mosaic mobile.']),
        ]);
      }),
    );
  }

  Widget _stat(BuildContext c, String k, String v) => Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: TextStyle(color: c.pal.muted, fontSize: 12)),
        const SizedBox(height: 3),
        Text(v, style: numStyle(15)),
      ]);
}

class _Chart extends ConsumerWidget {
  const _Chart({required this.code, required this.range, required this.prevClose});
  final String code, range;
  final double prevClose;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(historyProvider((code, range)));
    final p = context.pal;
    return SizedBox(
      height: 238,
      child: h.when(
        loading: () => const Center(child: Skeleton(height: 180)),
        error: (e, _) => Center(child: Text('Chart unavailable', style: TextStyle(color: p.muted))),
        data: (hist) {
          final up = hist.change >= 0;
          final color = up ? p.gain : p.loss;
          final values = [...hist.points.map((e) => e.v), if (hist.previousClose != null) hist.previousClose!];
          final minY = values.reduce((a, b) => a < b ? a : b);
          final maxY = values.reduce((a, b) => a > b ? a : b);
          final pad = (maxY - minY) * .12 + .01;
          final label = switch (range) { '1D' => 'Today', '1M' => 'Past month', '3M' => 'Past 3 months', _ => 'Past year' };
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 10),
              child: Row(children: [
                Text('$label  ', style: TextStyle(color: p.muted, fontSize: 12.5)),
                ChangeText('${Fmt.audSigned(hist.change)} (${Fmt.pct(hist.changePct)})', up, size: 13),
                const Spacer(),
                if (hist.previousClose != null) Text('Prev close ${Fmt.price(hist.previousClose!)}', style: numStyle(11.5, weight: FontWeight.w500, color: p.muted)),
              ]),
            ),
            Expanded(
              child: Semantics(
                label: '$code price chart, $label. From ${Fmt.aud(hist.first)} to ${Fmt.aud(hist.last)}, ${Fmt.pct(hist.changePct)}. Range low ${Fmt.aud(minY)}, high ${Fmt.aud(maxY)}.',
                child: LineChart(
                  duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 350),
                  LineChartData(
                    minY: minY - pad,
                    maxY: maxY + pad,
                    gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: ((maxY - minY) / 3).clamp(0.01, double.infinity), getDrawingHorizontalLine: (_) => FlLine(color: p.border, strokeWidth: 1)),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, minIncluded: false, maxIncluded: false, reservedSize: 46, interval: ((maxY - minY) / 3).clamp(0.01, double.infinity), getTitlesWidget: (v, m) => Text(v.toStringAsFixed(v > 100 ? 0 : 2), style: numStyle(10, weight: FontWeight.w500, color: p.muted)))),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          interval: (hist.points.length / 4).floorToDouble(),
                          getTitlesWidget: (v, m) {
                            final i = v.toInt();
                            if (i < 0 || i >= hist.points.length) return const SizedBox();
                            final t = hist.points[i].t;
                            return Padding(padding: const EdgeInsets.only(top: 6), child: Text(range == '1D' ? Sydney.hm(t) : Sydney.shortDate(t), style: TextStyle(fontSize: 10, color: p.muted)));
                          },
                        ),
                      ),
                    ),
                    extraLinesData: ExtraLinesData(horizontalLines: [
                      if (hist.previousClose != null) HorizontalLine(y: hist.previousClose!, color: p.muted.withValues(alpha: .7), strokeWidth: 1, dashArray: [4, 4]),
                    ]),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => Brand.navy,
                        getTooltipItems: (spots) => [
                          for (final s in spots)
                            LineTooltipItem('${Fmt.aud(s.y)}\n', numStyle(12.5, color: Colors.white), children: [
                              TextSpan(text: range == '1D' ? Sydney.time(hist.points[s.x.toInt()].t) : Sydney.date(hist.points[s.x.toInt()].t), style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                            ]),
                        ],
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [for (var i = 0; i < hist.points.length; i++) FlSpot(i.toDouble(), hist.points[i].v)],
                        isCurved: true,
                        curveSmoothness: .18,
                        preventCurveOverShooting: true,
                        color: color,
                        barWidth: 2.2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)])),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Announcements extends ConsumerWidget {
  const _Announcements({required this.code});
  final String code;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(announcementsProvider(code));
    return AsyncBody<List<Announcement>>(a, onRetry: () => ref.invalidate(announcementsProvider(code)), skeletons: 2, builder: (list) {
      return MCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (final x in list)
            InkWell(
              onTap: () => openIn(context, 'announcement/${x.id}', back: code),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(Icons.description_outlined, color: context.pal.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (x.priceSensitive) const Padding(padding: EdgeInsets.only(bottom: 4), child: PriceSensitiveTag()),
                      Text(x.title, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3)),
                      const SizedBox(height: 3),
                      Text('${Sydney.stamp(x.at)} · ${x.pages} pages', style: TextStyle(color: context.pal.muted, fontSize: 12)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: context.pal.muted),
                ]),
              ),
            ),
        ]),
      );
    });
  }
}

class PriceSensitiveTag extends StatelessWidget {
  const PriceSensitiveTag({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: context.pal.lossBg, borderRadius: BorderRadius.circular(5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.priority_high_rounded, size: 12, color: context.pal.loss),
          Text('PRICE SENSITIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5, color: context.pal.loss)),
        ]),
      );
}

class AnnouncementScreen extends StatelessWidget {
  const AnnouncementScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final a = Seed.announcements.where((x) => x.id == id).firstOrNull;
    final p = context.pal;
    if (a == null) return const Scaffold(appBar: MAppBar(), body: EmptyState(icon: Icons.description_outlined, title: 'Announcement unavailable', body: 'This document could not be loaded.'));
    return Scaffold(
      appBar: const MAppBar(title: 'ASX announcement'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [TickerTile(a.code, size: 36), const SizedBox(width: 10), Text(a.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), const SizedBox(width: 10), if (a.priceSensitive) const PriceSensitiveTag()]),
        const SizedBox(height: 12),
        Text(a.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.25)),
        const SizedBox(height: 6),
        Text('Released ${Sydney.stamp(a.at)} · ${a.pages} pages · Fictional demo document', style: TextStyle(color: p.muted, fontSize: 12.5)),
        if (a.kaiSummary.isNotEmpty) ...[
          const SizedBox(height: 16),
          MCard(
            color: p.bronzeTint,
            border: p.bronzeBorder,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Avatar('K', size: 28, bronze: true), const SizedBox(width: 8), const Text('K.ai plain-English summary', style: TextStyle(fontWeight: FontWeight.w700)), const Spacer(), const DemoTag('PREVIEW')]),
              const SizedBox(height: 10),
              Text(a.kaiSummary, style: const TextStyle(height: 1.5)),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        MCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.picture_as_pdf_outlined, color: p.loss), const SizedBox(width: 8), const Expanded(child: Text('Document viewer', style: TextStyle(fontWeight: FontWeight.w700))), Text('Page 1 of ${a.pages}', style: TextStyle(color: p.muted, fontSize: 12))]),
            const Divider(height: 24),
            Text(a.body, style: const TextStyle(height: 1.6)),
            const SizedBox(height: 12),
            Text('In production this opens the ASX PDF in a secure in-app viewer.', style: TextStyle(color: p.muted, fontSize: 12, fontStyle: FontStyle.italic)),
          ]),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: p.bronze),
          onPressed: () => openIn(context, 'quote/${a.code}', back: 'Announcement'),
          icon: const Icon(Icons.show_chart_rounded),
          label: Text('View ${a.code} quote'),
        ),
        const LegalFooter(),
      ]),
    );
  }
}
