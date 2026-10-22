import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../state/providers.dart';
import 'recs.dart';
import 'widgets.dart';

String _preview(ChatMessage m) => switch (m.body) {
      TextBody(:final text) => '${m.sender == Sender.client ? 'You: ' : ''}$text',
      RecCardBody(:final note) => 'Shared a recommendation · $note',
    };

String _when(DateTime t) {
  final now = DateTime.now();
  if (now.difference(t).inMinutes < 1) return 'now';
  if (Sydney.date(now) == Sydney.date(t)) return Sydney.hm(t);
  return Sydney.shortDate(t);
}

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final unread = ref.watch(unreadProvider);
    final brokers = Seed.threads.where((t) => t.kind == ThreadKind.broker).toList();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(padding: EdgeInsets.zero, children: [
          const TabTitle('Messages'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              MCard(
                color: p.bronzeTint,
                border: p.bronzeBorder,
                semantic: 'K.ai, your Mosaic assistant. Coming soon. Pinned.',
                onTap: () => openIn(context, 'kai', back: 'Messages'),
                child: Row(children: [
                  const Avatar('K', size: 48, bronze: true),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('K.ai', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(width: 6),
                      Icon(Icons.push_pin_rounded, size: 14, color: p.bronze),
                      const Spacer(),
                      const DemoTag('COMING SOON'),
                    ]),
                    const SizedBox(height: 2),
                    Text('Your Mosaic assistant', style: TextStyle(color: p.text, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text('Assistant', style: TextStyle(color: p.muted, fontSize: 12)),
                  ])),
                ]),
              ),
              const SectionHeader('Your MPC team'),
              MCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (final t in brokers) _ThreadRow(t, unread: unread[t.id] ?? 0),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: p.muted),
                const SizedBox(width: 6),
                Expanded(child: Text('Secure messaging. In this demo, messages stay on this device and replies are simulated.', style: TextStyle(color: p.muted, fontSize: 12))),
              ]),
              const LegalFooter(),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ThreadRow extends ConsumerWidget {
  const _ThreadRow(this.t, {required this.unread});
  final MessageThread t;
  final int unread;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msgs = ref.watch(chatProvider(t.id)).value;
    final last = (msgs != null && msgs.isNotEmpty) ? msgs.last : Seed.messages.lastWhere((m) => m.threadId == t.id);
    final p = context.pal;
    return Semantics(
      button: true,
      label: '${t.displayName}, ${t.role}. ${unread > 0 ? '$unread unread. ' : ''}Last message: ${_preview(last)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => openIn(context, 'chat/${t.id}', back: 'Messages'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Avatar(t.initials, size: 46),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(t.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w700, fontSize: 15))),
                Text(_when(last.at), style: TextStyle(color: unread > 0 ? p.bronze : p.muted, fontSize: 12, fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400)),
              ]),
              Text('${t.org} · ${t.role}', style: TextStyle(color: p.muted, fontSize: 12)),
              const SizedBox(height: 3),
              Row(children: [
                Expanded(child: Text(_preview(last), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unread > 0 ? p.text : p.muted, fontSize: 13.5))),
                if (unread > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: Brand.bronze, borderRadius: BorderRadius.circular(10)),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.id, this.draft});
  final String id;
  final String? draft;
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ctrl = TextEditingController();
  final scroll = ScrollController();
  bool showJump = false;

  @override
  void initState() {
    super.initState();
    final drafts = ref.read(draftsProvider);
    ctrl.text = widget.draft ?? drafts[widget.id] ?? '';
    if (widget.draft != null) Future.microtask(() => ref.read(draftsProvider.notifier).set(widget.id, widget.draft!));
    Future.microtask(() => ref.read(unreadProvider.notifier).clear(widget.id));
    scroll.addListener(() {
      final s = scroll.offset > 300;
      if (s != showJump) setState(() => showJump = s);
    });
  }

  @override
  void dispose() {
    ctrl.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    ref.read(chatProvider(widget.id).notifier).send(text);
    ctrl.clear();
    ref.read(draftsProvider.notifier).set(widget.id, '');
    if (scroll.hasClients) scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final t = Seed.threads.firstWhere((x) => x.id == widget.id);
    final msgs = ref.watch(chatProvider(widget.id));
    final typing = ref.watch(typingProvider(widget.id));
    final p = context.pal;
    return Scaffold(
      appBar: MAppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(children: [
              Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(t.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                Text(t.role, style: TextStyle(color: p.muted, fontSize: 11.5)),
              ]),
              const SizedBox(width: 10),
              Avatar(t.initials, size: 36),
            ]),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: p.bronzeTint,
          child: Text('Demo conversation. Messages stay on this device. No real adviser receives them, and replies are simulated.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: context.isDark ? Brand.bronzeLight : Brand.bronzeDeep, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Stack(children: [
            AsyncBody<List<ChatMessage>>(msgs, onRetry: () => ref.invalidate(chatProvider(widget.id)), builder: (list) {
              final items = <Widget>[];
              String? lastDay;
              for (final m in list) {
                final day = Sydney.date(m.at);
                if (day != lastDay) {
                  items.add(_DateSep(m.at));
                  lastDay = day;
                }
                items.add(_Bubble(m, onRetry: () {
                  final text = (m.body as TextBody).text;
                  ref.read(chatProvider(widget.id).notifier).send(text, retryId: m.id);
                }));
              }
              if (typing) items.add(const _Typing());
              return ListView(
                controller: scroll,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                children: items.reversed.toList(),
              );
            }),
            if (showJump)
              Positioned(
                right: 14,
                bottom: 10,
                child: FloatingActionButton.small(
                  tooltip: 'Scroll to latest',
                  backgroundColor: p.card,
                  foregroundColor: p.text,
                  onPressed: () => scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.border))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('composer'),
                  controller: ctrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  onChanged: (v) => ref.read(draftsProvider.notifier).set(widget.id, v),
                  decoration: InputDecoration(hintText: 'Message ${t.displayName}', fillColor: p.bg, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                key: const Key('send'),
                tooltip: 'Send',
                style: IconButton.styleFrom(backgroundColor: Brand.bronze, minimumSize: const Size(46, 46)),
                onPressed: _send,
                icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _DateSep extends StatelessWidget {
  const _DateSep(this.t);
  final DateTime t;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: context.pal.chip, borderRadius: BorderRadius.circular(10)),
            child: Text(Sydney.dayLabel(t), style: TextStyle(fontSize: 11.5, color: context.pal.muted, fontWeight: FontWeight.w600)),
          ),
        ),
      );
}

