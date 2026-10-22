import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/seed.dart';
import '../state/providers.dart';
import 'widgets.dart';

class MarketsScreen extends ConsumerStatefulWidget {
  const MarketsScreen({super.key});
  @override
  ConsumerState<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends ConsumerState<MarketsScreen> {
  static const filters = <(String, ContentType?)>[
    ('Everything', null),
    ('Articles', ContentType.article),
    ('Thematics', ContentType.thematic),
    ('Company Insights', ContentType.companyInsight),
    ('Webinars', ContentType.webinar),
    ('Videos', ContentType.video),
  ];
  int filter = 0;
  final items = <ResearchContent>[];
  int page = 0;
  bool loading = false, hasMore = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
      if (reset) {
        items.clear();
        page = 0;
        hasMore = true;
      }
    });
    try {
      final r = await ref.read(repoProvider).research(type: filters[filter].$2, page: page);
      setState(() {
        items.addAll(r);
        page++;
        hasMore = r.length == 6;
      });
    } catch (e) {
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final mc = Seed.research.firstWhere((r) => r.type == ContentType.morningCall);
    final bvb = Seed.research.firstWhere((r) => r.type == ContentType.bullsBears);
    final feat = Seed.research.firstWhere((r) => r.id == 'th-critical');
    final movers = Seed.securities.values.toList()..sort((a, b) => b.changePct.compareTo(a.changePct));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Brand.bronze,
          onRefresh: () => _load(reset: true),
          child: ListView(padding: EdgeInsets.zero, children: [
            const TabTitle('Markets & Research'),
            SizedBox(
              height: 108,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), children: [
                for (final i in Seed.indices)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: MCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      semantic: '${i.name} ${i.value.toStringAsFixed(2)}, ${Fmt.pct(i.changePct)}, 20 minutes delayed',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(i.name, style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('${i.unit.isEmpty ? '' : '${i.unit.split('/').first} '}${Fmt.price(i.value)}', style: numStyle(15.5, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        ChangePill(i.changePct, small: true),
                      ]),
                    ),
                  ),
              ]),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: DelayedBadge()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(children: [
                Expanded(child: _PinnedCard(r: mc, kicker: 'MORNING CALL', cadence: 'DAILY', sub: 'Daily podcast & report', dark: true)),
                const SizedBox(width: 10),
                Expanded(child: _PinnedCard(r: bvb, kicker: 'BULLS VS. BEARS', cadence: 'WEEKLY', sub: 'Weekly podcast & report', dark: false)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionHeader('Featured research'),
                MCard(
                  padding: EdgeInsets.zero,
                  onTap: () => openIn(context, 'content/${feat.id}', back: 'Markets'),
                  semantic: 'Featured: ${feat.title}',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    HeroArt(hue: feat.hue, height: 150, icon: Icons.diamond_outlined),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(feat.type.label.toUpperCase(), style: TextStyle(color: p.bronze, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8)),
                        const SizedBox(height: 6),
                        Text(feat.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.25)),
                        const SizedBox(height: 6),
                        Text('${Sydney.date(feat.published)} · ${feat.minutes} min read', style: TextStyle(color: p.muted, fontSize: 12.5)),
                      ]),
                    ),
                  ]),
                ),
                SectionHeader('Market movers', action: 'See all', onAction: () => openIn(context, 'movers', back: 'Markets')),
                MCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: _moverCol(context, 'Top gainers', movers.take(3).toList())),
                      const SizedBox(width: 14),
                      Expanded(child: _moverCol(context, 'Top losers', movers.reversed.take(3).toList())),
                    ]),
                    const SizedBox(height: 10),
                    const DelayedBadge(),
                  ]),
                ),
                const SectionHeader('Research & content'),
              ]),
            ),
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                for (var i = 0; i < filters.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filters[i].$1),
                      selected: filter == i,
                      showCheckmark: false,
                      selectedColor: context.isDark ? Brand.bronze : Brand.navy,
                      labelStyle: TextStyle(color: filter == i ? Colors.white : p.text, fontWeight: FontWeight.w600, fontSize: 13),
                      backgroundColor: p.card,
                      side: BorderSide(color: filter == i ? Colors.transparent : p.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onSelected: (_) {
                        setState(() => filter = i);
                        _load(reset: true);
                      },
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(children: [
                for (final r in items) Padding(padding: const EdgeInsets.only(bottom: 10), child: ContentRow(r, back: 'Markets')),
                if (loading && items.isEmpty) const SkeletonList(count: 3),
                if (error != null) ErrorRetry(error!, onRetry: () => _load()),
                if (!loading && error == null && items.isEmpty) const EmptyState(icon: Icons.inbox_outlined, title: 'Nothing here yet', body: 'No content in this category right now.'),
                if (hasMore && items.isNotEmpty)
                  TextButton(onPressed: loading ? null : () => _load(), child: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Load more', style: TextStyle(color: p.bronze, fontWeight: FontWeight.w700))),
                const LegalFooter(),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _moverCol(BuildContext context, String title, List<Security> list) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: context.pal.muted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        for (final s in list)
          InkWell(
            onTap: () => openIn(context, 'quote/${s.code}', back: 'Markets'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.code, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(Fmt.price(s.price), style: numStyle(11.5, weight: FontWeight.w500, color: context.pal.muted)),
                ])),
                ChangePill(s.changePct, small: true),
              ]),
            ),
          ),
      ]);
}

