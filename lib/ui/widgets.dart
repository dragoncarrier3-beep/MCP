import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/seed.dart';

const afslText = 'MPC Markets Pty Ltd (ABN 33 668 234 562) is a Corporate Authorised Representative (CAR No. 000349083) of LeMessurier Securities Pty Ltd, AFSL 296877.';
const generalAdvice = 'This information is general in nature and does not take into account your objectives, financial situation or needs.';
const recWarning = 'Recommendations are general in nature. Speak with your adviser before acting.';
const structuredWarning = 'Structured products carry risk of capital loss; read the PDS.';

/// Push a nested screen inside the current tab, with a meaningful back label.
void openIn(BuildContext context, String sub, {required String back}) {
  HapticFeedback.selectionClick();
  final seg = GoRouterState.of(context).uri.pathSegments.first;
  final sep = sub.contains('?') ? '&' : '?';
  context.push('/$seg/$sub${sep}back=${Uri.encodeComponent(back)}');
}

String backLabel(BuildContext context) => GoRouterState.of(context).uri.queryParameters['back'] ?? 'Back';

class MCard extends StatelessWidget {
  const MCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(18), this.color, this.border, this.semantic});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final Color? border;
  final String? semantic;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final body = Container(
      decoration: BoxDecoration(
        color: color ?? p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border ?? (context.isDark ? p.border : Colors.transparent)),
        boxShadow: context.isDark ? null : [BoxShadow(color: Brand.navy.withValues(alpha: .05), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return semantic == null ? body : Semantics(button: onTap != null, label: semantic, child: body);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 0, 10),
      child: Row(children: [
        Expanded(child: Semantics(header: true, child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: context.pal.bronze, minimumSize: const Size(44, 44)),
            child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }
}

class TabTitle extends StatelessWidget {
  const TabTitle(this.title, {super.key, this.trailing = const []});
  final String title;
  final List<Widget> trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
        child: Row(children: [
          Expanded(child: Semantics(header: true, child: Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)))),
          ...trailing,
        ]),
      );
}

/// Gain/loss shown with colour AND arrow AND explicit sign.
class ChangePill extends StatelessWidget {
  const ChangePill(this.pct, {super.key, this.small = false});
  final double pct;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final up = pct >= 0;
    return Semantics(
      label: '${up ? 'Up' : 'Down'} ${pct.abs().toStringAsFixed(2)} percent',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 2 : 4),
        decoration: BoxDecoration(color: up ? p.gainBg : p.lossBg, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: small ? 16 : 18, color: up ? p.gain : p.loss),
          Text(Fmt.pct(pct), style: numStyle(small ? 11.5 : 12.5, color: up ? p.gain : p.loss)),
        ]),
      ),
    );
  }
}

class ChangeText extends StatelessWidget {
  const ChangeText(this.text, this.positive, {super.key, this.size = 13});
  final String text;
  final bool positive;
  final double size;
  @override
  Widget build(BuildContext context) => Text(text, style: numStyle(size, color: positive ? context.pal.gain : context.pal.loss));
}

class TickerTile extends StatelessWidget {
  const TickerTile(this.code, {super.key, this.size = 42});
  final String code;
  final double size;
  static const _tones = [Brand.navy, Brand.navy2, Brand.blue, Brand.bronzeDeep, Color(0xFF2F5F73), Color(0xFF4B3F72)];
  @override
  Widget build(BuildContext context) {
    final c = _tones[code.codeUnits.fold(0, (a, b) => a + b) % _tones.length];
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(size * .28)),
        child: Text(code.length > 4 ? code.substring(0, 4) : code, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * (code.length > 3 ? .25 : .3), letterSpacing: .3)),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 44, this.bronze = false});
  final String initials;
  final double size;
  final bool bronze;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: bronze ? const [Brand.bronzeLight, Brand.bronzeDeep] : const [Brand.navy2, Brand.navy], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Text(initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * .36)),
      );
}

