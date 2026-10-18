import 'dart:async';
import 'dart:math';

import 'package:budgetphonewala/core/data/error_reporter.dart';
import 'package:budgetphonewala/core/data/retry.dart';
import 'package:budgetphonewala/core/errors/app_exception.dart';
import 'package:budgetphonewala/features/catalogue/model_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('retryTransient', () {
    test('repeats transient failures with growing, jittered delays and then succeeds', () async {
      var calls = 0;
      final waits = <Duration>[];
      final r = await retryTransient(() async {
        calls++;
        if (calls < 3) throw TimeoutException('slow');
        return 'ok';
      }, sleep: (d) async => waits.add(d), random: Random(1));
      expect(r, 'ok');
      expect(calls, 3);
      expect(waits.length, 2);
      expect(waits[0].inMilliseconds, inInclusiveRange(200, 600)); // 400ms +-50%
      expect(waits[1].inMilliseconds, inInclusiveRange(400, 1200)); // 800ms +-50%
    });

    test('gives up after the attempt limit and rethrows the last error', () async {
      var calls = 0;
      await expectLater(
        retryTransient(() async { calls++; throw TimeoutException('x'); }, attempts: 3, sleep: (_) async {}),
        throwsA(isA<TimeoutException>()),
      );
      expect(calls, 3, reason: 'bounded: no retry storm');
    });

    test('never repeats a business error (sold out, forbidden, bad coupon)', () async {
      var calls = 0;
      await expectLater(
        retryTransient(() async { calls++; throw AppException('UNAVAILABLE', 'sold'); }, sleep: (_) async {}),
        throwsA(isA<AppException>()),
      );
      expect(calls, 1);
    });

    test('recognises network style failures as transient', () {
      expect(isTransientFailure(TimeoutException('t')), isTrue);
      expect(isTransientFailure(Exception('SocketException: Failed host lookup')), isTrue);
      expect(isTransientFailure(Exception('invalid input')), isFalse);
    });
  });

  group('error mapping', () {
    test('network problems become one friendly message and unknown errors never leak internals', () {
      expect(toAppException(Exception('SocketException: Connection refused')).code, 'NETWORK');
      final unknown = toAppException(StateError('relation "orders" does not exist at db-host-7'));
      expect(unknown.code, 'ERROR');
      expect(unknown.message, isNot(contains('relation')));
      expect(unknown.message, isNot(contains('db-host')));
    });
  });

  group('error reporting', () {
    test('scrubs tokens, emails, long numbers and secrets before anything is sent', () {
      const dirty = 'failed for a.b@shop.in with eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abcDEF123xyz '
          'phone 9850007981 apikey=SECRETVALUE password: hunter2';
      final clean = scrubForReport(dirty);
      for (final leak in ['a.b@shop.in', 'eyJhbGci', '9850007981', 'SECRETVALUE', 'hunter2']) {
        expect(clean, isNot(contains(leak)), reason: leak);
      }
    });

    test('is rate limited, de-duplicated and never throws even when sending fails', () async {
      final sent = <Map<String, dynamic>>[];
      var clock = DateTime(2026, 10, 18, 12);
      final r = RemoteErrorReporter(
        send: (b) async { sent.add(b); throw StateError('network down'); },
        appVersion: '1.0.0', buildNumber: '2', platform: 'android', maxPerMinute: 3, now: () => clock,
      );
      r.report('same error', null);
      r.report('same error', null); // duplicate within a minute: dropped
      for (var i = 0; i < 10; i++) { r.report('different $i', null, category: 'payment'); }
      await Future<void>.delayed(Duration.zero);
      expect(sent.length, 3, reason: 'at most 3 per minute');
      expect(sent.first['app_version'], '1.0.0');
      expect(sent.first.containsKey('user_id'), isFalse, reason: 'identity comes from the verified session, not the payload');
      clock = clock.add(const Duration(minutes: 2));
      r.report('after a quiet minute', null);
      await Future<void>.delayed(Duration.zero);
      expect(sent.length, 4);
    });
  });

  test('catalogue grid adds columns on tablets and large screens', () {
    expect(gridColumns(360), 2);
    expect(gridColumns(600), 3);
    expect(gridColumns(900), 4);
  });
}
