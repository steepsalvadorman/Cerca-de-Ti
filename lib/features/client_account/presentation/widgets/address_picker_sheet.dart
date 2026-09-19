import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';

typedef AddressSelection = ({String label, String detail});

Future<AddressSelection?> showAddressPicker(BuildContext context) =>
    showModalBottomSheet<AddressSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _AddressPickerSheet(),
    );

class _AddressPickerSheet extends StatefulWidget {
  const _AddressPickerSheet();

  @override
  State<_AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<_AddressPickerSheet> {
  static const _limaCenter = LatLng(-12.0464, -77.0428);

  final _mapController = MapController();
  final _labelController = TextEditingController(text: 'Casa');
  final _addressController = TextEditingController();
  final _geocoding = Geocoding(locale: const Locale('es', 'PE'));
  Timer? _reverseGeocodeTimer;
  LatLng _selectedPoint = _limaCenter;
  bool _locating = false;
  bool _readingAddress = false;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _useCurrentLocation());
  }

  @override
  void dispose() {
    _reverseGeocodeTimer?.cancel();
    _mapController.dispose();
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationMessage = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationIssue(
          'Activa la ubicación o mueve el mapa manualmente.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _LocationIssue(
          'Sin permiso GPS: mueve el mapa hasta tu dirección.',
        );
      }
      // The cached fix centers the map the moment permission is granted.
      // The GPS can take seconds to answer — worse indoors — and until it
      // does the map would still be sitting on the Lima default, so the
      // person would see a city that is not theirs. Geolocator itself
      // recommends this pair: cached position first, fresh fix after.
      final cached = await Geolocator.getLastKnownPosition();
      if (cached != null) _centerOn(cached);

      final position = await _currentPosition();
      if (position == null) {
        throw const _LocationIssue(
          'No pudimos fijar tu ubicación. Mueve el mapa hasta tu dirección.',
        );
      }
      _centerOn(position);
      await _readAddress(_selectedPoint);
    } on _LocationIssue catch (error) {
      if (mounted) setState(() => _locationMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationMessage =
              'No pudimos obtener tu ubicación. Elígela moviendo el mapa.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Current fix, with the cached one as fallback. `getCurrentPosition`
  /// has no ceiling of its own, so a device that never gets a satellite
  /// lock would leave the sheet spinning with no address at all.
  Future<Position?> _currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      return Geolocator.getLastKnownPosition();
    }
  }

  /// Keeps the pin — which is simply the map center — on [position], so
  /// the address that gets read is always the one under the pin.
  void _centerOn(Position position) {
    if (!mounted) return;
    final point = LatLng(position.latitude, position.longitude);
    _selectedPoint = point;
    _mapController.move(point, 17);
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    _selectedPoint = camera.center;
    _reverseGeocodeTimer?.cancel();
    _reverseGeocodeTimer = Timer(
      const Duration(milliseconds: 650),
      () => _readAddress(_selectedPoint),
    );
  }

  Future<void> _readAddress(LatLng point) async {
    if (mounted) setState(() => _readingAddress = true);
    try {
      final places = await _geocoding.placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (places.isNotEmpty && mounted) {
        _addressController.text = formatPlacemark(places.first);
        setState(() => _locationMessage = null);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationMessage =
              'No se pudo leer la calle. Puedes escribir o corregir la dirección.',
        );
      }
    } finally {
      if (mounted) setState(() => _readingAddress = false);
    }
  }

  void _save() {
    final label = _labelController.text.trim();
    final detail = _addressController.text.trim();
    if (label.isEmpty || detail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega un nombre y confirma la dirección.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop((label: label, detail: detail));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final locationMessage = _locationMessage;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cercaBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
                Expanded(
                  child: Text(
                    'Ubica tu dirección',
                    style: CercaText.sora(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Mueve el mapa hasta dejar el pin sobre la entrada de tu domicilio.',
              style: CercaText.sora(
                fontSize: 12,
                color: AppColors.cercaTextSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _limaCenter,
                        initialZoom: 13,
                        minZoom: 5,
                        maxZoom: 19,
                        onPositionChanged: _onMapMoved,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.cerca.app',
                        ),
                        const RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution('OpenStreetMap contributors'),
                          ],
                        ),
                      ],
                    ),
                    const IgnorePointer(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 38),
                        child: Icon(
                          Icons.location_pin,
                          size: 48,
                          color: AppColors.cercaPrimary,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 28,
                      child: FloatingActionButton.small(
                        heroTag: 'address-current-location',
                        tooltip: 'Usar mi ubicación',
                        onPressed: _locating ? null : _useCurrentLocation,
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.cercaPrimary,
                        child: _locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (locationMessage != null) ...[
              const SizedBox(height: 7),
              Text(
                locationMessage,
                style: CercaText.sora(
                  fontSize: 11,
                  color: AppColors.cercaTextSecondary,
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _labelController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Casa, trabajo…',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Dirección',
                hintText: 'La dirección aparecerá al mover el mapa',
                suffixIcon: _readingAddress
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.edit_location_alt_outlined),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _readingAddress ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Confirmar dirección'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String formatPlacemark(Placemark place) {
  final street = [
    place.street,
    place.subThoroughfare,
  ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' ');
  final parts = [
    street,
    place.subLocality ?? '',
    place.locality ?? '',
    place.administrativeArea ?? '',
  ];
  final unique = <String>[];
  for (final part
      in parts
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)) {
    if (!unique.any((value) => value.toLowerCase() == part.toLowerCase())) {
      unique.add(part);
    }
  }
  return unique.join(', ');
}

class _LocationIssue implements Exception {
  const _LocationIssue(this.message);
  final String message;
}