class _PinnedCard extends StatelessWidget {
  const _PinnedCard({required this.r, required this.kicker, required this.cadence, required this.sub, required this.dark});
  final ResearchContent r;
  final String kicker, cadence, sub;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : context.pal.text;
    return Semantics(
      button: true,
      label: '$kicker, $cadence, $sub',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openIn(context, 'content/${r.id}', back: 'Markets'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: dark ? const LinearGradient(colors: [Brand.navy, Brand.blue], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
            color: dark ? null : context.pal.bronzeTint,
            border: Border.all(color: dark ? Colors.transparent : context.pal.bronzeBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: dark ? Brand.bronze : Brand.navy, borderRadius: BorderRadius.circular(5)),
                child: Text(cadence, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
              ),
              const Spacer(),
              Icon(Icons.headphones_rounded, color: dark ? Brand.bronzeLight : Brand.bronze, size: 20),
            ]),
            const SizedBox(height: 34),
            Text(kicker, style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: .3)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(color: dark ? Colors.white70 : context.pal.muted, fontSize: 12)),
            const SizedBox(height: 6),
            Text(Sydney.date(r.published), style: TextStyle(color: dark ? Brand.bronzeLight : Brand.bronzeDeep, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class ContentRow extends StatelessWidget {
  const ContentRow(this.r, {super.key, required this.back});
  final ResearchContent r;
  final String back;
  @override
  Widget build(BuildContext context) {
    final icon = r.audioUrl != null ? Icons.headphones_rounded : (r.videoUrl != null ? Icons.play_circle_outline_rounded : Icons.article_outlined);
    return MCard(
      padding: const EdgeInsets.all(12),
      onTap: () => openIn(context, 'content/${r.id}', back: back),
      semantic: '${r.type.label}: ${r.title}',
      child: Row(children: [
        SizedBox(width: 70, child: HeroArt(hue: r.hue, height: 70, radius: 12, icon: icon)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.type.label.toUpperCase(), style: TextStyle(color: context.pal.bronze, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .7)),
            const SizedBox(height: 3),
            Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.25)),
            const SizedBox(height: 3),
            Text('${Sydney.date(r.published)} · ${r.minutes} min', style: TextStyle(color: context.pal.muted, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

class MoversScreen extends StatefulWidget {
  const MoversScreen({super.key});
  @override
  State<MoversScreen> createState() => _MoversScreenState();
}

class _MoversScreenState extends State<MoversScreen> {
  String seg = 'g';
  @override
  Widget build(BuildContext context) {
    final all = Seed.securities.values.toList()..sort((a, b) => b.changePct.compareTo(a.changePct));
    final list = seg == 'g' ? all.where((s) => s.change > 0).toList() : all.reversed.where((s) => s.change < 0).toList();
    return Scaffold(
      appBar: const MAppBar(title: 'Market movers'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Segmented<String>(values: const ['g', 'l'], labels: const ['Top gainers', 'Top losers'], selected: seg, onChanged: (v) => setState(() => seg = v)),
        const SizedBox(height: 10),
        const DelayedBadge(),
        const SizedBox(height: 10),
        MCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (final s in list)
              ListTile(
                onTap: () => openIn(context, 'quote/${s.code}', back: 'Movers'),
                leading: TickerTile(s.code, size: 38),
                title: Text(s.code, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(Fmt.aud(s.price), style: numStyle(14)), const SizedBox(height: 2), ChangePill(s.changePct, small: true)]),
              ),
          ]),
        ),
        const LegalFooter(extra: ['Movers shown from the fictional demo universe of ASX securities.']),
      ]),
    );
  }
}

class ContentDetailScreen extends StatelessWidget {
  const ContentDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final r = Seed.research.where((x) => x.id == id).firstOrNull;
    if (r == null) return const Scaffold(appBar: MAppBar(), body: EmptyState(icon: Icons.article_outlined, title: 'Content unavailable', body: 'This item could not be loaded.'));
    final p = context.pal;
    return Scaffold(
      appBar: const MAppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), children: [
        HeroArt(hue: r.hue, height: 180, icon: r.audioUrl != null ? Icons.headphones_rounded : (r.videoUrl != null ? Icons.play_circle_outline_rounded : Icons.auto_stories_outlined)),
        const SizedBox(height: 16),
        Text(r.type.label.toUpperCase(), style: TextStyle(color: p.bronze, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .8)),
        const SizedBox(height: 6),
        Semantics(header: true, child: Text(r.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.4))),
        const SizedBox(height: 8),
        Text('${r.author} · ${Sydney.date(r.published)} · ${r.minutes} min', style: TextStyle(color: p.muted, fontSize: 13)),
        if (r.audioUrl != null) ...[const SizedBox(height: 16), PodcastPlayer(content: r)],
        if (r.videoUrl != null) ...[const SizedBox(height: 16), DemoVideo(url: r.videoUrl!)],
        const SizedBox(height: 18),
        for (final para in r.body) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(para, style: const TextStyle(fontSize: 15.5, height: 1.6))),
        if (r.related.isNotEmpty) ...[
          const SectionHeader('Related securities'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in r.related.where(Seed.securities.containsKey))
              ActionChip(
                avatar: TickerTile(c, size: 22),
                label: Text('$c  ${Fmt.pct(Seed.securities[c]!.changePct)}', style: numStyle(12.5)),
                backgroundColor: p.card,
                side: BorderSide(color: p.border),
                onPressed: () => openIn(context, 'quote/$c', back: r.type.label),
              ),
          ]),
        ],
        const LegalFooter(),
      ]),
    );
  }
}

