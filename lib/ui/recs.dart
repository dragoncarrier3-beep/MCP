import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../state/providers.dart';
import 'widgets.dart';

const _acceptMsg = 'Your adviser will contact you to confirm the account, size and price before any order is placed. No order is placed from this screen.';
const _declineMsg = 'Your adviser will be notified that you\'ve passed on this recommendation. You can still discuss it with them in Messages.';

String _entry(Recommendation r) => '${r.currency}${_n(r.entryLow)}–${_n(r.entryHigh)}';
String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
String _px(Recommendation r, double v) => '${r.currency}${Fmt.price(v)}';

/// Accept/decline flow: confirm → repository → wait for ack → audit → update.
/// Never shows success before acknowledgement. Errors leave status unchanged.
Future<bool> actOnRecommendation(BuildContext context, WidgetRef ref, Recommendation r, RecStatus s) async {
  final accept = s == RecStatus.accepted;
  final ok = await confirmSheet(
    context,
    title: accept ? 'Accept recommendation?' : 'Decline recommendation?',
    message: accept ? _acceptMsg : _declineMsg,
    confirm: accept ? 'Confirm accept' : 'Confirm decline',
    destructive: !accept,
    footnote: 'DEMO · SIMULATED APPROVAL',
  );
  if (!ok || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(recsProvider.notifier);
  try {
    await notifier.act(r.id, s);
    toastWith(messenger, accept ? '${r.code} recommendation accepted. Your adviser will be in touch. (Simulated)' : '${r.code} recommendation declined. Your adviser has been notified. (Simulated)');
    return true;
  } catch (e) {
    toastWith(messenger, '$e', error: true, action: context.mounted ? SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: () => actOnRecommendation(context, ref, r, s)) : null);
    return false;
  }
}

class RecsScreen extends ConsumerWidget {
  const RecsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recs = ref.watch(recsProvider);
    final offers = ref.watch(offersProvider).value ?? Seed.offers;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Brand.bronze,
          onRefresh: () => ref.refresh(recsProvider.future),
          child: ListView(padding: EdgeInsets.zero, children: [
            const TabTitle('Recommendations'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: AsyncBody<List<Recommendation>>(recs, onRetry: () => ref.invalidate(recsProvider), builder: (list) {
                final pending = list.where((r) => r.status == RecStatus.pending).toList();
                final done = list.where((r) => r.status != RecStatus.pending).toList()..sort((a, b) => (b.actionedAt ?? b.issued).compareTo(a.actionedAt ?? a.issued));
                int count(RecCategory c) => c == RecCategory.structured ? offers.length : list.where((r) => r.category == c).length;
                const icons = {RecCategory.auStocks: Icons.flag_outlined, RecCategory.globalStocks: Icons.public_rounded, RecCategory.structured: Icons.layers_outlined, RecCategory.highConviction: Icons.star_outline_rounded};
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.3,
                    children: [
                      for (final c in RecCategory.values)
                        MCard(
                          padding: const EdgeInsets.all(14),
                          semantic: '${c.label}, ${count(c)} items',
                          onTap: () => c == RecCategory.structured ? openIn(context, 'offers', back: 'Recs') : openIn(context, 'category/${c.name}', back: 'Recs'),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [Icon(icons[c], color: context.pal.bronze), const Spacer(), Text('${count(c)}', style: numStyle(20, weight: FontWeight.w800))]),
                            const Spacer(),
                            Text(c.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.2)),
                            Text(c == RecCategory.structured ? 'open offers' : 'recommendations', style: TextStyle(color: context.pal.muted, fontSize: 11.5)),
                          ]),
                        ),
                    ],
                  ),
                  SectionHeader('Pending approvals (${pending.length})'),
                  if (pending.isEmpty)
                    MCard(child: EmptyState(icon: Icons.task_alt_rounded, title: 'All caught up', body: 'You have no recommendations waiting for a response.')),
                  for (final r in pending) Padding(padding: const EdgeInsets.only(bottom: 12), child: PendingRecCard(r, back: 'Recs')),
                  const SectionHeader('Recently actioned'),
                  MCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [for (final r in done) _ActionedRow(r)]),
                  ),
                  const LegalFooter(extra: [recWarning]),
                ]);
              }),
            ),
          ]),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.s, {super.key});
  final RecStatus s;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final (label, fg, bg, icon) = switch (s) {
      RecStatus.pending => ('Pending', p.bronze, p.bronzeTint, Icons.schedule_rounded),
      RecStatus.accepted => ('Accepted', p.gain, p.gainBg, Icons.check_circle_rounded),
      RecStatus.declined => ('Declined', p.muted, p.chip, Icons.do_not_disturb_on_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: fg), const SizedBox(width: 4), Text(label, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700))]),
    );
  }
}

