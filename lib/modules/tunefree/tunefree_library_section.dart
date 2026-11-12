import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../providers/favorites_provider.dart';
import '../../providers/kugou_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/tunefree_record_rack.dart';
import '../../core/theme/tunefree_theme.dart';
import '../player/full_player_route.dart';

class TuneFreeLibrarySection extends StatefulWidget {
  const TuneFreeLibrarySection({super.key});
  @override
  State<TuneFreeLibrarySection> createState() => _TuneFreeLibrarySectionState();
}

class _TuneFreeLibrarySectionState extends State<TuneFreeLibrarySection> {
  String? _loadedUser;
  void _loadForUser(String user) {
    if (_loadedUser != user) {
      _loadedUser = user;
      final favorites = context.read<FavoritesProvider>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            favorites.loadCloudFavoriteSongs().catchError(
              (_) => favorites.favorites,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadForUser(context.select<KugouProvider, String?>((p) => p.userid) ?? '');
    final songs = context.watch<FavoritesProvider>().favoritesForBridge;
    final loggedIn = context.select<KugouProvider, bool>((p) => p.isLoggedIn);
    final playback = context.select<PlayerProvider, (String?, bool)>(
      (p) => (p.currentSong?.id, p.isPlaying),
    );
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '我的唱片架',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${songs.length} 首收藏',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TuneFreeRecordRack(
            songs: songs,
            currentSongId: playback.$1,
            isPlaying: playback.$2,
            onPlay: (index) {
              unawaited(
                context.read<PlayerProvider>().playPlaylist(songs, index),
              );
              openFullPlayer(context);
            },
            emptyMessage: loggedIn
                ? '收藏喜欢的歌曲，让唱片架慢慢丰富起来。'
                : '登录酷狗账号，将喜欢的歌曲放进唱片架。',
          ),
        ],
      ),
    );
  }
}

class TuneFreeWelcomeCard extends StatelessWidget {
  const TuneFreeWelcomeCard({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = context.select<KugouProvider, String>(
      (p) => p.isTodayYouthVip ? '今日已签到' : p.autoSignInMessage ?? '每一天，从一首好歌开始',
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: TuneFreeGlass(
        blur: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '音乐，无界',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '让喜欢的旋律，\n留在身边。',
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: cs.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Transform.rotate(
                angle: -.14,
                child: TuneFreeGlass(
                  radius: 23,
                  sleeve: true,
                  blur: false,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/kugou_concept.png',
                        width: 68,
                        height: 68,
                        semanticLabel: '酷狗音乐概念版',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
