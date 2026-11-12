import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../../core/services/desktop_lyric_service.dart';

/// Settings shared by the two compact native lyric capsules.
class DesktopLyricSettingsPanel extends StatefulWidget {
  const DesktopLyricSettingsPanel({super.key});
  @override
  State<DesktopLyricSettingsPanel> createState() =>
      _DesktopLyricSettingsPanelState();
}

class _DesktopLyricSettingsPanelState extends State<DesktopLyricSettingsPanel> {
  final _service = DesktopLyricService.instance;
  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final font = _service.fontSize.clamp(12.0, 18.0);
    final alpha = (100 + _service.opacity * 1.35) / 255;
    // material_ui's host is a different Material type; Flutter controls need
    // this transparent Flutter Material ancestor to paint their ink safely.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Container(
                  key: const ValueKey('lyric-capsule-preview'),
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: const Color(0xADFFF9FF)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF635074).withValues(alpha: alpha),
                        const Color(0xFF271D39).withValues(alpha: alpha),
                        const Color(0xFF3B555A).withValues(alpha: alpha),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFF3C3050),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: Color(0xFF96E2D0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'md3Free · 歌曲名',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFCBBFDD),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '让喜欢的旋律，留在身边。',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: font,
                                color: Color(0xFFF6F1FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('封面、歌曲名和当前歌词收在一个小胶囊里。长歌词平滑滚动，暂停时停在当前位置。'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(child: Text('歌词字号')),
                IconButton(
                  tooltip: '减小歌词字号',
                  onPressed: font > 12
                      ? () => _service.setFontSize(font - 1)
                      : null,
                  icon: const Icon(Icons.text_decrease),
                ),
                Text('${font.round()}'),
                IconButton(
                  tooltip: '增大歌词字号',
                  onPressed: font < 18
                      ? () => _service.setFontSize(font + 1)
                      : null,
                  icon: const Icon(Icons.text_increase),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Expanded(child: Text('玻璃深浅')),
                Text('${_service.opacity}%'),
              ],
            ),
          ),
          Slider(
            value: _service.opacity.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            label: '${_service.opacity}%',
            onChanged: (v) => _service.setOpacity(v.round(), persist: false),
            onChangeEnd: (v) => _service.setOpacity(v.round()),
          ),
          if (Platform.isWindows)
            SwitchListTile.adaptive(
              title: const Text('允许左右移动'),
              subtitle: const Text('关闭后拖动胶囊时只上下移动'),
              value: _service.allowHorizontalMove,
              onChanged: _service.setAllowHorizontalMove,
            ),
          SwitchListTile.adaptive(
            title: const Text('锁定歌词位置'),
            subtitle: Text(
              Platform.isWindows ? '锁定后仍可点击胶囊打开菜单' : '锁定后点击穿透，可在此处或通知栏解锁',
            ),
            value: _service.locked,
            onChanged: (v) => v ? _service.lock() : _service.unlock(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
