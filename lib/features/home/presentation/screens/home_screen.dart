import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cerca/application/cerca_controller.dart';
import '../../../cerca/application/cerca_seed_data.dart';
import '../../../cerca/application/cerca_state.dart';
import '../../../cerca/domain/entities/category.dart';
import '../../../cerca/presentation/widgets/back_circle_button.dart';
import '../../../cerca/presentation/widgets/cerca_text_styles.dart';
import '../../../cerca/presentation/widgets/monogram_avatar.dart';
import '../../../cerca/presentation/widgets/verified_badge.dart';
import '../../../technician/application/providers_controller.dart';
import '../../../technician/domain/tech_team.dart';
import '../../../technician/domain/technician.dart';

/// Either a [Technician] or a [TechTeam] — the two provider kinds shown
/// on the map/list, unified by the fields this screen actually reads.
sealed class _Provider {
  const _Provider();

  int get id;
  String get name;
  String get mono;
  String get oficio;
  double get rating;
  String get distance;
  String get priceLabel;
  double get pinTop;
  double get pinLeft;
}

class _TechnicianProvider extends _Provider {
  const _TechnicianProvider(this.value);
  final Technician value;

  @override
  int get id => value.id;
  @override
  String get name => value.name;
  @override
  String get mono => value.mono;
  @override
  String get oficio => value.oficio;
  @override
  double get rating => value.rating;
  @override
  String get distance => value.distance;
  @override
  String get priceLabel => value.priceLabel;
  @override
  double get pinTop => value.pinTop;
  @override
  double get pinLeft => value.pinLeft;
}

class _TeamProvider extends _Provider {
  const _TeamProvider(this.value);
  final TechTeam value;

