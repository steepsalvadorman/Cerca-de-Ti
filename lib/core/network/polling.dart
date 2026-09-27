import 'dart:async';

import 'package:flutter/widgets.dart';

import 'api_exception.dart';

/// Repeatedly calls [fetch] and emits each result — pausing while the app
/// is in the background — the stand-in for the
/// push/websocket support the backend does not have (chat, bidding
/// offers and technician location all poll).
///
/// The naive shape — `while (true) { yield await fetch(); await delay; }`
/// — looks equivalent but ends the stream on the first thrown error, and
/// since the screens render "no data yet" for an empty stream, one lost
/// packet silently froze the view for as long as the user stayed on it.
///
/// Here a failure is survivable: the poll keeps going on a widening
/// delay so a flaky connection recovers on its own without hammering a
/// struggling server. Two failures are *not* survivable and do end the
/// stream, because retrying cannot help:
///   * the server rejecting the request outright (4xx) — the job ended,
///     the fee is unpaid, the caller is no longer a participant;
///   * the caller's session being gone (401), which the Dio interceptor
///     is already turning into a logout.
Stream<T> pollWithBackoff<T>(
  Future<T> Function() fetch, {
  required Duration every,
  Duration maxBackoff = const Duration(seconds: 60),
}) async* {
  var backoff = every;

  while (true) {
    // Nobody is looking while the app is in the background: stop hitting
    // the server (and the battery) until it comes back to the foreground.
    await _untilForeground();
    try {
      yield await fetch();
      backoff = every;
      await Future<void>.delayed(every);
    } on ApiException catch (e) {
      final status = e.statusCode;
      if (status != null && status >= 400 && status < 500) rethrow;

      // Transient (timeout, connection lost, 5xx): wait longer each time,
      // up to a ceiling, and try again.
      await Future<void>.delayed(backoff);
      final next = backoff * 2;
      backoff = next > maxBackoff ? maxBackoff : next;
    }
  }
}

/// Completes right away while the app is visible (or the binding isn't up,
/// as in plain Dart tests), otherwise when it next resumes.
Future<void> _untilForeground() async {
  final AppLifecycleState? state;
  try {
    state = WidgetsBinding.instance.lifecycleState;
  } catch (_) {
    return;
  }
  if (state == null || state == AppLifecycleState.resumed || state == AppLifecycleState.inactive) return;

  final resumed = Completer<void>();
  final listener = AppLifecycleListener(onResume: resumed.complete);
  try {
    await resumed.future;
  } finally {
    listener.dispose();
  }
}
