import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/network/polling.dart';
import '../../auth/application/auth_controller.dart';
import '../data/tracking_repository.dart';
import '../domain/technician_location.dart';

part 'tracking_controller.g.dart';

@riverpod
TrackingRepository trackingRepository(Ref ref) => TrackingRepository(ref.watch(apiClientProvider));

/// Polls `GET /jobs/{id}/location` every few seconds while a client is
/// looking at the tracking screen — the backend has no push/websocket
/// support, matching the chat/offers polling pattern.
@riverpod
Stream<TechnicianLocation?> technicianLocation(Ref ref, String jobId) {
  final repo = ref.watch(trackingRepositoryProvider);
  return pollWithBackoff(() => repo.getLocation(jobId), every: const Duration(seconds: 5));
}

enum LocationSharingStatus { idle, sharing, permissionDenied, serviceDisabled, error }

/// The signed-in technician's live-location broadcast for whichever job is
/// active: periodically reads the device's GPS position and pushes it via
/// `POST /jobs/{id}/location` while sharing is on. Survives navigation
/// (e.g. to the chat screen) so sharing doesn't silently stop mid-job.
@Riverpod(keepAlive: true)
class LocationSharingController extends _$LocationSharingController {
  Timer? _timer;
  int _consecutiveFailures = 0;

  /// A flaky connection should not end the broadcast, but a persistently
  /// failing one should — otherwise the phone keeps waking the GPS for a
  /// job nobody is listening to.
  static const _maxConsecutiveFailures = 3;

  @override
  LocationSharingStatus build() {
    // Being keepAlive, this notifier outlives every screen, so nothing
    // else would ever stop the timer. Signing out must not leave a
    // background GPS broadcast running against the previous account.
    ref.listen(authControllerProvider, (_, next) {
      if (next.value == null) stop();
    });
    ref.onDispose(() => _timer?.cancel());
    return LocationSharingStatus.idle;
  }

  Future<void> start(String jobId) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = LocationSharingStatus.serviceDisabled;
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      state = LocationSharingStatus.permissionDenied;
      return;
    }

    state = LocationSharingStatus.sharing;
    await _pushOnce(jobId);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _pushOnce(jobId));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _consecutiveFailures = 0;
    state = LocationSharingStatus.idle;
  }

  Future<void> _pushOnce(String jobId) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await ref
          .read(trackingRepositoryProvider)
          .updateLocation(jobId, latitude: position.latitude, longitude: position.longitude);
      _consecutiveFailures = 0;
      state = LocationSharingStatus.sharing;
    } on ApiException catch (e) {
      final status = e.statusCode;
      // The server refusing outright — job finished, fee unpaid, no
      // longer the assigned technician — will not become true by
      // retrying, so stop rather than broadcast into the void.
      if (status != null && status >= 400 && status < 500) {
        _stopWithError();
      } else {
        _recordFailure();
      }
    } catch (_) {
      _recordFailure();
    }
  }

  void _recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      _stopWithError();
    } else {
      state = LocationSharingStatus.error;
    }
  }

  void _stopWithError() {
    stop();
    state = LocationSharingStatus.error;
  }
}
