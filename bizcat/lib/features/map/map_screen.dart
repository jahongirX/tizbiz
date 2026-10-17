import 'dart:async';

import 'package:bizcat/app/routes.dart';
import 'package:bizcat/core/city.dart';
import 'package:bizcat/core/errors.dart';
import 'package:bizcat/core/messenger.dart';
import 'package:bizcat/data/directory_providers.dart';
import 'package:bizcat/features/map/providers.dart';
import 'package:bizcat/features/map/widgets/base_map.dart';
import 'package:bizcat/features/map/widgets/map_business_card.dart';
import 'package:bizcat/features/map/widgets/map_pin.dart';
import 'package:bizcat/shared/widgets/category_icon.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Geolocator, LocationAccuracy, LocationPermission, LocationSettings;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' show Distance, LatLng, LengthUnit;
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Where the map opens before results arrive (the selected city, else Toshkent).
const Map<String, LatLng> _cityCenters = {'Toshkent': LatLng(41.3111, 69.2797), 'Termiz': LatLng(37.2242, 67.2783)};

/// The map search (`/map?q=&category=`): business pins on a full-screen map, search and
/// category chips on top, a swipeable card carousel at the bottom. A pin tap selects its card,
/// a tap on the selected pin or on a card opens the business.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.q, this.category});

  final String? q;
  final String? category;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with TickerProviderStateMixin {
  static const _debounce = Duration(milliseconds: 400);

  final _map = MapController();
  final _pages = PageController(viewportFraction: 0.88);
  late final TextEditingController _search = TextEditingController(text: widget.q ?? '');
  late MapQuery _query = MapQuery(q: widget.q, category: widget.category);

  Timer? _timer;
  AnimationController? _camera;
  bool _ready = false;

  /// The user panned/zoomed since the last search: offer "search this area".
  bool _moved = false;

  /// The result list the camera was last fitted to (fit once per new result set).
  List<BusinessCard>? _fittedTo;
  int _index = 0;

  /// A page change we caused ourselves (pin tap): do not move the camera again.
  bool _programmaticPage = false;
  LatLng? _me;
  bool _locating = false;

  @override
  void dispose() {
    _timer?.cancel();
    _camera?.dispose();
    _pages.dispose();
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  List<BusinessCard> _withLocation(List<BusinessCard> items) => [
    for (final b in items)
      if (b.hasLocation) b,
  ];

  LatLng _point(BusinessCard b) => LatLng(b.lat!, b.lng!);

  // ---------------------------------------------------------------- camera

  void _animateTo(LatLng dest, {double? zoom}) {
    if (!_ready) return;
    final cam = _map.camera;
    final center = LatLngTween(begin: cam.center, end: dest);
    final z = Tween<double>(begin: cam.zoom, end: zoom ?? cam.zoom);
    _camera?.dispose();
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _camera = c;
    final t = CurvedAnimation(parent: c, curve: Curves.easeInOutCubic);
    c.addListener(() => _map.move(center.evaluate(t), z.evaluate(t)));
    unawaited(c.forward());
  }

  /// Frames all pins, leaving room for the search bar on top and the cards below.
  void _fit(List<BusinessCard> items) {
    if (!_ready) return;
    final points = [for (final b in items) _point(b)];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _map.move(points.first, 15);
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(56, 170, 56, kMapCardHeight + 90),
        maxZoom: 16,
      ),
    );
  }

  void _onResults(List<BusinessCard> items) {
    if (identical(_fittedTo, items)) return;
    _fittedTo = items;
    _index = 0;
    if (_pages.hasClients) _pages.jumpToPage(0);
    // A "search this area" result keeps the viewport the user chose.
    if (_query.bbox == null) _fit(items);
  }

  // ---------------------------------------------------------------- search

  void _setQuery(MapQuery next) {
    if (next == _query) return;
    setState(() {
      _query = next;
      _moved = false;
    });
  }

  void _onChanged(String value) {
    setState(() {});
    _timer?.cancel();
    // A text search looks everywhere, not only in the current viewport.
    _timer = Timer(_debounce, () {
      if (mounted) _setQuery(_query.copyWith(q: value.trim().isEmpty ? null : value.trim(), bbox: null));
    });
  }

  void _clearSearch() {
    _timer?.cancel();
    _search.clear();
    _setQuery(_query.copyWith(q: null, bbox: null));
  }

  void _setCategory(String? key) => _setQuery(_query.copyWith(category: key == _query.category ? null : key));

  void _searchHere() {
    if (!_ready) return;
    final b = _map.camera.visibleBounds;
    _setQuery(
      _query.copyWith(
        bbox: bboxParam(west: b.west, south: b.south, east: b.east, north: b.north),
      ),
    );
  }

  void _showAll() {
    final items = ref.read(mapResultsProvider(_query)).value;
    if (_query.bbox != null) {
      _setQuery(_query.copyWith(bbox: null));
    } else if (items != null) {
      _fit(_withLocation(items));
      setState(() => _moved = false);
    }
  }

  // ---------------------------------------------------------------- selection

  void _onPinTap(List<BusinessCard> items, int i) {
    if (i == _index) {
      _open(items[i]);
      return;
    }
    setState(() => _index = i);
    _animateTo(_point(items[i]), zoom: _map.camera.zoom < 14 ? 15 : null);
    if (_pages.hasClients) {
      _programmaticPage = true;
      unawaited(
        _pages
            .animateToPage(i, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic)
            .whenComplete(() => _programmaticPage = false),
      );
    }
  }

  void _onPageChanged(List<BusinessCard> items, int i) {
    setState(() => _index = i);
    if (!_programmaticPage && i < items.length) _animateTo(_point(items[i]));
  }

  void _open(BusinessCard b) => unawaited(context.push(AppRoutes.business(b.slug)));

  // ---------------------------------------------------------------- my location

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        showSnack("Telefonda joylashuv (GPS) o'chirilgan.");
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        showSnack('Joylashuvga ruxsat berilmadi.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      if (!mounted) return;
      final me = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _me = me;
        _moved = true;
      });
      _animateTo(me, zoom: 15);
    } on Object {
      showSnack("Joylashuvni aniqlab bo'lmadi.");
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  double? _metersTo(BusinessCard b) {
    final me = _me;
    return me == null ? null : const Distance().as(LengthUnit.Meter, me, _point(b));
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(mapResultsProvider(_query));
    final items = _withLocation(results.value ?? const []);
    final loading = results.isLoading;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final city = ref.watch(cityProvider);

    ref.listen(mapResultsProvider(_query), (_, next) {
      final v = next.value;
      if (v != null && !next.isLoading) _onResults(_withLocation(v));
    });

    final index = items.isEmpty ? 0 : _index.clamp(0, items.length - 1);
    final markers = <Marker>[
      for (var i = 0; i < items.length; i++)
        if (i != index) _marker(items, i, selected: false),
      // The selected pin is painted last: always on top.
      if (items.isNotEmpty) _marker(items, index, selected: true),
    ];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            key: const Key('map'),
            mapController: _map,
            options: MapOptions(
              initialCenter: _cityCenters[city] ?? _cityCenters['Toshkent']!,
              initialZoom: 12,
              minZoom: 4,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onMapReady: () {
                _ready = true;
                final v = ref.read(mapResultsProvider(_query)).value;
                if (v != null) _onResults(_withLocation(v));
              },
              onPositionChanged: (_, hasGesture) {
                if (hasGesture && !_moved) setState(() => _moved = true);
              },
            ),
            children: [
              BaseMapLayer(dark: dark),
              if (_me != null)
                MarkerLayer(
                  markers: [Marker(point: _me!, width: 36, height: 36, child: const MyLocationDot())],
                ),
              MarkerLayer(markers: markers),
            ],
          ),
          _TopBar(
            controller: _search,
            loading: loading,
            selectedCategory: _query.category,
            onChanged: _onChanged,
            onClear: _clearSearch,
            onCategory: _setCategory,
          ),
          if (_moved && !loading)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 124,
              left: 0,
              right: 0,
              child: Center(
                child: _Pill(
                  key: const Key('map-search-here'),
                  icon: Icons.refresh,
                  label: 'Shu hududda qidirish',
                  onTap: _searchHere,
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(BzRadius.s),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text(
                                  kMapAttribution,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: dark ? BzColors.darkMuted : BzColors.muted,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: BzSpace.s),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _RoundButton(
                              key: const Key('map-show-all'),
                              tooltip: "Hammasini ko'rsatish",
                              icon: Icons.zoom_out_map,
                              onTap: _showAll,
                            ),
                            const SizedBox(height: BzSpace.s),
                            _RoundButton(
                              key: const Key('map-locate'),
                              tooltip: 'Mening joylashuvim',
                              icon: Icons.my_location,
                              busy: _locating,
                              onTap: () => unawaited(_locate()),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: BzSpace.m),
                  _bottom(context, results, items, index),
                  const SizedBox(height: BzSpace.m),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _marker(List<BusinessCard> items, int i, {required bool selected}) {
    final b = items[i];
    return Marker(
      key: ValueKey('pin-${b.slug}'),
      point: _point(b),
      width: kMapPinSize.width,
      height: kMapPinSize.height,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _onPinTap(items, i),
        child: MapPin(card: b, selected: selected),
      ),
    );
  }

  Widget _bottom(BuildContext context, AsyncValue<List<BusinessCard>> results, List<BusinessCard> items, int index) {
    if (results.hasError && !results.isLoading) {
      return Center(
        child: _Pill(
          icon: Icons.refresh,
          label: isOffline(results.error!) ? "Internet yo'q · Qayta urinish" : 'Xatolik · Qayta urinish',
          onTap: () => ref.invalidate(mapResultsProvider(_query)),
        ),
      );
    }
    if (results.value == null) return const SizedBox(height: kMapCardHeight);
    if (items.isEmpty) {
      return Center(
        child: _Pill(
          key: const Key('map-empty'),
          icon: Icons.search_off,
          label: _query.bbox != null ? "Bu hududda topilmadi · Hammasini ko'rish" : 'Hech narsa topilmadi',
          onTap: _query.bbox != null ? _showAll : null,
        ),
      );
    }
    return SizedBox(
      height: kMapCardHeight,
      child: PageView.builder(
        key: const Key('map-cards'),
        controller: _pages,
        itemCount: items.length,
        onPageChanged: (i) => _onPageChanged(items, i),
        itemBuilder: (_, i) => MapBusinessCard(
          card: items[i],
          selected: i == index,
          meters: _metersTo(items[i]),
          onOpen: () => _open(items[i]),
        ),
      ),
    );
  }
}

/// Back button + search field + category chips, floating over the map.
class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.controller,
    required this.loading,
    required this.selectedCategory,
    required this.onChanged,
    required this.onClear,
    required this.onCategory,
  });

  final TextEditingController controller;
  final bool loading;
  final String? selectedCategory;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final canPop = context.canPop();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(BzSpace.gutter, BzSpace.s, BzSpace.gutter, 0),
            child: Row(
              children: [
                if (canPop) ...[
                  _RoundButton(tooltip: 'Orqaga', icon: Icons.arrow_back, onTap: () => context.pop()),
                  const SizedBox(width: BzSpace.s),
                ],
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(BzRadius.pill), boxShadow: [_shadow]),
                    child: TextField(
                      key: const Key('map-search'),
                      controller: controller,
                      textInputAction: TextInputAction.search,
                      onChanged: onChanged,
                      onSubmitted: onChanged,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Xaritadan qidirish...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: loading
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : controller.text.isEmpty
                            ? null
                            : IconButton(tooltip: 'Tozalash', icon: const Icon(Icons.close), onPressed: onClear),
                        filled: true,
                        fillColor: scheme.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(BzRadius.pill),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 52,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter, vertical: BzSpace.s),
              child: Row(
                children: [
                  _CategoryChip(
                    label: 'Hammasi',
                    icon: Icons.apps,
                    selected: selectedCategory == null,
                    onTap: () => onCategory(null),
                  ),
                  for (final c in categories)
                    if (c.count > 0) ...[
                      const SizedBox(width: BzSpace.s),
                      _CategoryChip(
                        key: ValueKey('map-cat-${c.key}'),
                        label: categoryShortLabel(c.label),
                        icon: categoryIconData(c.icon),
                        selected: selectedCategory == c.key,
                        onTap: () => onCategory(c.key),
                      ),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _shadow = BoxShadow(color: BzColors.indigo.withValues(alpha: 0.16), blurRadius: 12, offset: const Offset(0, 4));

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.primary : scheme.surface,
        borderRadius: BorderRadius.circular(BzRadius.pill),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(BzRadius.pill),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(BzRadius.pill), boxShadow: [_shadow]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BzSpace.m, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                  Text(label, style: theme.textTheme.labelLarge?.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.tooltip, required this.icon, required this.onTap, this.busy = false});

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [_shadow]),
      child: Material(
        color: scheme.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          onPressed: busy ? null : onTap,
          icon: busy
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon, color: scheme.onSurface),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(BzRadius.pill), boxShadow: [_shadow]),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(BzRadius.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BzSpace.l, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: scheme.primary),
                const SizedBox(width: BzSpace.s),
                Text(label, style: theme.textTheme.labelLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