/// "20 min delayed · as at 4:20 pm AEDT"
class DelayedBadge extends StatelessWidget {
  const DelayedBadge({super.key, this.asAt, this.onDark = false});
  final DateTime? asAt;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final t = asAt ?? Seed.asAt;
    final c = onDark ? Brand.bronzeLight : p.bronze;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: c.withValues(alpha: .6))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.schedule_rounded, size: 12, color: c),
          const SizedBox(width: 3),
          Text('20 min delayed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
        ]),
      ),
      Text('as at ${Sydney.stamp(t)}', style: TextStyle(fontSize: 11, color: onDark ? Colors.white70 : p.muted)),
    ]);
  }
}

class DemoTag extends StatelessWidget {
  const DemoTag(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: context.pal.bronzeTint, borderRadius: BorderRadius.circular(6), border: Border.all(color: context.pal.bronzeBorder)),
        child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .6, color: context.isDark ? Brand.bronzeLight : Brand.bronzeDeep)),
      );
}

class LegalFooter extends StatelessWidget {
  const LegalFooter({super.key, this.extra = const []});
  final List<String> extra;
  @override
  Widget build(BuildContext context) {
    final s = TextStyle(fontSize: 11, height: 1.45, color: context.pal.muted);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in extra) ...[Text(e, style: s.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: 6)],
        Text(generalAdvice, style: s),
        const SizedBox(height: 6),
        Text(afslText, style: s),
        const SizedBox(height: 6),
        Text('Demo build: all client, portfolio and market data is fictional. Quotes are seeded, not live.', style: s.copyWith(fontStyle: FontStyle.italic)),
      ]),
    );
  }
}

/// Bronze back button with a destination label.
class MAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MAppBar({super.key, this.title, this.actions = const [], this.back});
  final String? title;
  final List<Widget> actions;
  final String? back;
  @override
  Size get preferredSize => const Size.fromHeight(52);
  @override
  Widget build(BuildContext context) {
    final label = back ?? backLabel(context);
    return AppBar(
      toolbarHeight: 52,
      leadingWidth: 140,
      automaticallyImplyLeading: false,
      leading: Semantics(
        button: true,
        label: 'Back to $label',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => context.canPop() ? context.pop() : context.go('/home'),
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(children: [
              Icon(Icons.chevron_left_rounded, color: context.pal.bronze, size: 30),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.pal.bronze, fontWeight: FontWeight.w600, fontSize: 15.5))),
            ]),
          ),
        ),
      ),
      title: title == null ? null : Text(title!),
      actions: actions,
    );
  }
}

class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.values, required this.labels, required this.selected, required this.onChanged});
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final idx = values.indexOf(selected);
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 6) / values.length;
      return Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(12)),
        child: Stack(children: [
          AnimatedPositioned(
            duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: idx * w,
            top: 0,
            bottom: 0,
            width: w,
            child: Container(decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(9), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 6)])),
          ),
          Row(children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == idx,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(values[i]);
                    },
                    child: Center(child: Text(labels[i], style: TextStyle(fontSize: 13.5, fontWeight: i == idx ? FontWeight.w700 : FontWeight.w500, color: i == idx ? p.text : p.muted))),
                  ),
                ),
              ),
          ]),
        ]),
      );
    });
  }
}

