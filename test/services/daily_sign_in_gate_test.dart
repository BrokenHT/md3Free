import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:md3music/core/services/daily_sign_in_gate.dart';

void main() {
  late DateTime now;
  late Map<String, String> ledger;
  late String account;
  late int requests;
  late DailySignInGate gate;
  setUp(() {
    now = DateTime.utc(2026, 11, 12, 2);
    ledger = {};
    account = 'a';
    requests = 0;
    gate = DailySignInGate(
      clock: () => now,
      readDay: (account) async => ledger[account],
      writeDay: (account, day) async {
        ledger[account] = day;
      },
    );
  });
  Future<DailySignInResult> enter({bool success = true}) {
    final captured = account;
    return gate.run(
      account: captured,
      isCurrentAccount: () => account == captured,
      resolveDay: () async => DailySignInGate.dayKey(now),
      signIn: (_) async {
        requests++;
        return success;
      },
    );
  }

  test(
    'first entry signs once; repeated entry and reconstructed gate skip',
    () async {
      expect(await enter(), DailySignInResult.completed);
      expect(await enter(), DailySignInResult.skipped);
      gate = DailySignInGate(
        clock: () => now,
        readDay: (account) async => ledger[account],
        writeDay: (account, day) async {
          ledger[account] = day;
        },
      );
      expect(await enter(), DailySignInResult.skipped);
      expect(requests, 1);
    },
  );
  test('new day triggers once after an overnight background session', () async {
    await enter();
    now = now.add(const Duration(days: 1));
    expect(await enter(), DailySignInResult.completed);
    await enter();
    expect(requests, 2);
    expect(ledger['a'], '2026-11-13');
  });
  test(
    'account A success never suppresses B and return to A does not repeat',
    () async {
      await enter();
      account = 'b';
      await enter();
      account = 'a';
      await enter();
      expect(requests, 2);
      expect(ledger.length, 2);
    },
  );
  test(
    'failed upgrade remains retryable and is not shown as completed',
    () async {
      expect(await enter(success: false), DailySignInResult.failed);
      expect(ledger, isEmpty);
      expect(await enter(), DailySignInResult.skipped);
      now = now.add(const Duration(minutes: 1));
      expect(await enter(), DailySignInResult.completed);
      expect(requests, 2);
    },
  );
  test(
    'simultaneous startup and resume coalesce to a single request',
    () async {
      final results = await Future.wait(List.generate(8, (_) => enter()));
      expect(results.where((r) => r == DailySignInResult.completed).length, 1);
      expect(requests, 1);
    },
  );
  test('account switch while server date is loading makes no claim', () async {
    final date = Completer<String>();
    final pending = gate.run(
      account: 'a',
      isCurrentAccount: () => account == 'a',
      resolveDay: () => date.future,
      signIn: (_) async {
        requests++;
        return true;
      },
    );
    await Future<void>.delayed(Duration.zero);
    account = 'b';
    date.complete('2026-11-12');
    expect(await pending, DailySignInResult.accountChanged);
    expect(requests, 0);
    expect(ledger, isEmpty);
  });
  test(
    'account switch during a request does not stamp the new account',
    () async {
      final claim = Completer<bool>();
      final pending = gate.run(
        account: 'a',
        isCurrentAccount: () => account == 'a',
        resolveDay: () async => '2026-11-12',
        signIn: (_) => claim.future,
      );
      await Future<void>.delayed(Duration.zero);
      account = 'b';
      claim.complete(true);
      expect(await pending, DailySignInResult.accountChanged);
      expect(ledger, isEmpty);
      expect(await enter(), DailySignInResult.completed);
      expect(ledger.keys, ['b']);
    },
  );
  test('successful manual sign-in suppresses automatic entry', () async {
    await gate.markCompleted('a', '2026-11-12');
    expect(await enter(), DailySignInResult.skipped);
    expect(requests, 0);
  });
  test('service day boundary is UTC+8, independent of device time zone', () {
    expect(
      DailySignInGate.dayKey(DateTime.parse('2026-11-12T15:59:59Z')),
      '2026-11-12',
    );
    expect(
      DailySignInGate.dayKey(DateTime.parse('2026-11-12T16:00:00Z')),
      '2026-11-13',
    );
    expect(
      DailySignInGate.dayKey(DateTime.parse('2026-11-12T08:00:00-08:00')),
      '2026-11-13',
    );
  });
}