/// Typed renderer: picks a widget per MessageBody type.
class _Bubble extends StatelessWidget {
  const _Bubble(this.m, {required this.onRetry});
  final ChatMessage m;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final mine = m.sender == Sender.client;
    final p = context.pal;
    final content = switch (m.body) {
      TextBody(:final text) => Text(text, style: TextStyle(color: mine ? Colors.white : p.text, fontSize: 15, height: 1.35)),
      RecCardBody(:final recId, :final note) => _RecShare(recId: recId, note: note),
    };
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: m.delivery == Delivery.failed ? onRetry : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: mine ? (m.delivery == Delivery.failed ? Brand.navy.withValues(alpha: .55) : (context.isDark ? Brand.blue : Brand.navy)) : p.card,
                  borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 4), bottomRight: Radius.circular(mine ? 4 : 18)),
                  border: mine ? null : Border.all(color: p.border),
                ),
                child: content,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (m.simulated && !mine) Padding(padding: const EdgeInsets.only(right: 6), child: Text('SIMULATED', style: TextStyle(fontSize: 9.5, letterSpacing: .6, fontWeight: FontWeight.w800, color: p.bronze))),
                Text(Sydney.hm(m.at), style: TextStyle(fontSize: 11, color: p.muted)),
                if (mine) ...[const SizedBox(width: 5), _DeliveryMark(m.delivery)],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DeliveryMark extends StatelessWidget {
  const _DeliveryMark(this.d);
  final Delivery d;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final (IconData icon, String label, Color c) = switch (d) {
      Delivery.sending => (Icons.schedule_rounded, 'Sending', p.muted),
      Delivery.sent => (Icons.check_rounded, 'Sent', p.muted),
      Delivery.delivered => (Icons.done_all_rounded, 'Delivered', p.muted),
      Delivery.read => (Icons.done_all_rounded, 'Read', p.bronze),
      Delivery.failed => (Icons.error_outline_rounded, 'Not sent · tap to retry', p.loss),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _RecShare extends ConsumerWidget {
  const _RecShare({required this.recId, required this.note});
  final String recId, note;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = (ref.watch(recsProvider).value ?? Seed.recommendations).firstWhere((x) => x.id == recId);
    final p = context.pal;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(note, style: TextStyle(color: p.text, fontSize: 15, height: 1.35)),
      const SizedBox(height: 10),
      InkWell(
        onTap: () => openIn(context, 'rec/${r.id}', back: 'Chat'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.bronzeTint, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.bronzeBorder)),
          child: Row(children: [
            TickerTile(r.code, size: 36),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Row(children: [ActionBadge(r.action), const SizedBox(width: 6), StatusChip(r.status)]),
            ])),
            Icon(Icons.chevron_right_rounded, color: p.bronze),
          ]),
        ),
      ),
    ]);
  }
}

