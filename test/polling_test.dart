import 'dart:ui';

import 'package:cerca/core/network/polling.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('polling pauses in the background and resumes in the foreground', (tester) async {
    var fetches = 0;
    final sub = pollWithBackoff(() async => ++fetches, every: const Duration(seconds: 1)).listen((_) {});

    await tester.pump();
    expect(fetches, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 5));
    expect(fetches, 1, reason: 'no requests while the app is in the background');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(fetches, 2, reason: 'fetches again as soon as it is back');

    await tester.pump(const Duration(seconds: 1));
    expect(fetches, 3);

    // Cancelling waits for the generator's pending delay, which only
    // elapses on fake time: cancel, then let that delay run out.
    final cancelled = sub.cancel();
    await tester.pump(const Duration(seconds: 2));
    await cancelled;
  });
}
