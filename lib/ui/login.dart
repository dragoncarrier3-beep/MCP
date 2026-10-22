import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/seed.dart';
import '../state/providers.dart';
import 'widgets.dart';

class MpcLogo extends StatelessWidget {
  const MpcLogo({super.key, this.size = 52});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'MPC Markets',
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * .26),
              gradient: const LinearGradient(colors: [Brand.bronzeLight, Brand.bronzeDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * .52, height: 1)),
          ),
          SizedBox(width: size * .25),
          Text('MPC MARKETS', style: TextStyle(color: Colors.white, fontSize: size * .3, letterSpacing: size * .06, fontWeight: FontWeight.w800)),
        ]),
      );
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    await Future.delayed(const Duration(milliseconds: 700));
    // Production: LiveAuthAdapter → Mosaic auth, tokens in Keychain/Keystore.
    // Credentials are never logged.
    setState(() {
      _busy = false;
      _error = _id.text.trim().isEmpty || _pw.text.isEmpty
          ? 'Enter your email or client ID and password.'
          : 'Live sign-in is connected to Mosaic in production. This preview has no production access. Use Explore Demo.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final notice = ref.watch(sessionProvider).notice;
    final p = context.pal;
    return Scaffold(
      backgroundColor: p.bg,
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(28, MediaQuery.of(context).padding.top + 48, 28, 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Brand.navy, Brand.navy2, Brand.blue], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const MpcLogo(size: 44),
              const SizedBox(height: 40),
              const Text('Mosaic', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
              Text('by MPC Markets', style: TextStyle(color: Brand.bronzeLight.withValues(alpha: .95), fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: .4)),
              const SizedBox(height: 18),
              const Text('Welcome back. Your portfolio, research and adviser, in one secure place.', style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.45)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 12),
            child: AutofillGroup(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (notice != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: p.bronzeTint, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.bronzeBorder)),
                    child: Text(notice, style: TextStyle(color: p.text, fontSize: 13.5)),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: _id,
                  autofillHints: const [AutofillHints.username],
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email or client ID', prefixIcon: Icon(Icons.person_outline_rounded)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pw,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _signIn(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(tooltip: _obscure ? 'Show password' : 'Hide password', onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      builder: (c) => const Padding(
                        padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Forgot password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          SizedBox(height: 10),
                          Text('In production, password reset uses the same secure Mosaic flow as the web platform. A reset link is sent to your registered email address.\n\nNeed help? Contact MPC Markets client services.', style: TextStyle(height: 1.5)),
                        ]),
                      ),
                    ),
                    style: TextButton.styleFrom(foregroundColor: p.bronze),
                    child: const Text('Forgot password?'),
                  ),
                ),
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_error!, style: TextStyle(color: p.loss, fontSize: 13))),
                PrimaryButton('Sign In', busy: _busy, onPressed: _signIn),
                const SizedBox(height: 14),
                Row(children: [Expanded(child: Divider(color: p.border)), Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('or', style: TextStyle(color: p.muted))), Expanded(child: Divider(color: p.border))]),
                const SizedBox(height: 14),
                OutlinedButton(
                  key: const Key('explore-demo'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54), side: BorderSide(color: p.bronze, width: 1.4), foregroundColor: p.bronze, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => ref.read(sessionProvider.notifier).startDemo(),
                  child: const Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Explore Demo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    Text('Fictional test account · no production data', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                  ]),
                ),
                const SizedBox(height: 18),
                Text('Mosaic accounts are opened through your MPC adviser. There is no self-registration in the app.', textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 12.5)),
                const SizedBox(height: 10),
                Wrap(alignment: WrapAlignment.center, children: [
                  for (final (k, l) in [('privacy', 'Privacy Policy'), ('terms', 'Terms'), ('fsg', 'Financial Services Guide')])
                    TextButton(onPressed: () => context.push('/login/legal/$k?back=Sign in'), style: TextButton.styleFrom(foregroundColor: p.muted), child: Text(l, style: const TextStyle(fontSize: 12.5, decoration: TextDecoration.underline))),
                ]),
                Text(afslText, textAlign: TextAlign.center, style: TextStyle(color: p.muted, fontSize: 10.5, height: 1.4)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});
  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _checking = false;

  Future<void> _unlock() async {
    setState(() => _checking = true);
    // Native builds call local_auth (Face ID / Touch ID / Android BiometricPrompt).
    // The web preview cannot verify biometrics, so this is a labelled simulation.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    ref.read(sessionProvider.notifier).unlock();
  }

  @override
  Widget build(BuildContext context) {
    final bio = ref.watch(sessionProvider).biometricEnabled;
    return Material(
      child: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const MpcLogo(size: 36),
          const SizedBox(height: 48),
          Avatar(Seed.client.initials, size: 72, bronze: true),
          const SizedBox(height: 16),
          Text(Seed.client.fullName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Mosaic is locked to protect your information.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 36),
          if (_checking)
            const Column(children: [
              CircularProgressIndicator(color: Brand.bronzeLight),
              SizedBox(height: 14),
              Text('Simulating biometric check…', style: TextStyle(color: Colors.white70)),
            ])
          else ...[
            FilledButton.icon(
              key: const Key('unlock'),
              style: FilledButton.styleFrom(backgroundColor: Brand.bronze, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: _unlock,
              icon: Icon(bio ? Icons.face_retouching_natural_rounded : Icons.lock_open_rounded),
              label: Text(bio ? 'Unlock with biometrics (simulated)' : 'Unlock demo session', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () => ref.read(sessionProvider.notifier).signOut(), child: const Text('Sign out', style: TextStyle(color: Colors.white70))),
          ],
          const SizedBox(height: 28),
          Text(
            kIsWeb
                ? 'Web preview: no real Face ID or fingerprint check takes place. Native iOS and Android builds use the device biometric APIs.'
                : 'Demo build: biometric check is simulated.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
        ]),
      ),
    );
  }
}
