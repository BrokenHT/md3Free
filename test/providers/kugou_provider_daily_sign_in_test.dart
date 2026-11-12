import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:md3music/core/services/daily_sign_in_gate.dart';
import 'package:md3music/data/repositories/settings_repository.dart';
import 'package:md3music/providers/kugou_provider.dart';
import 'package:md3music/services/kugou_api/kugou_api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers/fake_secure_storage.dart';

class _SignInAdapter implements HttpClientAdapter {
  Map<String, dynamic> claim = {'status': 1};
  Map<String, dynamic> upgrade = {'status': 1};
  final calls = <String>[];
  dynamic receiveDay;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    calls.add(path);
    final Map<String, dynamic> body;
    if (path == '/server/now') {
      body = {
        'data': {'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000},
      };
    } else if (path == '/youth/day/vip') {
      receiveDay = (options.data as Map)['receive_day'];
      body = claim;
    } else if (path == '/youth/day/vip/upgrade') {
      body = upgrade;
    } else {
      body = {
        'status': 1,
        'data': {'userid': '9001', 'user_name': 'Test'},
      };
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KugouProvider provider;
  late _SignInAdapter adapter;
  late HttpClientAdapter original;
  final settings = SettingsRepository();
  final today = DailySignInGate.dayKey(DateTime.now());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    installFakeSecureStorage();
    final client = KugouApiClient();
    KugouApiClient.markServerReady();
    await client.clearCookies();
    original = client.dio.httpClientAdapter;
    adapter = _SignInAdapter();
    client.dio.httpClientAdapter = adapter;
    provider = KugouProvider(registerDeviceOnStart: false);
    await client.setLoginCookies('test-token', '9001');
    await provider.refreshUserInfo();
    adapter.calls.clear();
  });
  tearDown(() {
    provider.dispose();
    KugouApiClient().dio.httpClientAdapter = original;
    uninstallFakeSecureStorage();
  });

  test(
    'auto entry completes both API steps once and updates calendar',
    () async {
      await Future.wait(
        List.generate(4, (_) => provider.autoReceiveVipIfNeeded()),
      );
      expect(adapter.calls.where((p) => p == '/youth/day/vip'), hasLength(1));
      expect(
        adapter.calls.where((p) => p == '/youth/day/vip/upgrade'),
        hasLength(1),
      );
      expect(adapter.receiveDay, today);
      expect(await settings.getCompletedSignInDay('9001'), today);
      expect(await settings.getSignedDays(account: '9001'), contains(today));
      expect(provider.isTodayYouthVip, isTrue);
      await provider.autoReceiveVipIfNeeded();
      expect(adapter.calls.where((p) => p == '/youth/day/vip'), hasLength(1));
    },
  );

  test('upgrade failure never marks a successful daily completion', () async {
    adapter.upgrade = {'status': 0, 'error_code': 12345, 'msg': '请稍后重试'};
    await provider.autoReceiveVipIfNeeded();
    expect(await settings.getCompletedSignInDay('9001'), isNull);
    expect(provider.isTodayYouthVip, isFalse);
    expect(provider.autoSignInMessage, contains('升级概念版失败'));
  });

  test(
    'automatic captcha requirement does not open a startup dialog',
    () async {
      adapter.claim = {
        'status': 0,
        'error_code': 20028,
        'ssaCode': 'test-challenge',
      };
      await provider.autoReceiveVipIfNeeded();
      expect(await settings.getCompletedSignInDay('9001'), isNull);
      expect(provider.pendingVerifyCaptcha, isNull);
      expect(provider.autoSignInMessage, contains('安全验证'));
      expect(adapter.calls, isNot(contains('/youth/day/vip/upgrade')));
    },
  );

  test(
    'already claimed entitlement is accepted after successful upgrade',
    () async {
      adapter.claim = {'status': 0, 'error_code': 131001};
      adapter.upgrade = {'status': 0, 'error_code': 20030};
      await provider.autoReceiveVipIfNeeded();
      expect(await settings.getCompletedSignInDay('9001'), today);
    },
  );

  test('disabled setting prevents both automatic API calls', () async {
    await settings.setAutoReceiveVip(false);
    await provider.autoReceiveVipIfNeeded();
    expect(adapter.calls, isEmpty);
    expect(await settings.getCompletedSignInDay('9001'), isNull);
  });

  test(
    'current server already-received-upgrade wording is successful',
    () async {
      adapter.claim = {'status': 0, 'error_code': 131001};
      adapter.upgrade = {'status': 0, 'error_code': 1, 'msg': '已经领取过升级vip奖励'};
      await provider.autoReceiveVipIfNeeded();
      expect(await settings.getCompletedSignInDay('9001'), today);
      expect(provider.autoSignInMessage, '今日已签到');
    },
  );
}