class _ActionedRow extends StatelessWidget {
  const _ActionedRow(this.r);
  final Recommendation r;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => openIn(context, 'rec/${r.id}', back: 'Recs'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            TickerTile(r.code, size: 38),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.name} · ${r.action}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(r.actionedAt == null ? '' : 'Actioned ${Sydney.date(r.actionedAt!)}', style: TextStyle(color: context.pal.muted, fontSize: 12)),
            ])),
            StatusChip(r.status),
          ]),
        ),
      );
}

class ActionBadge extends StatelessWidget {
  const ActionBadge(this.action, {super.key});
  final String action;
  @override
  Widget build(BuildContext context) {
    final sell = action == 'SELL';
    final hold = action == 'HOLD';
    final c = sell ? context.pal.loss : (hold ? context.pal.muted : context.pal.gain);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: sell ? context.pal.lossBg : (hold ? context.pal.chip : context.pal.gainBg), borderRadius: BorderRadius.circular(7)),
      child: Text(action, style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: .6)),
    );
  }
}

class PendingRecCard extends ConsumerStatefulWidget {
  const PendingRecCard(this.r, {super.key, required this.back});
  final Recommendation r;
  final String back;
  @override
  ConsumerState<PendingRecCard> createState() => _PendingRecCardState();
}

class _PendingRecCardState extends ConsumerState<PendingRecCard> {
  bool busy = false;
  Future<void> _go(RecStatus s) async {
    if (busy) return;
    setState(() => busy = true);
    await actOnRecommendation(context, ref, widget.r, s);
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final p = context.pal;
    final ent = Seed.entities.firstWhere((e) => e.id == r.entityId);
    Widget kv(String k, String v) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: TextStyle(color: p.muted, fontSize: 11.5)),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: numStyle(14.5, weight: FontWeight.w700))),
          ]),
        );
    return MCard(
      border: p.bronzeBorder,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          TickerTile(r.code, size: 44),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('${r.category.label} · Issued ${Sydney.date(r.issued)}', style: TextStyle(color: p.muted, fontSize: 12)),
          ])),
          ActionBadge(r.action),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [kv('Entry', _entry(r)), kv('Target', _px(r, r.target)), kv('Stop', _px(r, r.stop))]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.account_balance_wallet_outlined, size: 16, color: p.muted),
          const SizedBox(width: 6),
          Expanded(child: Text('Suggested account: ${ent.name}', style: TextStyle(color: p.muted, fontSize: 12.5))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: p.bronze, minimumSize: const Size.fromHeight(46)),
              onPressed: () => openIn(context, 'rec/${r.id}', back: widget.back),
              child: const FittedBox(child: Text('View Details', maxLines: 1, style: TextStyle(fontWeight: FontWeight.w700))),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: OutlinedButton(
              key: Key('decline-${r.id}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), foregroundColor: p.text, side: BorderSide(color: p.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: busy ? null : () => _go(RecStatus.declined),
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              key: Key('accept-${r.id}'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46), backgroundColor: context.isDark ? Brand.blue : Brand.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: busy ? null : () => _go(RecStatus.accepted),
              child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(recWarning, style: TextStyle(color: p.muted, fontSize: 11)),
      ]),
    );
  }
}

class RecDetailScreen extends ConsumerStatefulWidget {
  const RecDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<RecDetailScreen> createState() => _RecDetailScreenState();
}

