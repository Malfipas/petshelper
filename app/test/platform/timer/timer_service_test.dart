import 'package:ai_pet_assistant/platform/timer/timer_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// 计时服务只算时间：走秒、暂停、继续、停止、每秒 tick。
///
/// 时钟用手推的假 `now`，不真等；走秒频率用 `FakeAsync` 验，避免测试跑几秒。
void main() {
  late int now;
  late TimerService service;

  setUp(() {
    now = 1000000;
    service = TimerService(now: () => now);
  });

  tearDown(() => service.dispose());

  group('走秒', () {
    test('开始后净时长跟着假时钟长', () {
      service.start('t-1');
      now += 3000;

      expect(service.elapsedMs(), 3000);
      expect(service.running!.taskId, 't-1');
      expect(service.isRunning, isTrue);
    });

    test('没在跑时是 0', () {
      expect(service.elapsedMs(), 0);
      expect(service.running, isNull);
    });

    test('已经有一条在跑时再开始会被挡下', () {
      service.start('t-1');

      expect(() => service.start('t-2'), throwsStateError);
      expect(service.running!.taskId, 't-1');
    });
  });

  group('暂停与继续', () {
    test('暂停冻住，继续接上，暂停那段不进净时长', () {
      service.start('t-1');
      now += 3000;

      service.pause();
      now += 5000;
      expect(service.elapsedMs(), 3000);
      expect(service.running!.paused, isTrue);
      // 暂停中重复按暂停不该改动任何东西。
      service.pause();
      expect(service.elapsedMs(), 3000);

      service.resume();
      now += 2000;
      expect(service.elapsedMs(), 5000);
      expect(service.running!.paused, isFalse);
    });
  });

  group('停止', () {
    test('返回净毫秒并清空状态', () {
      service.start('t-1');
      now += 4000;
      service.pause();
      now += 6000;
      service.resume();
      now += 1000;

      expect(service.stop(), 5000);
      expect(service.running, isNull);
      expect(service.elapsedMs(), 0);
    });

    test('没在跑时停止返回 0', () {
      expect(service.stop(), 0);
    });
  });

  group('每秒 tick', () {
    test('开始后每秒推一次，暂停后不再推', () {
      fakeAsync((async) {
        final ticker = TimerService(now: () => async.elapsed.inMilliseconds);
        var count = 0;
        final sub = ticker.ticks.listen((_) => count++);

        ticker.start('t-1');
        // 开始本身推一次；再走 3 秒，共 4 次。
        async.elapse(const Duration(milliseconds: 3000));
        expect(count, 4);

        ticker.pause();
        async.flushMicrotasks();
        final afterPause = count;
        async.elapse(const Duration(seconds: 3));
        expect(count, afterPause);

        sub.cancel();
        ticker.dispose();
      });
    });

    test('dispose 之后不留定时器', () {
      fakeAsync((async) {
        final ticker = TimerService(now: () => async.elapsed.inMilliseconds);
        ticker.start('t-1');
        ticker.dispose();

        // 没有悬挂定时器时这里不会抛「pending timers」。
        async.elapse(const Duration(seconds: 5));
        expect(ticker.running, isNull);
      });
    });
  });
}
