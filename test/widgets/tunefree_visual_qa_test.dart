import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:md3music/core/theme/app_theme.dart';
import 'package:md3music/core/theme/tunefree_theme.dart';
import 'package:md3music/data/models/song.dart';
import 'package:md3music/modules/tunefree/tunefree_library_section.dart';
import 'package:md3music/providers/favorites_provider.dart';
import 'package:md3music/providers/kugou_provider.dart';
import 'package:md3music/providers/player_provider.dart';

final tracks = List.generate(
  12,
  (i) => Song(
    id: '$i',
    title: ['晚风来信', '慢慢喜欢', '月光漫游', '沿途的风景'][i % 4],
    artist: '界面预览 · 示例收藏',
    album: '音乐，无界',
    duration: const Duration(minutes: 4),
  ),
);

class _PreviewFavorites extends FavoritesProvider {
  _PreviewFavorites() : super(syncOnStart: false);
  @override
  List<Song> get favoritesForBridge => tracks;
  @override
  Future<List<Song>> loadCloudFavoriteSongs() async => tracks;
}

class _PreviewPlayer extends ChangeNotifier implements PlayerProvider {
  @override
  Song? get currentSong => null;
  @override
  bool get isPlaying => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PreviewAccount extends KugouProvider {
  _PreviewAccount() : super(registerDeviceOnStart: false);
  @override
  String get userid => 'visual-preview';
  @override
  bool get isLoggedIn => true;
  @override
  bool get isTodayYouthVip => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final path = Platform.environment['TUNEFREE_QA_FONT'];
    if (path != null) {
      final loader = FontLoader('TuneFreeQA');
      loader.addFont(
        Future.value(ByteData.sublistView(await File(path).readAsBytes())),
      );
      await loader.load();
    }
    final iconPath = Platform.environment['TUNEFREE_QA_ICONS'];
    if (iconPath != null) {
      final icons = FontLoader('MaterialIcons');
      icons.addFont(
        Future.value(ByteData.sublistView(await File(iconPath).readAsBytes())),
      );
      await icons.load();
    }
  });
  for (final width in [390.0, 1280.0]) {
    testWidgets('TuneFree visual QA at $width', (tester) async {
      tester.view.physicalSize = Size(width, 880);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final theme = AppTheme.darkThemeFromSeed(
        AppTheme.defaultSeedColor,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PlayerProvider>(
              create: (_) => _PreviewPlayer(),
            ),
            ChangeNotifierProvider<FavoritesProvider>(
              create: (_) => _PreviewFavorites(),
            ),
            ChangeNotifierProvider<KugouProvider>(
              create: (_) => _PreviewAccount(),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'TuneFreeQA'),
            ),
            home: Stack(
              children: [
                const Positioned.fill(child: TuneFreeAtmosphere()),
                Scaffold(
                  body: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(22, 24, 22, 8),
                              child: Text(
                                '我的收藏',
                                style: TextStyle(
                                  fontFamily: 'TuneFreeQA',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const TuneFreeLibrarySection(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  bottomNavigationBar: TuneFreeNavigationBar(
                    height: 58,
                    selectedIndex: 1,
                    onDestinationSelected: (_) {},
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        label: '首页',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.favorite_outline),
                        label: '收藏',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.grid_view_rounded),
                        label: '探索',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.library_music_outlined),
                        label: '本地',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        label: '我的',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await precacheImage(
          const ResizeImage(
            AssetImage('assets/images/record_sleeve_dark.png'),
            width: 512,
          ),
          tester.element(find.byType(TuneFreeLibrarySection)),
        );
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tunefree-${width.toInt()}.png'),
      );
    }, skip: Platform.environment['TUNEFREE_VISUAL_QA'] != '1');
  }
}