/// Working podcast player. Plays a clearly labelled demonstration recording.
/// Native builds add audio_service for lock-screen controls and background playback.
class PodcastPlayer extends ConsumerStatefulWidget {
  const PodcastPlayer({super.key, required this.content});
  final ResearchContent content;
  @override
  ConsumerState<PodcastPlayer> createState() => _PodcastPlayerState();
}

class _PodcastPlayerState extends ConsumerState<PodcastPlayer> {
  final player = AudioPlayer();
  static const speeds = [1.0, 1.25, 1.5, 2.0, 0.75];
  int speedIdx = 0;
  bool loading = false, failed = false, ready = false;
  StreamSubscription? _posSub;
  late final String _key = 'media.pos.${widget.content.id}';
  late final SharedPreferences _prefs = ref.read(prefsProvider);

  @override
  void initState() {
    super.initState();
    _prefs; // Resolve while ref is valid; dispose() must not touch ref.
  }

  Future<void> _init() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      await player.setUrl(widget.content.audioUrl!);
      final saved = _prefs.getInt(_key);
      if (saved != null && saved > 0) await player.seek(Duration(milliseconds: saved));
      _posSub = player.positionStream.listen((p) {
        if (p.inSeconds % 5 == 0) _prefs.setInt(_key, p.inMilliseconds);
      });
      setState(() => ready = true);
    } catch (_) {
      setState(() => failed = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    final pos = player.position.inMilliseconds;
    if (pos > 0) _prefs.setInt(_key, pos);
    _posSub?.cancel();
    player.dispose();
    super.dispose();
  }

  String _t(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(colors: [Brand.navy, Brand.navy2], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.podcasts_rounded, color: Brand.bronzeLight),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.content.type.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: Brand.bronze.withValues(alpha: .25), borderRadius: BorderRadius.circular(6)),
            child: const Text('DEMO RECORDING', style: TextStyle(color: Brand.bronzeLight, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .7)),
          ),
        ]),
        const SizedBox(height: 6),
        const Text('Sample music track (SoundHelix) stands in for MPC\'s Morning Call audio, which is not connected in this preview.', style: TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.35)),
        const SizedBox(height: 12),
        if (failed)
          Row(children: [
            const Expanded(child: Text('Audio unavailable. Check your connection.', style: TextStyle(color: Color(0xFFFF9A8F)))),
            TextButton(onPressed: _init, child: const Text('Retry', style: TextStyle(color: Brand.bronzeLight))),
          ])
        else if (!ready)
          Center(
            child: FilledButton.icon(
              key: const Key('podcast-play'),
              style: FilledButton.styleFrom(backgroundColor: Brand.bronze, minimumSize: const Size(180, 48)),
              onPressed: loading
                  ? null
                  : () async {
                      await _init();
                      if (ready) player.play();
                    },
              icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_arrow_rounded),
              label: Text(loading ? 'Loading…' : 'Play episode'),
            ),
          )
        else
          StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (c, snap) {
              final pos = snap.data ?? Duration.zero;
              final dur = player.duration ?? Duration.zero;
              final max = dur.inMilliseconds.toDouble().clamp(1.0, double.infinity);
              return Column(children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7), activeTrackColor: Brand.bronzeLight, inactiveTrackColor: Colors.white24, thumbColor: Colors.white, overlayColor: Colors.white12),
                  child: Slider(
                    semanticFormatterCallback: (v) => '${_t(Duration(milliseconds: v.toInt()))} of ${_t(dur)}',
                    value: pos.inMilliseconds.toDouble().clamp(0, max),
                    max: max,
                    onChanged: (v) => player.seek(Duration(milliseconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    Text(_t(pos), style: numStyle(12, color: Colors.white70)),
                    const Spacer(),
                    Text(_t(dur), style: numStyle(12, color: Colors.white70)),
                  ]),
                ),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  TextButton(
                    onPressed: () {
                      setState(() => speedIdx = (speedIdx + 1) % speeds.length);
                      player.setSpeed(speeds[speedIdx]);
                    },
                    child: Text('${speeds[speedIdx]}×', semanticsLabel: 'Playback speed ${speeds[speedIdx]} times', style: numStyle(14, color: Colors.white)),
                  ),
                  IconButton(tooltip: 'Back 15 seconds', onPressed: () => player.seek(pos - const Duration(seconds: 15) < Duration.zero ? Duration.zero : pos - const Duration(seconds: 15)), icon: const _Skip15(forward: false)),
                  StreamBuilder<bool>(
                    stream: player.playingStream,
                    builder: (c, s) {
                      final playing = s.data ?? false;
                      return IconButton.filled(
                        tooltip: playing ? 'Pause' : 'Play',
                        style: IconButton.styleFrom(backgroundColor: Brand.bronze, minimumSize: const Size(60, 60)),
                        onPressed: () => playing ? player.pause() : player.play(),
                        icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 32),
                      );
                    },
                  ),
                  IconButton(tooltip: 'Forward 15 seconds', onPressed: () => player.seek(pos + const Duration(seconds: 15)), icon: const _Skip15(forward: true)),
                  const SizedBox(width: 48),
                ]),
                Text(kIsWeb ? 'Position is saved so you can resume. Background playback and lock-screen controls run on native builds.' : 'Position is saved so you can resume.',
                    textAlign: TextAlign.center, style: TextStyle(color: p.muted.withValues(alpha: .9), fontSize: 11)),
              ]);
            },
          ),
      ]),
    );
  }
}