class _RecDetailScreenState extends ConsumerState<RecDetailScreen> {
  bool busy = false;
  Future<void> _go(Recommendation r, RecStatus s) async {
    if (busy) return;
    setState(() => busy = true);
    await actOnRecommendation(context, ref, r, s);
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final recs = ref.watch(recsProvider);
    return Scaffold(
      appBar: const MAppBar(title: 'Recommendation'),
      body: AsyncBody<List<Recommendation>>(recs, onRetry: () => ref.invalidate(recsProvider), builder: (list) {
        final r = list.where((x) => x.id == widget.id).firstOrNull;
        if (r == null) return const EmptyState(icon: Icons.search_off_rounded, title: 'Not found', body: 'This recommendation is no longer available.');
        final p = context.pal;
        final sec = Seed.securities[r.code];
        final ent = Seed.entities.firstWhere((e) => e.id == r.entityId);
        Widget cell(String k, String v) => Expanded(
              child: Column(children: [
                Text(k, style: TextStyle(color: p.muted, fontSize: 12)),
                const SizedBox(height: 4),
                FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: numStyle(16, weight: FontWeight.w800))),
              ]),
            );
        return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), children: [
          Row(children: [
            TickerTile(r.code, size: 52),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text('${r.code} · ${sec?.exchange ?? 'NASDAQ'} · ${sec?.sector ?? 'Communication Services'}', style: TextStyle(color: p.muted, fontSize: 12.5)),
            ])),
          ]),
          const SizedBox(height: 12),
          Row(children: [ActionBadge(r.action), const SizedBox(width: 8), StatusChip(r.status), const Spacer(), Text('Issued ${Sydney.date(r.issued)}', style: TextStyle(color: p.muted, fontSize: 12))]),
          if (sec != null) ...[
            const SizedBox(height: 10),
            Row(children: [Text('Last ${Fmt.aud(sec.price)}  ', style: numStyle(14)), ChangePill(sec.changePct, small: true), const SizedBox(width: 8), const Expanded(child: DelayedBadge())]),
          ],
          if (r.status != RecStatus.pending) ...[
            const SizedBox(height: 14),
            MCard(
              color: r.status == RecStatus.accepted ? p.gainBg : p.chip,
              child: Text(
                r.status == RecStatus.accepted
                    ? 'You accepted this on ${Sydney.stamp(r.actionedAt!)}. Your adviser will contact you to confirm account, size and price. No order has been placed. (Simulated acknowledgement)'
                    : 'You declined this on ${Sydney.stamp(r.actionedAt!)}. Your adviser has been notified. (Simulated acknowledgement)',
                style: TextStyle(color: r.status == RecStatus.accepted ? p.gain : p.text, fontWeight: FontWeight.w600, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 14),
          MCard(child: Row(children: [cell('Entry', _entry(r)), cell('Target', _px(r, r.target)), cell('Stop', _px(r, r.stop))])),
          const SectionHeader('Commentary'),
          Text(r.commentary, style: const TextStyle(fontSize: 15, height: 1.6)),
          const SectionHeader('Why we like it'),
          for (final w in r.whyWeLikeIt)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.check_circle_rounded, size: 18, color: p.bronze)),
                const SizedBox(width: 10),
                Expanded(child: Text(w, style: const TextStyle(fontSize: 14.5, height: 1.4))),
              ]),
            ),
          const SectionHeader('Suggested account'),
          MCard(
            onTap: () => openIn(context, 'entity/${ent.id}', back: r.code),
            child: Row(children: [
              Icon(Icons.account_balance_wallet_outlined, color: p.bronze),
              const SizedBox(width: 10),
              Expanded(child: Text('${ent.name} (${ent.type.label})', style: const TextStyle(fontWeight: FontWeight.w600))),
              Icon(Icons.chevron_right_rounded, color: p.muted),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            if (sec != null)
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: p.text, side: BorderSide(color: p.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => openIn(context, 'quote/${r.code}', back: 'Recommendation'),
                  icon: const Icon(Icons.show_chart_rounded),
                  label: const Text('View quote'),
                ),
              ),
            if (sec != null) const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: p.text, side: BorderSide(color: p.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => context.go('/messages/chat/adviser?draft=${Uri.encodeComponent('Hi, could we talk about the ${r.code} recommendation?')}&back=Messages'),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Ask adviser'),
              ),
            ),
          ]),
          if (r.status == RecStatus.pending) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: p.text, side: BorderSide(color: p.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: busy ? null : () => _go(r, RecStatus.declined), child: const Text('Decline'))),
              const SizedBox(width: 10),
              Expanded(child: PrimaryButton('Accept', key: const Key('detail-accept'), busy: busy, onPressed: () => _go(r, RecStatus.accepted))),
            ]),
            const SizedBox(height: 6),
            Text('Accepting is not placing a trade. No order is placed from this app.', textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12)),
          ],
          const LegalFooter(extra: [recWarning]),
        ]);
      }),
    );
  }
}

