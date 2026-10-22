import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'data/models.dart';
import 'state/providers.dart';
import 'ui/home.dart';
import 'ui/holdings.dart';
import 'ui/login.dart';
import 'ui/markets.dart';
import 'ui/messages.dart';
import 'ui/quote.dart';
import 'ui/recs.dart';
import 'ui/settings.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const MosaicApp()));
}

/// Nested screens available inside every tab, so each tab keeps its own history.
List<RouteBase> _nested() => [
      GoRoute(path: 'entity/:id', builder: (c, s) => EntityScreen(id: s.pathParameters['id']!)),
      GoRoute(path: 'quote/:code', builder: (c, s) => QuoteScreen(code: s.pathParameters['code']!)),
      GoRoute(path: 'announcement/:id', builder: (c, s) => AnnouncementScreen(id: s.pathParameters['id']!)),
      GoRoute(path: 'content/:id', builder: (c, s) => ContentDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: 'movers', builder: (c, s) => const MoversScreen()),
      GoRoute(path: 'trades', builder: (c, s) => const TradesScreen()),
      GoRoute(path: 'rec/:id', builder: (c, s) => RecDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: 'category/:cat', builder: (c, s) => RecListScreen(cat: s.pathParameters['cat']!)),
      GoRoute(path: 'offers', builder: (c, s) => const OffersScreen()),
      GoRoute(path: 'chat/:id', builder: (c, s) => ChatScreen(id: s.pathParameters['id']!, draft: s.uri.queryParameters['draft'])),
      GoRoute(path: 'kai', builder: (c, s) => const KaiScreen()),
      GoRoute(path: 'search', builder: (c, s) => const SearchScreen()),
      GoRoute(path: 'settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(path: 'notifications', builder: (c, s) => const NotificationsScreen()),
      GoRoute(path: 'legal/:doc', builder: (c, s) => LegalDocScreen(doc: s.pathParameters['doc']!)),
    ];

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider.select((s) => s.status), (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(sessionProvider).status;
      final atLogin = state.matchedLocation.startsWith('/login');
      if (status == SessionStatus.signedOut) return atLogin ? null : '/login';
      if (atLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen(), routes: [
        GoRoute(path: 'legal/:doc', builder: (c, s) => LegalDocScreen(doc: s.pathParameters['doc']!)),
      ]),
      StatefulShellRoute.indexedStack(
        builder: (c, s, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (c, s) => const HomeScreen(), routes: _nested())]),
          StatefulShellBranch(routes: [GoRoute(path: '/markets', builder: (c, s) => const MarketsScreen(), routes: _nested())]),
          StatefulShellBranch(routes: [GoRoute(path: '/holdings', builder: (c, s) => const HoldingsScreen(), routes: _nested())]),
          StatefulShellBranch(routes: [GoRoute(path: '/recs', builder: (c, s) => const RecsScreen(), routes: _nested())]),
          StatefulShellBranch(routes: [GoRoute(path: '/messages', builder: (c, s) => const MessagesScreen(), routes: _nested())]),
        ],
      ),
    ],
  );
});

class MosaicApp extends ConsumerStatefulWidget {
  const MosaicApp({super.key});
  @override
  ConsumerState<MosaicApp> createState() => _MosaicAppState();
}

class _MosaicAppState extends ConsumerState<MosaicApp> {
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onHide: () => ref.read(sessionProvider.notifier).onBackground(),
      onShow: () => ref.read(sessionProvider.notifier).onForeground(),
    );
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Mosaic by MPC Markets',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode,
      routerConfig: router,
      builder: (context, child) => Listener(
        onPointerDown: (_) => ref.read(sessionProvider.notifier).touch(),
        child: PhoneFrame(child: _LockOverlay(child: child!)),
      ),
    );
  }
}

/// The lock screen overlays the app so tab state survives a lock/unlock.
class _LockOverlay extends ConsumerWidget {
  const _LockOverlay({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(sessionProvider.select((s) => s.status == SessionStatus.locked));
    return Stack(children: [
      child,
      if (locked) const Positioned.fill(child: LockScreen()),
    ]);
  }
}

/// On wide browser windows, present the app in an iPhone-sized frame.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width < 560 || mq.size.height < 700) return child;
    final h = (mq.size.height - 48).clamp(700.0, 860.0);
    const w = 393.0;
    final wide = mq.size.width > 1100;
    return ColoredBox(
      color: const Color(0xFFE9EDF3),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (wide) const SizedBox(width: 300, child: _DemoAside(left: true)),
        if (wide) const SizedBox(width: 48),
        Container(
          width: w + 20,
          height: h + 20,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Brand.navy, borderRadius: BorderRadius.circular(54), boxShadow: [BoxShadow(color: Brand.navy.withValues(alpha: .35), blurRadius: 40, offset: const Offset(0, 18))]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(44),
            child: MediaQuery(
              data: mq.copyWith(size: Size(w, h), padding: const EdgeInsets.only(top: 12, bottom: 8), viewPadding: const EdgeInsets.only(top: 12, bottom: 8)),
              child: SizedBox(width: w, height: h, child: child),
            ),
          ),
        ),
        if (wide) const SizedBox(width: 48),
        if (wide) const SizedBox(width: 300, child: _DemoAside(left: false)),
      ]),
    );
  }
}

