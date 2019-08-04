import 'dart:async';

import 'package:actors/actors.dart';
import 'package:test/test.dart';

import 'local_messenger_test.dart';

class Two with Handler<int, int> {
  @override
  int handle(int message) => message * 2;
}

class SleepsAfterAck with Handler<int, int> {
  int _count = 0;
  Future<void> _maybeSleep = Future.value(null);

  @override
  FutureOr<int> handle(int message) async {
    _count++;
    await _maybeSleep;
    _maybeSleep = Future<void>.delayed(Duration(milliseconds: message));
    return _count;
  }
}

void main() {
  group('ActorGroup can handle messages like a single Actor', () {
    ActorGroup<int, int> actorGroup;

    setUp(() {
      actorGroup = ActorGroup(Two());
    });

    tearDown(() async {
      await actorGroup?.close();
    });

    test('ActorGroup handles messages like single Actor', () async {
      expect(await actorGroup.send(2), equals(4));
      expect(await actorGroup.send(10), equals(20));
      expect(await actorGroup.send(25), equals(50));
    });
  });
  group('ActorGroup RoundRobbin Strategy', () {
    ActorGroup<int, int> actorGroup;

    setUp(() {
      actorGroup =
          ActorGroup(Counter(), size: 3, strategy: const RoundRobbin());
    });

    tearDown(() async {
      await actorGroup?.close();
    });

    test('should handle messages one by one', () async {
      // first round
      expect(await actorGroup.send(1), equals(1));
      expect(await actorGroup.send(1), equals(1));
      expect(await actorGroup.send(1), equals(1));

      // second round
      expect(await actorGroup.send(1), equals(2));
      expect(await actorGroup.send(1), equals(2));
      expect(await actorGroup.send(1), equals(2));

      // third round
      expect(await actorGroup.send(4), equals(6));
      expect(await actorGroup.send(5), equals(7));
      expect(await actorGroup.send(6), equals(8));
    });
  });

  group('ActorGroup AllHandleWithNAcks Strategy', () {
    ActorGroup<int, int> actorGroup;

    setUp(() {
      actorGroup = ActorGroup(Two(),
          size: 3,
          strategy: AllHandleWithNAcks(
              n: 2,
              combineAnswers: (answers) {
                if (answers.length != 2) {
                  throw 'Incorrect number of answers: ${answers}';
                }
                return answers[0] + answers[1];
              }));
    });

    tearDown(() async {
      await actorGroup?.close();
    });

    test('any Actor can handle messages, only 2 acks are awaited', () async {
      expect(await actorGroup.send(100), equals(400));
      expect(await actorGroup.send(200), equals(800));
      expect(await actorGroup.send(300), equals(1200));
    });
  });
  group('ActorGroup errors', () {
    test('size must be > 0', () {
      expect(() {
        ActorGroup<int, int>(Two(), size: 0);
      }, throwsArgumentError);
      expect(() {
        ActorGroup<int, int>(Two(), size: -1);
      }, throwsArgumentError);
    });
    test('AllHandleWithNAcks must now allow n > actorsSize', () {
      // same n as actorsSize is ok
      expect(
          Future.value(ActorGroup<int, int>(Two(),
              size: 3,
              strategy:
                  AllHandleWithNAcks(n: 3, combineAnswers: (a) => a.first))),
          completes);
      expect(() {
        ActorGroup<int, int>(Two(),
            size: 3,
            strategy: AllHandleWithNAcks(n: 4, combineAnswers: (a) => a.first));
      }, throwsStateError);
      expect(() {
        ActorGroup<int, int>(Two(),
            size: 1,
            strategy: AllHandleWithNAcks(n: 4, combineAnswers: (a) => a.first));
      }, throwsStateError);
    });
  });
}