  @override
  int get id => value.id;
  @override
  String get name => value.name;
  @override
  String get mono => value.mono;
  @override
  String get oficio => value.oficio;
  @override
  double get rating => value.rating;
  @override
  String get distance => value.distance;
  @override
  String get priceLabel => value.priceLabel;
  @override
  double get pinTop => value.pinTop;
  @override
  double get pinLeft => value.pinLeft;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cercaControllerProvider);
    final controller = ref.watch(cercaControllerProvider.notifier);
    final isPuntual = state.jobKind == JobKind.puntual;
    final categories = isPuntual ? CercaSeedData.categories : CercaSeedData.projectCategories;
    final userName = ref.watch(authControllerProvider).value?.user.name.trim().split(' ').first ?? '';
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final providersAsync = ref.watch(providersControllerProvider);
    final providersPage = providersAsync.value;
    final List<_Provider> allProviders = providersPage == null
        ? const []
        : isPuntual
            ? providersPage.technicians.map(_TechnicianProvider.new).toList()
            : providersPage.teams.map(_TeamProvider.new).toList();
    final providers = allProviders.where(_matchesSearch).toList();

    return Scaffold(
      backgroundColor: AppColors.cercaBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hola, $userName', style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextSecondary)),
                            const SizedBox(height: 2),
                            Text('¿Qué necesitas hoy?', style: CercaText.lora(fontSize: 20)),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => context.go(RoutePaths.clientAccount),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.cercaSurfaceTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 21,
                            color: AppColors.cercaPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 90),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.cercaChipTrack,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ModeTab(
                                  label: 'Trabajos puntuales',
                                  active: isPuntual,
                                  onTap: () => controller.setJobKind(JobKind.puntual),
                                ),
                              ),
                              Expanded(
                                child: _ModeTab(
                                  label: 'Proyectos',
                                  active: !isPuntual,
                                  onTap: () => controller.setJobKind(JobKind.proyecto),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: isPuntual
                                ? 'Ej.: fuga, electricidad o cerradura'
                                : 'Ej.: piscina, pozo o construcción',
                            hintStyle: CercaText.sora(fontSize: 13, color: AppColors.cercaTextMuted),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.cercaTextSecondary),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Limpiar búsqueda',
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.cercaBorder),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.cercaPrimary, width: 1.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 84,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            separatorBuilder: (_, _) => SizedBox(width: isPuntual ? 10 : 6),
                            itemBuilder: (context, i) => _CategoryChip(
                              category: categories[i],
                              active: selectedCategory == categories[i].id,
                              wideLabel: !isPuntual,
                              onTap: () =>
                                  ref.read(selectedCategoryProvider.notifier).toggle(categories[i].id),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (providersAsync.isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (providersAsync.hasError)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No se pudieron cargar los técnicos. Desliza para reintentar.',
                              style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextSecondary),
                            ),
                          )
                        else ...[
                          _MapPreview(providers: providers, onSelect: (p) => _select(context, controller, p)),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isPuntual ? 'Técnicos cerca de ti' : 'Equipos cerca de ti',
                                style: CercaText.sora(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              InkWell(
                                onTap: () => _showAllProviders(context, controller, isPuntual),
                                borderRadius: BorderRadius.circular(18),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Ver todos',
                                        style: CercaText.sora(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.cercaPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      const Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.cercaPrimary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (providers.isEmpty)
                            _EmptySearch(query: _query)
                          else
                            for (final p in providers)
                              _ProviderRow(provider: p, onTap: () => _select(context, controller, p)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isPuntual)
              Positioned(
                bottom: 20,
                right: 20,
                child: InkWell(
                  onTap: () => context.push(RoutePaths.jobMode),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.cercaPrimary,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: AppColors.cercaPrimary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Text(
                      '+ Solicitar servicio',
                      style: CercaText.sora(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _select(BuildContext context, CercaController controller, _Provider provider) {
    if (provider is _TeamProvider) {
      controller.selectTeam(provider.id);
    } else {
      controller.selectTech(provider.id);
    }
    context.push(RoutePaths.providerProfile);
  }

  Future<List<_Provider>> _loadAllProviders(bool isPuntual) async {
    final page = await ref.read(technicianRepositoryProvider).getProviders();
    return isPuntual
        ? page.technicians.map(_TechnicianProvider.new).toList()
        : page.teams.map(_TeamProvider.new).toList();
  }

  void _showAllProviders(BuildContext context, CercaController controller, bool isPuntual) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AllProvidersSheet(
        title: isPuntual ? 'Todos los técnicos' : 'Todos los equipos',
        providers: _loadAllProviders(isPuntual),
        onSelect: (provider) {
          ref.read(selectedCategoryProvider.notifier).clear();
          Navigator.of(sheetContext).pop();
          _select(context, controller, provider);
        },
      ),
    );
  }

  bool _matchesSearch(_Provider provider) {
    final query = _normalize(_query.trim());
    if (query.isEmpty) return true;
    final searchable = _normalize('${provider.name} ${provider.oficio} ${_problemTerms(provider.oficio)}');
    return query.split(RegExp(r'\s+')).every(searchable.contains);
  }

  String _problemTerms(String oficio) {
    final value = _normalize(oficio);
    if (value.contains('gasfit') || value.contains('agua')) {
      return 'fuga gotera tuberia cano grifo ducha bano lavadero desague agua';
    }
    if (value.contains('electric')) {
      return 'luz corriente enchufe interruptor cable corto circuito tablero';
    }
    if (value.contains('carpint')) return 'madera mueble puerta mesa silla armario';
    if (value.contains('pint')) return 'pared techo pintura mancha humedad acabado';
    if (value.contains('cerraj')) return 'llave cerradura chapa puerta candado apertura';
    if (value.contains('electrodom')) return 'lavadora refrigeradora cocina horno microondas artefacto';
    if (value.contains('jardin')) return 'jardin pasto planta poda arbol riego';
    if (value.contains('climat') || value.contains('aire')) return 'aire acondicionado frio calor ventilacion';
    if (value.contains('piscina')) return 'piscina agua bomba filtro mantenimiento';
    if (value.contains('pozo')) return 'pozo conexion tuberia agua excavacion';
    if (value.contains('tarrajeo') || value.contains('construccion')) {
      return 'pared muro cemento ladrillo obra remodelacion tarrajeo construccion';
    }
    return '';
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll('ñ', 'n');
}

class _AllProvidersSheet extends StatelessWidget {
  const _AllProvidersSheet({
    required this.title,
    required this.providers,
    required this.onSelect,
  });

  final String title;
  final Future<List<_Provider>> providers;
  final void Function(_Provider) onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.78),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        decoration: const BoxDecoration(
          color: AppColors.cercaBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cercaBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Text(title, style: CercaText.lora(fontSize: 20))),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FutureBuilder<List<_Provider>>(
                future: providers,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'No se pudo cargar el listado completo.',
                        style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextSecondary),
                      ),
                    );
                  }
                  final items = snapshot.data ?? const <_Provider>[];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No hay profesionales disponibles por ahora.',
                        style: CercaText.sora(fontSize: 13, color: AppColors.cercaTextSecondary),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final provider = items[index];
                      return _ProviderRow(provider: provider, onTap: () => onSelect(provider));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.cercaBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, color: AppColors.cercaTextSecondary, size: 28),
          const SizedBox(height: 8),
          Text(
            query.trim().isEmpty
                ? 'No hay técnicos disponibles en esta especialidad.'
                : 'No encontramos resultados para “${query.trim()}”.',
            textAlign: TextAlign.center,
            style: CercaText.sora(fontSize: 12.5, color: AppColors.cercaTextSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Prueba con el oficio o describe el problema con menos palabras.',
            textAlign: TextAlign.center,
            style: CercaText.sora(fontSize: 11, color: AppColors.cercaTextMuted),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.cercaPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: CercaText.sora(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.cercaTextSecondary),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.active,
    required this.onTap,
    this.wideLabel = false,
  });

  final Category category;
  final bool active;
  final VoidCallback onTap;
  final bool wideLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wideLabel ? 82 : 64,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.cercaPrimary : AppColors.cercaSurfaceTint,
                border: Border.all(color: active ? AppColors.cercaPrimary : const Color(0xFFEAD6D2)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: _TradeIcon(categoryId: category.id),
            ),
            const SizedBox(height: 6),
            if (wideLabel)
              SizedBox(
                width: double.infinity,
                height: 28,
                child: Text(
                  category.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: CercaText.sora(
                    fontSize: 10.5,
                    height: 1.2,
                    color: active ? AppColors.cercaPrimary : AppColors.cercaTextSecondary,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 14,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    category.label,
                    maxLines: 1,
                    softWrap: false,
                    style: CercaText.sora(
                      fontSize: 10.5,
                      color: active ? AppColors.cercaPrimary : AppColors.cercaTextSecondary,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Displays one cell from the generated 4x2 trade-icon atlas. Keeping the
/// artwork in one asset makes the category row lightweight and guarantees a
/// consistent style across all eight trades.
class _TradeIcon extends StatelessWidget {
  const _TradeIcon({required this.categoryId});

  static const _cellSize = 38.0;
  static const _columns = 4;
  static const _asset = 'assets/images/trades/trade-icons.png';
  static const _positions = <String, int>{
    'gasfiteria': 0,
    'electricidad': 1,
    'carpinteria': 2,
    'pintura': 3,
    'cerrajeria': 4,
    'electrodomesticos': 5,
    'jardineria': 6,
    'climatizacion': 7,
  };

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final index = _positions[categoryId];
    if (index == null) return const Icon(Icons.handyman_outlined, size: 24);
    final column = index % _columns;
    final row = index ~/ _columns;

    return ClipRect(
      child: SizedBox(
        width: _cellSize,
        height: _cellSize,
        child: Transform.translate(
          offset: Offset(-column * _cellSize, -row * _cellSize),
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: _cellSize * _columns,
            maxWidth: _cellSize * _columns,
            minHeight: _cellSize * 2,
            maxHeight: _cellSize * 2,
            child: Image.asset(
              _asset,
              width: _cellSize * _columns,
              height: _cellSize * 2,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPreview extends StatefulWidget {
  const _MapPreview({required this.providers, required this.onSelect});
  final List<_Provider> providers;
  final void Function(_Provider) onSelect;

  @override
  State<_MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<_MapPreview> {
  static const _limaCenter = LatLng(-12.075, -77.045);

  // Demo locations intentionally placed on urban land in Lima. Technician
  // and team ids overlap, so each provider kind has its own coordinates.
  static const _technicianLocations = <int, LatLng>{
    1: LatLng(-12.1219, -77.0305), // Miraflores
    2: LatLng(-12.1072, -76.9990), // San Borja
    3: LatLng(-12.0750, -77.0450), // Jesús María
    4: LatLng(-12.1450, -76.9910), // Santiago de Surco
  };
  static const _teamLocations = <int, LatLng>{
    1: LatLng(-12.0777, -77.0636), // Pueblo Libre
    2: LatLng(-12.0867, -76.9282), // La Molina
    3: LatLng(-12.0064, -77.0716), // Los Olivos
  };

  LatLng? _userLocation;

  /// Why there is no user pin yet, so the preview can offer the right
  /// action instead of firing the system permission dialog on arrival.
  _LocationBlock? _locationBlock;

  @override
  void initState() {
    super.initState();
    // Only use location that's already allowed; asking is left to the
    // "Usar mi ubicación" chip, where the person knows what it's for.
    _loadUserLocation(askPermission: false);
    // Coming back from system settings: pick up a newly granted permission
    // or switched-on location without needing another tap.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_locationBlock != null) _loadUserLocation(askPermission: false);
      },
    );
  }

  late final AppLifecycleListener _lifecycle;

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _loadUserLocation({required bool askPermission}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (askPermission) await Geolocator.openLocationSettings();
        if (mounted) setState(() => _locationBlock = _LocationBlock.serviceOff);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && askPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (askPermission) await Geolocator.openAppSettings();
        if (mounted) setState(() => _locationBlock = _LocationBlock.blocked);
        return;
      }
      if (permission == LocationPermission.denied) {
        if (mounted) setState(() => _locationBlock = _LocationBlock.needsPermission);
        return;
      }
      if (mounted) setState(() => _locationBlock = null);
      // Neighbourhood-level accuracy is plenty for "0.6 km de ti", and unlike
      // `high` it doesn't trigger Google's extra "Location Accuracy" prompt.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) {
        setState(() => _userLocation = LatLng(position.latitude, position.longitude));
      }
    } catch (_) {
      // The map and the example technicians remain useful without GPS.
    }
  }

  LatLng _providerLocation(_Provider provider) {
    if (provider is _TechnicianProvider) {
      return _technicianLocations[provider.id] ?? _limaCenter;
    }
    return _teamLocations[provider.id] ?? _limaCenter;
  }

  void _openFullMap() {
    // Root navigator: full screen, above the Inicio/Cuenta bottom bar.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullMapScreen(
          providers: widget.providers,
          userLocation: _userLocation,
          locate: _providerLocation,
          onSelect: widget.onSelect,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The preview doesn't pan or zoom: inside the page's scroll view a drag
    // on it has to scroll the page, not move the map. Pins stay tappable and
    // the full, interactive map is one tap away.
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        child: Stack(
          children: [
            _ProvidersMap(
              providers: widget.providers,
              userLocation: _userLocation,
              locate: _providerLocation,
              onSelect: widget.onSelect,
              interactive: false,
              onTapMap: _openFullMap,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: IconButton(
                  onPressed: _openFullMap,
                  tooltip: 'Ver mapa completo',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.open_in_full_rounded, size: 18, color: AppColors.cercaPrimary),
                ),
              ),
            ),
            if (_locationBlock case final block?)
              Positioned(
                left: 8,
                bottom: 8,
                child: _UseLocationChip(
                  block: block,
                  onTap: () => _loadUserLocation(askPermission: true),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _LocationBlock { needsPermission, blocked, serviceOff }

class _UseLocationChip extends StatelessWidget {
  const _UseLocationChip({required this.block, required this.onTap});

  final _LocationBlock block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (block) {
      _LocationBlock.needsPermission => 'Usar mi ubicación',
      _LocationBlock.blocked => 'Permitir ubicación en ajustes',
      _LocationBlock.serviceOff => 'Activar ubicación',
    };
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.my_location_rounded, size: 16, color: AppColors.cercaPrimary),
              const SizedBox(width: 6),
              Text(
                label,
                style: CercaText.sora(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.cercaPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProvidersMap extends StatelessWidget {
  const _ProvidersMap({
    required this.providers,
    required this.userLocation,
    required this.locate,
    required this.onSelect,
    required this.interactive,
    this.onTapMap,
  });

  final List<_Provider> providers;
  final LatLng? userLocation;
  final LatLng Function(_Provider) locate;
  final void Function(_Provider) onSelect;
  final bool interactive;
  final VoidCallback? onTapMap;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: _MapPreviewState._limaCenter,
        initialZoom: 11.5,
        minZoom: 9,
        maxZoom: 18,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
        onTap: onTapMap == null ? null : (_, _) => onTapMap!(),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.salvador.cerca',
        ),
        MarkerLayer(
          markers: [
            if (userLocation != null)
              Marker(
                point: userLocation!,
                width: 42,
                height: 42,
                child: Semantics(
                  label: 'Tu ubicación',
                  child: Container(
                    margin: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppColors.cercaMapPin,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            for (final provider in providers)
              Marker(
                point: locate(provider),
                width: 42,
                height: 46,
                child: InkWell(
                  onTap: () => onSelect(provider),
                  customBorder: const CircleBorder(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.cercaPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 7,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          provider.mono,
                          style: CercaText.sora(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        width: 3,
                        height: 8,
                        color: AppColors.cercaPrimary,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        RichAttributionWidget(
          attributions: const [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }
}

class _FullMapScreen extends StatelessWidget {
  const _FullMapScreen({
    required this.providers,
    required this.userLocation,
    required this.locate,
    required this.onSelect,
  });

  final List<_Provider> providers;
  final LatLng? userLocation;
  final LatLng Function(_Provider) locate;
  final void Function(_Provider) onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _ProvidersMap(
            providers: providers,
            userLocation: userLocation,
            locate: locate,
            interactive: true,
            onSelect: (provider) {
              Navigator.of(context).pop();
              onSelect(provider);
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BackCircleButton(onTap: () => Navigator.of(context).pop()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.provider, required this.onTap});
  final _Provider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.cercaBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            MonogramAvatar(text: provider.mono, fontSize: 15),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          provider.name,
                          overflow: TextOverflow.ellipsis,
                          style: CercaText.sora(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const VerifiedBadge(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      style: CercaText.sora(fontSize: 12, color: AppColors.cercaTextSecondary),
                      children: [
                        TextSpan(text: '${provider.oficio} · ${provider.distance} · '),
                        TextSpan(text: '★', style: CercaText.sora(fontSize: 12, color: AppColors.cercaStar)),
                        TextSpan(text: ' ${provider.rating}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Text(provider.priceLabel, style: CercaText.sora(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