class _Typing extends StatefulWidget {
  const _Typing();
  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          label: 'Adviser is typing (simulated)',
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: context.pal.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.pal.border)),
            child: AnimatedBuilder(
              animation: c,
              builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: context.pal.muted.withValues(alpha: ((c.value * 3 - i) % 3) < 1 ? 1 : .35)),
                  ),
              ]),
            ),
          ),
        ),
      );
}

class KaiScreen extends StatelessWidget {
  const KaiScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    Widget preview(String q, String a) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(bottom: 6, left: 60),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: (context.isDark ? Brand.blue : Brand.navy).withValues(alpha: .55), borderRadius: BorderRadius.circular(18)),
              child: Text(q, style: const TextStyle(color: Colors.white)),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 16, right: 40),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.bronzeBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a, style: const TextStyle(height: 1.45)),
              const SizedBox(height: 8),
              const DemoTag('PREVIEW · NOT FINANCIAL ADVICE'),
            ]),
          ),
        ]);
    return Scaffold(
      appBar: const MAppBar(title: 'K.ai'),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            MCard(
              color: p.bronzeTint,
              border: p.bronzeBorder,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Avatar('K', size: 40, bronze: true), const SizedBox(width: 10), const Expanded(child: Text('K.ai is coming soon.', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))]),
                const SizedBox(height: 10),
                const Text('K.ai will help you understand announcements, research and your portfolio in plain English. It is not available yet.', style: TextStyle(height: 1.45)),
                const SizedBox(height: 8),
                Text('The examples below are static previews written for this demo. They are not live responses and are not financial advice. K.ai will not provide personal advice; speak with your adviser before acting.', style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.45)),
              ]),
            ),
            const SizedBox(height: 18),
            preview('What did RIO announce today?', 'Rio Tinto released its third quarter operations review. Iron ore shipments were a little lower because of wet weather, and it narrowed its full-year shipments range. Copper production increased.'),
            preview('Why is my SMSF down today?', 'Most of today\'s move comes from BHP, which fell after its quarterly production update. BHP is the largest holding in Sample Family Super Fund.'),
          ]),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.card, border: Border(top: BorderSide(color: p.border))),
            child: Row(children: [
              Expanded(child: TextField(enabled: false, decoration: InputDecoration(hintText: 'K.ai is not available yet', fillColor: p.bg))),
              const SizedBox(width: 8),
              const IconButton.filled(onPressed: null, tooltip: 'Send unavailable', icon: Icon(Icons.arrow_upward_rounded)),
            ]),
          ),
        ),
      ]),
    );
  }
}