class RecListScreen extends ConsumerWidget {
  const RecListScreen({super.key, required this.cat});
  final String cat;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = RecCategory.values.byName(cat);
    final recs = ref.watch(recsProvider);
    return Scaffold(
      appBar: MAppBar(title: c.label),
      body: AsyncBody<List<Recommendation>>(recs, onRetry: () => ref.invalidate(recsProvider), builder: (list) {
        final l = list.where((r) => r.category == c).toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (l.isEmpty) const EmptyState(icon: Icons.inbox_outlined, title: 'No recommendations', body: 'There are no recommendations in this list right now.'),
          for (final r in l)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: r.status == RecStatus.pending ? PendingRecCard(r, back: c.label) : MCard(padding: EdgeInsets.zero, child: _ActionedRow(r)),
            ),
          const LegalFooter(extra: [recWarning]),
        ]);
      }),
    );
  }
}

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(offersProvider);
    return Scaffold(
      appBar: const MAppBar(title: 'Structured Investments'),
      body: AsyncBody<List<StructuredOffer>>(offers, onRetry: () => ref.invalidate(offersProvider), builder: (list) {
        final open = list.where((o) => o.closes.isAfter(Seed.asAt)).toList();
        return ListView(padding: const EdgeInsets.all(16), children: [
          MCard(
            color: context.pal.lossBg,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, color: context.pal.loss),
              const SizedBox(width: 10),
              const Expanded(child: Text(structuredWarning, style: TextStyle(fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 12),
          for (final o in open) Padding(padding: const EdgeInsets.only(bottom: 12), child: _OfferCard(o)),
          const LegalFooter(extra: [structuredWarning, 'Offers shown are fictional examples for the demo timeline.']),
        ]);
      }),
    );
  }
}

class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard(this.o);
  final StructuredOffer o;
  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  bool busy = false;

  Future<void> _register() async {
    final o = widget.o;
    final ok = await confirmSheet(
      context,
      title: 'Register interest?',
      message: 'You are registering interest in "${o.title}". Your adviser will send you the term sheet and PDS and confirm suitability. This is not an application or an investment.',
      confirm: 'Register interest',
      footnote: 'DEMO · SIMULATED',
    );
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await ref.read(offersProvider.notifier).register(o.id);
      if (mounted) toast(context, 'Interest registered – your adviser will send the term sheet.');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true, action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _register));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final p = context.pal;
    final registered = o.status == OfferStatus.interestRegistered;
    return MCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          DemoTag(o.type.toUpperCase()),
          const Spacer(),
          if (registered)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: p.gainBg, borderRadius: BorderRadius.circular(7)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle_rounded, size: 13, color: p.gain), const SizedBox(width: 4), Text('Interest registered', style: TextStyle(color: p.gain, fontSize: 11.5, fontWeight: FontWeight.w700))]),
            )
          else
            Text('Open', style: TextStyle(color: p.gain, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
        const SizedBox(height: 10),
        Text(o.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(o.description, style: TextStyle(color: p.muted, height: 1.4)),
        const SizedBox(height: 12),
        for (final f in o.features)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [Icon(Icons.circle, size: 6, color: p.bronze), const SizedBox(width: 8), Expanded(child: Text(f, style: const TextStyle(fontSize: 13.5)))]),
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            for (final (k, v) in [('Tenor', o.tenor), ('Minimum', Fmt.aud(o.minInvestment, cents: false)), ('Closes', Sydney.date(o.closes))])
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(k, style: TextStyle(color: p.muted, fontSize: 11.5)), const SizedBox(height: 2), Text(v, style: numStyle(13.5, weight: FontWeight.w700))])),
          ]),
        ),
        const SizedBox(height: 12),
        registered
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: p.text, side: BorderSide(color: p.border)),
                onPressed: () => context.go('/messages/chat/desk?back=Messages'),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Message the Structured Products Desk'),
              )
            : PrimaryButton('Register Interest', key: Key('register-${o.id}'), bronze: true, busy: busy, onPressed: _register),
        const SizedBox(height: 8),
        Text(structuredWarning, style: TextStyle(color: p.muted, fontSize: 11)),
      ]),
    );
  }
}
