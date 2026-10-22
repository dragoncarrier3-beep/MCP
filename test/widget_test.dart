import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic_demo/core/theme.dart';
import 'package:mosaic_demo/main.dart';
import 'package:mosaic_demo/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> pumpApp(WidgetTester tester) async {
  useBrandFonts = false;
  SharedPreferences.setMockInitialValues({'session.bioPrompted': true});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const MosaicApp()));
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(MosaicApp)));
}

Future<void> settle(WidgetTester tester, [int ms = 1200]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tearDownApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await settle(tester, 300);
}

void main() {
  testWidgets('login shows Explore Demo and no registration', (tester) async {
    await pumpApp(tester);
    expect(find.text('Mosaic'), findsOneWidget);
    expect(find.text('Explore Demo'), findsOneWidget);
    expect(find.textContaining('Register'), findsNothing);
    await tearDownApp(tester);
  });

  testWidgets('demo sign-in opens Home with greeting and portfolio', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('explore-demo')));
    await settle(tester);
    expect(find.text('Good afternoon, Alex'), findsOneWidget);
    expect(find.text('Total portfolio value'), findsOneWidget);
    expect(find.textContaining('20 min delayed'), findsWidgets);
    await tearDownApp(tester);
  });

  testWidgets('tab navigation reaches all five tabs', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('explore-demo')));
    await settle(tester);
    await tester.tap(find.text('Markets'));
    await settle(tester);
    expect(find.text('Markets & Research'), findsOneWidget);
    await tester.tap(find.text('Holdings').last);
    await settle(tester);
    expect(find.text('Watchlist'), findsOneWidget);
    await tester.tap(find.text('Recs'));
    await settle(tester);
    expect(find.text('Recommendations'), findsWidgets);
    await tester.tap(find.text('Messages').last);
    await settle(tester);
    expect(find.text('K.ai'), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('entity navigation opens SMSF detail', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('explore-demo')));
    await settle(tester);
    await tester.ensureVisible(find.text('Sample Family Super Fund').first);
    await settle(tester, 300);
    await tester.tap(find.text('Sample Family Super Fund').first);
    await settle(tester);
    expect(find.text('HIN ••••4821'), findsOneWidget);
    expect(find.text('Equities'), findsWidgets);
    await tearDownApp(tester);
  });

  testWidgets('dark mode switches theme', (tester) async {
    final c = await pumpApp(tester);
    c.read(themeModeProvider.notifier).set(ThemeMode.dark);
    await tester.pump();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    await tearDownApp(tester);
  });

  testWidgets('accessibility basics: login meets tap target and label guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
    await tearDownApp(tester);
  });
}
