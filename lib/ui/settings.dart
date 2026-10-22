import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../state/providers.dart';
import 'holdings.dart';
import 'widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pal;
    final session = ref.watch(sessionProvider);
    final mode = ref.watch(themeModeProvider);
    final flags = ref.watch(demoFlagsProvider);
    final audit = ref.watch(repoProvider).auditLog;

    Widget group(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHeader(title),
          MCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[children[i], if (i < children.length - 1) Divider(height: 1, indent: 56, color: p.border)],
          ])),
        ]);
    Widget tile(IconData icon, String title, {String? sub, VoidCallback? onTap, Widget? trailing, Color? color}) => ListTile(
          minVerticalPadding: 12,
          leading: Icon(icon, color: color ?? p.bronze),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          subtitle: sub == null ? null : Text(sub, style: TextStyle(color: p.muted, fontSize: 12.5)),
          trailing: trailing ?? (onTap == null ? null : Icon(Icons.chevron_right_rounded, color: p.muted)),
          onTap: onTap,
        );
    void simulate(AlertKind k) {
      ref.read(notificationsProvider.notifier).simulate(k);
    }

    return Scaffold(
      appBar: const MAppBar(title: 'Profile & settings'),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), children: [
        MCard(
          child: Row(children: [
            Avatar(Seed.client.initials, size: 56),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(Seed.client.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(Seed.client.clientType, style: TextStyle(color: p.muted)),
              const SizedBox(height: 6),
              const DemoTag('FICTIONAL DEMO CLIENT'),
            ])),
          ]),
        ),
        group('Client profile', [
          for (final e in Seed.entities) tile(Icons.account_balance_outlined, e.name, sub: '${e.type.label} · HIN ${e.maskedHin}', onTap: () => openIn(context, 'entity/${e.id}', back: 'Settings')),
          tile(Icons.support_agent_rounded, 'Your Adviser', sub: 'MPC Markets · Private Client Adviser', onTap: () => context.go('/messages/chat/adviser?back=Messages')),
        ]),
        group('Notifications', [
          tile(Icons.notifications_none_rounded, 'Notification preferences', sub: 'Announcements, ±7% moves, per-security alerts', onTap: () => showAlertsSheet(context)),
          tile(Icons.history_rounded, 'Notification history', onTap: () => openIn(context, 'notifications', back: 'Settings')),
        ]),
        group('Security', [
          SwitchListTile(
            secondary: Icon(Icons.face_retouching_natural_rounded, color: p.bronze),
            title: const Text('Biometric unlock', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(kIsWeb ? 'Simulated in the web preview' : 'Face ID, Touch ID or fingerprint', style: TextStyle(color: p.muted, fontSize: 12.5)),
            value: session.biometricEnabled,
            onChanged: (v) => ref.read(sessionProvider.notifier).setBiometric(v),
          ),
          tile(Icons.lock_outline_rounded, 'Lock now', sub: 'Auto-locks after 5 min in background. Signs out after 30 min inactive.', onTap: () => ref.read(sessionProvider.notifier).lock()),
          tile(Icons.shield_outlined, 'Device protections', sub: 'What the native builds add', onTap: () => _protections(context)),
        ]),
        SectionHeader('Appearance'),
        MCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Segmented<ThemeMode>(
              key: const Key('theme-seg'),
              values: const [ThemeMode.light, ThemeMode.system, ThemeMode.dark],
              labels: const ['Light', 'System', 'Dark'],
              selected: mode,
              onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
            ),
          ]),
        ),
        group('Demo tools', [
          tile(Icons.trending_down_rounded, 'Simulate Price Move Alert', onTap: () => simulate(AlertKind.priceMove)),
          tile(Icons.campaign_outlined, 'Simulate ASX Announcement', sub: 'RIO price-sensitive · tap the banner to open the quote', onTap: () => simulate(AlertKind.announcement)),
          tile(Icons.thumb_up_alt_outlined, 'Simulate New Recommendation', onTap: () => simulate(AlertKind.recommendation)),
          tile(Icons.chat_bubble_outline_rounded, 'Simulate Adviser Message', onTap: () => simulate(AlertKind.message)),
          SwitchListTile(
            secondary: Icon(Icons.error_outline_rounded, color: p.bronze),
            title: const Text('Simulate API failure', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Approvals, watchlist and messages fail to acknowledge', style: TextStyle(color: p.muted, fontSize: 12.5)),
            value: flags.failActions,
            onChanged: (v) => ref.read(demoFlagsProvider.notifier).setFail(v),
          ),
          SwitchListTile(
            secondary: Icon(Icons.wifi_off_rounded, color: p.bronze),
            title: const Text('Simulate offline', style: TextStyle(fontWeight: FontWeight.w600)),
            value: flags.offline,
            onChanged: (v) => ref.read(demoFlagsProvider.notifier).setOffline(v),
          ),
          tile(Icons.timer_off_outlined, 'Simulate session expiry', sub: 'Token expires and you are signed out', onTap: () => ref.read(sessionProvider.notifier).expireToken()),
          tile(Icons.fact_check_outlined, 'Simulated audit log', sub: '${audit.length} event${audit.length == 1 ? '' : 's'} this session', onTap: () => _audit(context, audit)),
        ]),
        group('Legal & support', [
          tile(Icons.description_outlined, 'Financial Services Guide', onTap: () => openIn(context, 'legal/fsg', back: 'Settings')),
          tile(Icons.info_outline_rounded, 'General advice disclaimer', onTap: () => openIn(context, 'legal/advice', back: 'Settings')),
          tile(Icons.gavel_rounded, 'Terms', onTap: () => openIn(context, 'legal/terms', back: 'Settings')),
          tile(Icons.privacy_tip_outlined, 'Privacy Policy', onTap: () => openIn(context, 'legal/privacy', back: 'Settings')),
          tile(Icons.call_outlined, 'Contact MPC', onTap: () => _contact(context)),
          tile(Icons.person_off_outlined, 'Request account closure', sub: 'Handled by your adviser', onTap: () async {
            final ok = await confirmSheet(context,
                title: 'Request account closure?',
                message: 'Account closure is handled by your MPC adviser, not in the app. We will send them your request and they will contact you to discuss next steps.',
                confirm: 'Send request',
                footnote: 'DEMO · SIMULATED');
            if (ok && context.mounted) toast(context, 'Request sent to your adviser (simulated).');
          }),
        ]),
        group('About', [
          tile(Icons.phone_iphone_rounded, 'App version', sub: 'Mosaic 0.1.0 (demo build) · Flutter', trailing: const SizedBox()),
        ]),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          key: const Key('logout'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: p.loss, side: BorderSide(color: p.loss.withValues(alpha: .5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () async {
            final ok = await confirmSheet(context, title: 'Log out?', message: 'This ends your session and clears protected data stored on this device, including cached portfolio data, demo approvals and messages.', confirm: 'Log out', destructive: true);
            if (ok) ref.read(sessionProvider.notifier).signOut(notice: 'You have been signed out securely.');
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const LegalFooter(),
      ]),
    );
  }

  void _protections(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Device protections', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (final s in const [
                'Tokens in iOS Keychain / Android Keystore (flutter_secure_storage)',
                'TLS 1.2+ with public-key pinning and a rotation plan',
                'Encrypted offline cache for financial data',
                'Android FLAG_SECURE on sensitive screens',
                'iOS capture detection and app-switcher privacy blur',
                'Root and jailbreak warning',
                'No credentials or sensitive values in logs or analytics',
              ])
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_rounded, size: 18, color: Brand.bronze), const SizedBox(width: 8), Expanded(child: Text(s))])),
              const SizedBox(height: 6),
              Text(
                'These are native-only controls. They cannot be verified in this web preview. The app follows OWASP MASVS practices but is not security-certified.',
                style: TextStyle(color: c.pal.muted, fontSize: 12.5, height: 1.4),
              ),
            ]),
          ),
        ),
      );

  void _contact(BuildContext context) => showModalBottomSheet(
        context: context,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Contact MPC Markets', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              const Text('Client services contact details will be supplied by MPC before release.\n\nFor anything about your portfolio, message your adviser in the Messages tab.', style: TextStyle(height: 1.5)),
              const SizedBox(height: 16),
              PrimaryButton('Message Your Adviser', onPressed: () {
                Navigator.pop(c);
                context.go('/messages/chat/adviser?back=Messages');
              }),
            ]),
          ),
        ),
      );

  void _audit(BuildContext context, List<AuditEvent> audit) => showModalBottomSheet(
        context: context,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Simulated audit log', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('In production, Mosaic records these server-side. The app never holds the system of record.', style: TextStyle(color: c.pal.muted, fontSize: 12.5)),
              const SizedBox(height: 10),
              if (audit.isEmpty) const Text('No actions recorded yet. Accept a recommendation or register interest to see an entry.'),
              for (final a in audit.take(8))
                ListTile(contentPadding: EdgeInsets.zero, dense: true, leading: const Icon(Icons.verified_outlined, color: Brand.bronze), title: Text('${a.action} · ${a.subject}'), subtitle: Text(Sydney.stamp(a.at))),
            ]),
          ),
        ),
      );
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(notificationsProvider);
    final p = context.pal;
    return Scaffold(
      appBar: MAppBar(title: 'Alerts', actions: [IconButton(tooltip: 'Alert settings', onPressed: () => showAlertsSheet(context), icon: const Icon(Icons.tune_rounded))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (list.isEmpty) const EmptyState(icon: Icons.notifications_off_outlined, title: 'No alerts', body: 'Alerts for securities you hold or watch appear here.'),
        for (final n in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MCard(
              padding: const EdgeInsets.all(14),
              onTap: () {
                ref.read(notificationsProvider.notifier).markRead(n.id);
                context.go(n.route);
              },
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(switch (n.kind) { AlertKind.priceMove => Icons.trending_down_rounded, AlertKind.announcement => Icons.campaign_outlined, AlertKind.recommendation => Icons.thumb_up_alt_outlined, AlertKind.message => Icons.chat_bubble_outline_rounded }, color: n.kind == AlertKind.priceMove ? p.loss : p.bronze),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w800))),
                    if (!n.read) Container(width: 8, height: 8, decoration: const BoxDecoration(color: Brand.bronze, shape: BoxShape.circle)),
                  ]),
                  const SizedBox(height: 3),
                  Text(n.body, style: TextStyle(color: p.muted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(Sydney.stamp(n.at), style: TextStyle(color: p.muted, fontSize: 11.5)),
                    if (n.simulated) ...[const SizedBox(width: 8), const DemoTag('SIMULATED')],
                  ]),
                ])),
              ]),
            ),
          ),
        const LegalFooter(),
      ]),
    );
  }
}

class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.doc});
  final String doc;
  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (doc) {
      'fsg' => ('Financial Services Guide', 'The Financial Services Guide explains the services MPC Markets provides, how it is paid, and how to make a complaint.\n\n$afslText\n\nThe final FSG document will be supplied by MPC and displayed here.'),
      'advice' => ('General advice disclaimer', '$generalAdvice\n\n$recWarning\n\n$structuredWarning'),
      'terms' => ('Terms', 'Terms of use for Mosaic mobile will be supplied by MPC and displayed here. Placeholder for demo.'),
      _ => ('Privacy Policy', 'MPC Markets\' Privacy Policy will be supplied by MPC and displayed here. Client data is stored in Australia. Placeholder for demo.'),
    };
    return Scaffold(
      appBar: MAppBar(title: title),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(body, style: const TextStyle(fontSize: 15, height: 1.6)),
        const SizedBox(height: 16),
        const DemoTag('PROVISIONAL WORDING · MPC TO APPROVE'),
      ]),
    );
  }
}