class DemoVideo extends StatefulWidget {
  const DemoVideo({super.key, required this.url});
  final String url;
  @override
  State<DemoVideo> createState() => _DemoVideoState();
}

class _DemoVideoState extends State<DemoVideo> {
  late final VideoPlayerController c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool failed = false;
  bool started = false;

  Future<void> _start() async {
    setState(() => started = true);
    try {
      await c.initialize();
      await c.setVolume(0);
      await c.play();
      setState(() {});
    } catch (_) {
      setState(() => failed = true);
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: Brand.navy,
        child: Column(children: [
          AspectRatio(
            aspectRatio: c.value.isInitialized ? c.value.aspectRatio : 16 / 9,
            child: failed
                ? const Center(child: Text('Video unavailable', style: TextStyle(color: Colors.white70)))
                : !started
                    ? InkWell(onTap: _start, child: const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64, semanticLabel: 'Play video')))
                    : !c.value.isInitialized
                        ? const Center(child: CircularProgressIndicator(color: Brand.bronzeLight))
                        : GestureDetector(onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()), child: VideoPlayer(c)),
          ),
          if (c.value.isInitialized)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: Row(children: [
                ValueListenableBuilder(
                  valueListenable: c,
                  builder: (_, v, __) => IconButton(tooltip: v.isPlaying ? 'Pause' : 'Play', onPressed: () => v.isPlaying ? c.pause() : c.play(), icon: Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white)),
                ),
                Expanded(child: VideoProgressIndicator(c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Brand.bronzeLight, bufferedColor: Colors.white30, backgroundColor: Colors.white12))),
                IconButton(
                  tooltip: 'Full screen',
                  onPressed: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => _FullscreenVideo(c))),
                  icon: const Icon(Icons.fullscreen_rounded, color: Colors.white),
                ),
                IconButton(
                  tooltip: 'Picture in picture',
                  onPressed: () => toast(context, kIsWeb ? 'Picture-in-picture is available on native iOS and Android builds.' : 'Picture-in-picture starts when you leave the app.'),
                  icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white),
                ),
              ]),
            ),
          const Padding(padding: EdgeInsets.fromLTRB(12, 0, 12, 10), child: Text('Demonstration clip (Flutter sample video). Not MPC content.', style: TextStyle(color: Colors.white60, fontSize: 11))),
        ]),
      ),
    );
  }
}

class _FullscreenVideo extends StatelessWidget {
  const _FullscreenVideo(this.c);
  final VideoPlayerController c;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF050E1C),
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, leading: IconButton(tooltip: 'Exit full screen', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))),
        body: Center(
          child: GestureDetector(
            onTap: () => c.value.isPlaying ? c.pause() : c.play(),
            child: AspectRatio(aspectRatio: c.value.aspectRatio, child: Stack(alignment: Alignment.bottomCenter, children: [VideoPlayer(c), VideoProgressIndicator(c, allowScrubbing: true)])),
          ),
        ),
      );
}

class _Skip15 extends StatelessWidget {
  const _Skip15({required this.forward});
  final bool forward;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 32,
        height: 32,
        child: Stack(alignment: Alignment.center, children: [
          Transform.flip(flipX: forward, child: const Icon(Icons.replay_rounded, color: Colors.white, size: 32)),
          const Padding(padding: EdgeInsets.only(top: 3), child: Text('15', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
        ]),
      );
}