class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 8});
  final double height;
  final double? width;
  final double radius;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: .45, end: 1.0).animate(c),
        child: Container(height: widget.height, width: widget.width, decoration: BoxDecoration(color: context.pal.chip, borderRadius: BorderRadius.circular(widget.radius))),
      );
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4});
  final int count;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading',
        child: Column(children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MCard(child: Row(children: [const Skeleton(height: 42, width: 42, radius: 12), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Skeleton(width: 120), SizedBox(height: 8), Skeleton(width: 180, height: 12)]))])),
            ),
        ]),
      );
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry(this.message, {super.key, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => MCard(
        child: Column(children: [
          Icon(Icons.cloud_off_rounded, color: context.pal.muted, size: 32),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.pal.muted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title, body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(children: [
          Icon(icon, size: 40, color: context.pal.bronze),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: TextStyle(color: context.pal.muted)),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      );
}

/// Renders an AsyncValue with skeleton, retryable error, and data states.
class AsyncBody<T> extends ConsumerWidget {
  const AsyncBody(this.value, {super.key, required this.builder, required this.onRetry, this.skeletons = 3});
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback onRetry;
  final int skeletons;
  @override
  Widget build(BuildContext context, WidgetRef ref) => value.when(
        data: builder,
        loading: () => value.hasValue ? builder(value.requireValue) : SkeletonList(count: skeletons),
        error: (e, _) => value.hasValue ? builder(value.requireValue) : ErrorRetry('$e', onRetry: onRetry),
      );
}

void toast(BuildContext context, String msg, {bool error = false, SnackBarAction? action}) =>
    toastWith(ScaffoldMessenger.of(context), msg, error: error, action: action);

/// Use when the calling widget may be gone by the time the toast is shown.
void toastWith(ScaffoldMessengerState m, String msg, {bool error = false, SnackBarAction? action}) {
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    backgroundColor: error ? Brand.loss : null,
    content: Row(children: [
      Icon(error ? Icons.error_outline_rounded : Icons.check_circle_rounded, color: error ? Colors.white : Brand.bronzeLight, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(msg)),
    ]),
    action: action,
    duration: Duration(seconds: error ? 5 : 3),
  ));
}

/// Native-feeling confirmation sheet. Returns true on confirm.
Future<bool> confirmSheet(BuildContext context, {required String title, required String message, required String confirm, String? footnote, bool destructive = false}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(fontSize: 15, height: 1.45, color: c.pal.text)),
          if (footnote != null) ...[const SizedBox(height: 12), DemoTag(footnote)],
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: () => Navigator.pop(c, false), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: destructive ? Brand.loss : Brand.navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => Navigator.pop(c, true),
                child: Text(confirm, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
  return r ?? false;
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, required this.onPressed, this.busy = false, this.icon, this.bronze = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy, bronze;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: bronze ? Brand.bronze : (context.isDark ? Brand.blue : Brand.navy), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
            : Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)], Text(label, style: const TextStyle(fontWeight: FontWeight.w700))]),
      );
}

/// Synthetic editorial artwork (no external image dependency).
class HeroArt extends StatelessWidget {
  const HeroArt({super.key, required this.hue, this.height = 160, this.icon, this.radius = 18});
  final int hue;
  final double height;
  final IconData? icon;
  final double radius;
  static const _pairs = [
    [Brand.navy, Brand.blue],
    [Brand.bronzeDeep, Brand.navy],
    [Color(0xFF1B4D5C), Brand.navy],
    [Brand.navy2, Color(0xFF5C4A7A)],
    [Brand.blue, Brand.navy],
    [Color(0xFF3E2F1A), Brand.bronze],
  ];
  @override
  Widget build(BuildContext context) {
    final c = _pairs[hue % _pairs.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: height,
        decoration: BoxDecoration(gradient: LinearGradient(colors: c, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: CustomPaint(painter: _ArtPainter(hue), child: icon == null ? null : Center(child: Icon(icon, color: Colors.white.withValues(alpha: .9), size: 40))),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.seed);
  final int seed;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Brand.bronzeLight.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i < 6; i++) {
      final path = Path()..moveTo(0, s.height * (.35 + i * .1));
      for (var x = 0.0; x <= s.width; x += s.width / 12) {
        final y = s.height * (.35 + i * .1) - (x / s.width) * s.height * .25 + ((x.toInt() * (seed + 3) + i * 17) % 23 - 11).toDouble();
        path.lineTo(x, y);
      }
      canvas.drawPath(path, p..color = Colors.white.withValues(alpha: .06 + i * .03));
    }
    canvas.drawCircle(Offset(s.width * .85, s.height * .2), s.height * .5, Paint()..color = Colors.white.withValues(alpha: .05));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
