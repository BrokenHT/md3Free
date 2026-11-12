import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models/song.dart';
import '../core/theme/tunefree_theme.dart';
import '../core/services/frame_timing_probe.dart';
import 'record_sleeve_texture.dart';

/// Pointer signals are claimed only within this widget's hit-test area.
/// A bounded window of sleeves is reused, including for very large libraries.
class TuneFreeRecordRack extends StatefulWidget {
  const TuneFreeRecordRack({
    super.key,
    required this.songs,
    required this.onPlay,
    this.currentSongId,
    this.isPlaying = false,
    this.emptyMessage = '收藏喜欢的歌曲，让唱片架慢慢丰富起来。',
  });
  final List<Song> songs;
  final ValueChanged<int> onPlay;
  final String? currentSongId;
  final bool isPlaying;
  final String emptyMessage;

  @override
  State<TuneFreeRecordRack> createState() => _TuneFreeRecordRackState();
}

class _TuneFreeRecordRackState extends State<TuneFreeRecordRack>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
  );
  // A single clock follows the playing song through the circular rack. Only
  // its label layer listens to ticks; sleeves, text and other songs stay cached.
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  );
  static const _still = AlwaysStoppedAnimation<double>(0);
  int _playingIndex = -1;
  bool _foreground = true;
  bool _animationsAllowed = true;
  final FocusNode _focus = FocusNode(debugLabel: 'TuneFree record rack');
  double _target = 0;
  double _wheel = 0;
  DateTime? _lastWheel;
  String? _selectedId;
  final _faces = <String, Widget>{};
  final _selection = ValueNotifier<int>(0);

  int _index(int index) =>
      widget.songs.isEmpty ? 0 : index % widget.songs.length;
  int get _selected => _index(_position.value.round());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _findPlayingSong();
    _position.addListener(_rememberSelection);
    if (widget.songs.isNotEmpty) _selectedId = widget.songs.first.id;
  }

  void _rememberSelection() {
    if (widget.songs.isNotEmpty) _selectedId = widget.songs[_selected].id;
    _selection.value = _selected;
    _syncRotation();
  }

  void _findPlayingSong() {
    _playingIndex = widget.currentSongId == null
        ? -1
        : widget.songs.indexWhere((song) => song.id == widget.currentSongId);
  }

  void _syncRotation() {
    final distance = (_playingIndex - _selected).abs();
    final visible =
        _playingIndex >= 0 &&
        math.min(distance, widget.songs.length - distance) <=
            math.min(4, widget.songs.length - 1);
    final active =
        widget.isPlaying && visible && _foreground && _animationsAllowed;
    if (active && !_rotation.isAnimating) _rotation.repeat();
    if (!active && _rotation.isAnimating) _rotation.stop(canceled: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsAllowed =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    _syncRotation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncRotation();
  }

  @override
  void didUpdateWidget(covariant TuneFreeRecordRack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final playbackChanged = oldWidget.currentSongId != widget.currentSongId;
    final changed =
        oldWidget.songs.length != widget.songs.length ||
        List.generate(widget.songs.length, (i) => i).any(
          (i) =>
              i >= oldWidget.songs.length ||
              oldWidget.songs[i].id != widget.songs[i].id,
        );
    if (playbackChanged || changed) _findPlayingSong();
    if (playbackChanged) {
      _faces.clear();
      _rotation.value = 0;
    }
    if (changed) {
      final found = widget.songs.indexWhere((song) => song.id == _selectedId);
      final next = found >= 0 ? found : 0;
      _target = next.toDouble();
      _position.value = _target;
      _rememberSelection();
    }
    _syncRotation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rotation.dispose();
    _position.dispose();
    _focus.dispose();
    _selection.dispose();
    super.dispose();
  }

  void _go(double target, {double velocity = 0, bool wheel = false}) {
    if (widget.songs.length < 2) return;
    _target = target.roundToDouble();
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = _target;
    } else {
      _position.animateWith(
        SpringSimulation(
          wheel
              ? const SpringDescription(mass: .65, stiffness: 480, damping: 34)
              : const SpringDescription(mass: .85, stiffness: 250, damping: 33),
          _position.value,
          _target,
          velocity.clamp(wheel ? -32.0 : -12.0, wheel ? 32.0 : 12.0),
          tolerance: const Tolerance(distance: .001, velocity: .01),
        ),
      );
    }
  }

  void _step(int direction) => _go(_target + direction);

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || widget.songs.isEmpty) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      // A one-record library still owns its rack's wheel region.
      if (widget.songs.length < 2) return;
      final scroll = resolved as PointerScrollEvent;
      final delta = scroll.scrollDelta.dy.abs() >= scroll.scrollDelta.dx.abs()
          ? scroll.scrollDelta.dy
          : scroll.scrollDelta.dx;
      if (delta == 0) return;
      final now = DateTime.now();
      if (_lastWheel == null ||
          now.difference(_lastWheel!).inMilliseconds > 180) {
        _wheel = 0;
      }
      if (_wheel != 0 && _wheel.sign != delta.sign) _wheel = 0;
      // Accumulate every event, including trackpad fractions and rapid wheel
      // bursts. 120 logical pixels advance three records, not one debounced step.
      _wheel += delta.clamp(-480.0, 480.0);
      _lastWheel = now;
      final steps = (_wheel / 40).truncate();
      if (steps == 0) return;
      _wheel -= steps * 40;
      _go(_target + steps, velocity: _position.velocity, wheel: true);
    });
  }

  void _play() {
    if (widget.songs.isNotEmpty) widget.onPlay(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (frameProbeEnabled && event.logicalKey == LogicalKeyboardKey.f11) {
          _target += 12;
          _position.animateTo(
            _target,
            duration: const Duration(seconds: 6),
            curve: Curves.linear,
          );
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _step(-1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _step(1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter &&
            widget.songs.isNotEmpty) {
          _play();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(
            constraints.maxWidth >= 600 ? 228.0 : 260.0,
            constraints.maxWidth * .58,
          );
          final stageHeight = side * 239 / 180;
          final stageWidth = math.min(constraints.maxWidth, side * 2.05);
          final dragStep = (stageWidth / 5).clamp(54.0, 78.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: SizedBox(
                  width: stageWidth,
                  child: MouseRegion(
                    cursor: widget.songs.isEmpty
                        ? SystemMouseCursors.basic
                        : SystemMouseCursors.grab,
                    child: Listener(
                      key: const ValueKey('tunefree-rack-scroll-region'),
                      behavior: HitTestBehavior.opaque,
                      onPointerSignal: _onSignal,
                      onPointerDown: (_) => _focus.requestFocus(),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: widget.songs.length > 1
                            ? (_) {
                                _position.stop();
                              }
                            : null,
                        onHorizontalDragUpdate: widget.songs.length > 1
                            ? (event) {
                                _position.value -= event.delta.dx / dragStep;
                                _target = _position.value;
                              }
                            : null,
                        onHorizontalDragEnd: widget.songs.length > 1
                            ? (event) {
                                final speed = event.primaryVelocity ?? 0;
                                final momentum = (-speed * .15 / dragStep)
                                    .clamp(-1.4, 1.4);
                                _go(
                                  (_position.value + momentum).roundToDouble(),
                                  velocity: -speed / dragStep,
                                );
                              }
                            : null,
                        onHorizontalDragCancel: widget.songs.length > 1
                            ? () => _go(_position.value)
                            : null,
                        onVerticalDragEnd: widget.songs.isEmpty
                            ? null
                            : (event) {
                                if ((event.primaryVelocity ?? 0) < -300) {
                                  _play();
                                }
                              },
                        child: SizedBox(
                          height: stageHeight,
                          child: ClipRect(
                            child: AnimatedBuilder(
                              animation: _position,
                              builder: (context, _) =>
                                  _buildSleeves(stageWidth, side, stageHeight),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _selection,
                builder: (context, selection, _) {
                  if (widget.songs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: Text(
                        widget.emptyMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    );
                  }
                  final song = widget.songs[_selected];
                  return Column(
                    children: [
                      SizedBox(
                        height: 64,
                        child: ClipRect(
                          child: AnimatedBuilder(
                            animation: _position,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  song.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  [
                                    song.artist,
                                    if (song.album.isNotEmpty) song.album,
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            builder: (context, child) {
                              // Follow the same continuous position as the vinyl:
                              // next leaves upward and enters from below, previous
                              // reverses this. Swapping occurs only at zero opacity.
                              final distance =
                                  _position.value.round() - _position.value;
                              final weight = (1 - distance.abs() * 2).clamp(
                                0.0,
                                1.0,
                              );
                              return Transform.translate(
                                key: const ValueKey('rack-caption-motion'),
                                offset: Offset(0, distance * 14),
                                child: Opacity(
                                  key: const ValueKey('rack-caption-opacity'),
                                  opacity: weight * weight * (3 - 2 * weight),
                                  child: child,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: '上一张唱片',
                            onPressed: widget.songs.length > 1
                                ? () => _step(-1)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Semantics(
                            liveRegion: true,
                            child: SizedBox(
                              width: 86,
                              child: Text(
                                '${_selected + 1} / ${widget.songs.length}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '下一张唱片',
                            onPressed: widget.songs.length > 1
                                ? () => _step(1)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                          const SizedBox(width: 8),
                          TuneFreeGlass(
                            radius: 999,
                            blur: false,
                            child: IconButton(
                              tooltip: '播放这张唱片',
                              onPressed: _play,
                              color: cs.primary,
                              icon: const Icon(Icons.play_arrow_rounded),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        constraints.maxWidth < 600
                            ? '左右选曲 · 上滑播放 · 轻触唱片播放'
                            : '指针移到唱片上滚轮翻阅 · 点击播放',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _face(Song? song, int number) {
    final key = '${song?.id}|${song?.artworkUri}|${song?.localPath}|$number';
    if (_faces.length > 21) _faces.remove(_faces.keys.first);
    return _faces.putIfAbsent(
      key,
      () => RepaintBoundary(
        child: RecordSleeveTexture(
          artworkUri: song?.artworkUri,
          localPath: song?.localPath,
          number: song == null ? null : number,
          turns: song != null && song.id == widget.currentSongId
              ? _rotation
              : _still,
        ),
      ),
    );
  }

  Widget _buildSleeves(double width, double side, double height) {
    final empty = widget.songs.isEmpty;
    final count = empty ? 3 : math.min(4, widget.songs.length - 1) * 2 + 1;
    final center = empty ? 1 : _position.value.round();
    final slots = List.generate(count, (i) => center + i - count ~/ 2)
      ..sort(
        (a, b) =>
            (b - _position.value).abs().compareTo((a - _position.value).abs()),
      );
    return Stack(
      children: [
        for (final slot in slots) ...[
          Builder(
            builder: (context) {
              final distance = empty
                  ? (slot - 1).toDouble()
                  : slot - _position.value;
              final magnitude = distance.abs();
              final unit = side / 180;
              final scale = 1 - math.min(magnitude, 3.5) * .08;
              final offset =
                  distance.sign *
                  unit *
                  (82 * math.min(magnitude, 1) +
                      42 * math.max(0, magnitude - 1));
              final selected = !empty && slot == _position.value.round();
              final song = empty ? null : widget.songs[_index(slot)];
              return Positioned(
                key: ValueKey('rack-sleeve-$slot'),
                left: (width - side) / 2,
                top: 24 * unit,
                width: side,
                height: side,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, -1 / (900 * unit))
                    ..translateByDouble(
                      offset,
                      math.min(magnitude, 3) * 10 * unit,
                      (58 - math.min(magnitude, 4) * 75) * unit,
                      1,
                    )
                    ..rotateY(
                      (-distance * 60).clamp(-70.0, 70.0) * math.pi / 180,
                    )
                    ..rotateZ((distance * 1.7).clamp(-5.0, 5.0) * math.pi / 180)
                    ..scaleByDouble(scale, scale, 1, 1),
                  child: Opacity(
                    opacity: empty
                        ? .55
                        : (1 - math.max(0, magnitude - 1) * .25).clamp(0, 1),
                    child: Semantics(
                      button: !empty,
                      selected: selected,
                      label: song == null
                          ? '空唱片架'
                          : '${song.displayName}，${song.artist}',
                      child: GestureDetector(
                        onTap: empty
                            ? null
                            : () {
                                if (selected) {
                                  _play();
                                } else {
                                  _go(slot.toDouble());
                                }
                              },
                        child: _face(song, _index(slot) + 1),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