class _DemoAside extends StatelessWidget {
  const _DemoAside({required this.left});
  final bool left;
  @override
  Widget build(BuildContext context) {
    const t = TextStyle(color: Brand.navy, fontSize: 13, height: 1.5, decoration: TextDecoration.none, fontWeight: FontWeight.w400);
    if (left) {
      return const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('MPC MARKETS', style: TextStyle(color: Brand.bronze, fontSize: 12, letterSpacing: 2.4, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
        SizedBox(height: 8),
        Text('Mosaic mobile', style: TextStyle(color: Brand.navy, fontSize: 30, fontWeight: FontWeight.w800, decoration: TextDecoration.none, letterSpacing: -0.8)),
        SizedBox(height: 4),
        Text('Stage 1 interactive demo', style: TextStyle(color: Brand.muted, fontSize: 16, decoration: TextDecoration.none, fontWeight: FontWeight.w500)),
        SizedBox(height: 20),
        Text('Built in Flutter from one codebase for iOS and Android. This is the Flutter web preview of the same app.\n\nAll client, portfolio and market data is fictional. Approvals, adviser replies and alerts are simulated. No order can be placed.', style: t),
      ]);
    }
    const steps = [
      'Tap Explore Demo',
      'Review portfolio and allocation',
      'Open Sample Family Super Fund',
      'Open BHP, switch chart 1D → 1Y',
      'Add to watchlist, enable alerts',
      'Markets: play the Morning Call',
      'Recs: accept the CSL recommendation',
      'Register interest in a structured note',
      'Messages: send your adviser a note',
      'Settings: simulate an ASX alert',
      'Switch to dark mode, lock, log out',
    ];
    return Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('SUGGESTED WALKTHROUGH', style: TextStyle(color: Brand.bronze, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
      const SizedBox(height: 14),
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Brand.navy, borderRadius: BorderRadius.circular(11)),
              child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(steps[i], style: t)),
          ]),
        ),
    ]);
  }
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCountProvider);
    final unread = ref.watch(unreadTotalProvider);
    final offline = ref.watch(demoFlagsProvider).offline;
    final banner = ref.watch(bannerProvider);
    final p = context.pal;

    Widget icon(IconData i, int badge, String label) => Semantics(
          label: badge > 0 ? '$label, $badge new' : label,
          child: Badge(isLabelVisible: badge > 0, backgroundColor: Brand.bronze, label: Text('$badge'), child: Icon(i)),
        );

    return Scaffold(
      body: Stack(children: [
        Column(children: [
          if (offline)
            Container(
              width: double.infinity,
              color: Brand.loss,
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 4, 16, 6),
              child: const Text('Offline – showing last loaded data (simulated)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          Expanded(child: shell),
        ]),
        if (banner != null) _AlertBanner(key: ValueKey(banner.id), n: banner, onOpen: () {
          ref.read(notificationsProvider.notifier).markRead(banner.id);
          ref.read(bannerProvider.notifier).state = null;
          context.go(banner.route);
        }, onDismiss: () => ref.read(bannerProvider.notifier).state = null),
      ]),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: p.card,
          indicatorColor: p.bronzeTint,
          labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(fontSize: 11.5, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500, color: s.contains(WidgetState.selected) ? p.text : p.muted)),
          iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? p.bronze : p.muted)),
        ),
        child: NavigationBar(
          height: 64,
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            shell.goBranch(i, initialLocation: i == shell.currentIndex);
          },
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            const NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Markets'),
            const NavigationDestination(icon: Icon(Icons.pie_chart_outline_rounded), selectedIcon: Icon(Icons.pie_chart_rounded), label: 'Holdings'),
            NavigationDestination(icon: icon(Icons.thumb_up_alt_outlined, pending, 'Recs'), selectedIcon: icon(Icons.thumb_up_alt_rounded, pending, 'Recs'), label: 'Recs'),
            NavigationDestination(icon: icon(Icons.chat_bubble_outline_rounded, unread, 'Messages'), selectedIcon: icon(Icons.chat_bubble_rounded, unread, 'Messages'), label: 'Messages'),
          ],
        ),
      ),
    );
  }
}

class _AlertBanner extends StatefulWidget {
  const _AlertBanner({super.key, required this.n, required this.onOpen, required this.onDismiss});
  final AppNotification n;
  final VoidCallback onOpen, onDismiss;
  @override
  State<_AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<_AlertBanner> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 6,
      left: 10,
      right: 10,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: -40, end: 0),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (c, v, child) => Transform.translate(offset: Offset(0, v), child: child),
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            liveRegion: true,
            button: true,
            label: 'Alert: ${widget.n.title}. Tap to open.',
            child: InkWell(
              onTap: widget.onOpen,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Brand.navy, borderRadius: BorderRadius.circular(18), border: Border.all(color: Brand.bronze.withValues(alpha: .6)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 18, offset: const Offset(0, 6))]),
                child: Row(children: [
                  const Avatar('M', size: 36, bronze: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('MOSAIC · SIMULATED ALERT', style: TextStyle(color: Brand.bronzeLight.withValues(alpha: .95), fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(widget.n.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      Text(widget.n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                    ]),
                  ),
                  IconButton(onPressed: widget.onDismiss, tooltip: 'Dismiss', icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Re-export so widgets.dart helpers are reachable from main for tests.
typedef MosaicCard = MCard;
