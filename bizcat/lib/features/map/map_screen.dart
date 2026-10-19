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
import 'package:bizcat/theme/bz_icons.dart';
import 'package:bizcat/theme/tokens.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Geolocator, LocationAccuracy, LocationPermission, LocationSettings;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' show Distance, LatLng, LengthUnit;
import 'package:material_ui/material_ui.dart';
import 'package:tizbiz_core/tizbiz_core.dart';

/// Where the map opens before results arrive (the selected city, else Termiz).
const Map<String, LatLng> _cityCenters = {'Toshkent': LatLng(41.3111, 69.2797), 'Termiz': LatLng(37.2242, 67.2783)};

/// The first view frames the points within this distance of the city centre (a chain's
/// far-away branches would otherwise zoom out to the whole region).
const double _cityRadiusMeters = 30000;

/// One placemark: a business at its own point, or at one of its branches.
typedef MapPoint = ({String key, BusinessCard card, BusinessBranch? branch, LatLng at});

/// Every placemark of [items]: the business point plus each branch point (a branch at the
/// business's own spot is skipped).
List<MapPoint> mapPoints(List<BusinessCard> items) {
  final out = <MapPoint>[];
  for (final b in items) {
    final main = b.hasLocation ? LatLng(b.lat!, b.lng!) : null;
    if (main != null) out.add((key: b.slug, card: b, branch: null, at: main));
    for (final br in b.branches) {
      if (!br.hasLocation) continue;
      final at = LatLng(br.lat!, br.lng!);
      if (main != null && const Distance().as(LengthUnit.Meter, main, at) < 30) continue;
      out.add((key: '${b.slug}#${br.id}', card: b, branch: br, at: at));
    }
  }
  return out;
}

/// The "4.5+" rating filter.
const double kMapGoodRating = 4.5;

/// The map search (`/map?q=&category=`, the round button in the middle of the bottom bar):
/// business placemarks (logo + rating + review count) on a full-screen map, with a service
/// search and filter chips on top. A placemark tap opens the business card in a modal sheet
/// (closing it removes it at once); `Batafsil` opens the business page.
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
  late final TextEditingController _search = TextEditingController(text: widget.q ?? '');
  late MapQuery _query = MapQuery(q: widget.q, category: widget.category);

  Timer? _timer;
  AnimationController? _camera;
  bool _ready = false;

  /// The user panned/zoomed since the last search: offer "search this area".
  bool _moved = false;

  /// The result list the camera was last fitted to (fit once per new result set).
  List<MapPoint>? _fittedTo;

  /// The key of the placemark whose sheet is open.
  String? _selected;
  LatLng? _me;
  bool _locating = false;

  @override
  void dispose() {
    _timer?.cancel();
    _camera?.dispose();
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  LatLng get _cityCenter => _cityCenters[ref.read(cityProvider)] ?? _cityCenters['Termiz']!;

  /// Placemarks of a result list, cached per list instance (so `identical` works for fitting).
  List<MapPoint> _pointsOf(List<BusinessCard>? items) {
    if (items == null) return const [];
    if (!identical(items, _pointsFor)) {
      _pointsFor = items;
      _points = mapPoints(items);
    }
    return _points;
  }

  List<BusinessCard>? _pointsFor;
  List<MapPoint> _points = const [];

  // ---------------------------------------------------------------- camera

  void _animateTo(LatLng dest, {double? zoom}) {
    if (!_ready) return;
    final cam = _map.camera;
    final center = LatLngTween(begin: cam.center, end: dest);
    final z = Tween<double>(begin: cam.zoom, end: zoom ?? cam.zoom);
    _camera?.dispose();
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _camera = c;
    final t = CurvedAnimation(parent: c, curve: Curves.easeInOutCubic);
    c.addListener(() => _map.move(center.evaluate(t), z.evaluate(t)));
    unawaited(c.forward());
  }

  /// Frames the placemarks, leaving room for the search bar and filters on top. With
  /// [nearCity] only those around the city centre (when there are any).
  void _fit(List<MapPoint> all, {bool nearCity = false}) {
    if (!_ready) return;
    var points = [for (final p in all) p.at];
    if (nearCity) {
      final near = [
        for (final p in points)
          if (const Distance().as(LengthUnit.Meter, _cityCenter, p) <= _cityRadiusMeters) p,
      ];
      if (near.isNotEmpty) points = near;
    }
    if (points.isEmpty) return;
    if (points.length == 1) {
      _map.move(points.first, 15);
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.fromLTRB(60, 200, 60, 120), maxZoom: 16),
    );
  }

  void _onResults(List<MapPoint> points) {
    if (identical(_fittedTo, points)) return;
    _fittedTo = points;
    // A "search this area" result keeps the viewport the user chose.
    if (_query.bbox == null) _fit(points, nearCity: true);
  }

  // ---------------------------------------------------------------- search & filters

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
      final v = value.trim();
      if (mounted) _setQuery(_query.copyWith(q: v.isEmpty ? null : v, bbox: null));
    });
  }

  void _clearSearch() {
    _timer?.cancel();
    _search.clear();
    _setQuery(_query.copyWith(q: null, bbox: null));
  }

  void _setCategory(String? key) => _setQuery(_query.copyWith(category: key == _query.category ? null : key));

  void _toggleRating() => _setQuery(_query.copyWith(minRating: _query.minRating == null ? kMapGoodRating : null));

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
      _fit(_pointsOf(items));
      setState(() => _moved = false);
    }
  }

  // ---------------------------------------------------------------- placemark sheet

  Future<void> _openSheet(MapPoint p) async {
    final b = p.card;
    setState(() => _selected = p.key);
    _animateTo(p.at, zoom: _ready && _map.camera.zoom < 14 ? 15 : null);
    final open = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      useSafeArea: true,
      barrierColor: BzColors.indigo.withValues(alpha: 0.12),
      // Closing removes the card at once (no slide-out).
      sheetAnimationStyle: const AnimationStyle(duration: Duration(milliseconds: 260), reverseDuration: Duration.zero),
      builder: (sheet) => MapBusinessSheet(
        card: b,
        branch: p.branch,
        at: p.at,
        meters: _metersTo(p.at),
        onOpen: () => Navigator.of(sheet).pop(true),
      ),
    );
    if (!mounted) return;
    setState(() => _selected = null);
    if (open ?? false) unawaited(context.push(AppRoutes.business(b.slug)));
  }

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

  double? _metersTo(LatLng at) {
    final me = _me;
    return me == null ? null : const Distance().as(LengthUnit.Meter, me, at);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(mapResultsProvider(_query));
    final items = results.value ?? const <BusinessCard>[];
    final points = _pointsOf(results.value);
    final loading = results.isLoading;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final city = ref.watch(cityProvider);
    final top = MediaQuery.paddingOf(context).top;

    ref.listen(mapResultsProvider(_query), (_, next) {
      final v = next.value;
      if (v != null && !next.isLoading) _onResults(_pointsOf(v));
    });

    final markers = <Marker>[
      for (final p in points)
        if (p.key != _selected) _marker(p, selected: false),
      // The selected placemark is painted last: always on top.
      for (final p in points)
        if (p.key == _selected) _marker(p, selected: true),
    ];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            key: const Key('map'),
            mapController: _map,
            options: MapOptions(
              initialCenter: _cityCenters[city] ?? _cityCenters['Termiz']!,
              initialZoom: 12,
              minZoom: 4,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onMapReady: () {
                _ready = true;
                final v = ref.read(mapResultsProvider(_query)).value;
                if (v != null) _onResults(_pointsOf(v));
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
            query: _query,
            onChanged: _onChanged,
            onClear: _clearSearch,
            onCategory: _setCategory,
            onRating: _toggleRating,
          ),
          if (_moved && !loading)
            Positioned(
              top: top + 132,
              left: 0,
              right: 0,
              child: Center(
                child: _Pill(
                  key: const Key('map-search-here'),
                  icon: BzIcons.refresh,
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(BzSpace.gutter, 0, BzSpace.gutter, BzSpace.l),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _status(context, results, items, dark)),
                    const SizedBox(width: BzSpace.s),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RoundButton(
                          key: const Key('map-show-all'),
                          tooltip: "Hammasini ko'rsatish",
                          icon: BzIcons.fitAll,
                          onTap: _showAll,
                        ),
                        const SizedBox(height: BzSpace.s),
                        _RoundButton(
                          key: const Key('map-locate'),
                          tooltip: 'Mening joylashuvim',
                          icon: BzIcons.myLocation,
                          busy: _locating,
                          onTap: () => unawaited(_locate()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _marker(MapPoint p, {required bool selected}) {
    final b = p.card;
    return Marker(
      key: ValueKey('pin-${p.key}'),
      point: p.at,
      width: kMapPinSize.width,
      height: kMapPinSize.height,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_openSheet(p)),
        child: MapPin(card: b, selected: selected),
      ),
    );
  }

  /// Bottom-left: the result count, an error with retry, or "nothing found"; plus attribution.
  Widget _status(BuildContext context, AsyncValue<List<BusinessCard>> results, List<BusinessCard> items, bool dark) {
    final Widget? pill;
    if (results.hasError && !results.isLoading) {
      pill = _Pill(
        icon: BzIcons.retry,
        label: isOffline(results.error!) ? "Internet yo'q · Qayta urinish" : 'Xatolik · Qayta urinish',
        onTap: () => ref.invalidate(mapResultsProvider(_query)),
      );
    } else if (results.value == null) {
      pill = null;
    } else if (items.isEmpty) {
      pill = _Pill(
        key: const Key('map-empty'),
        icon: BzIcons.searchEmpty,
        label: _query.bbox != null ? 'Bu hududda topilmadi · Hammasi' : 'Hech narsa topilmadi',
        onTap: _query.bbox != null ? _showAll : null,
      );
    } else {
      pill = _Pill(key: const Key('map-count'), icon: BzIcons.shop, label: '${items.length} ta biznes');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ?pill,
        const SizedBox(height: BzSpace.s),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(BzRadius.s),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              kMapAttribution,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: dark ? BzColors.darkMuted : BzColors.muted, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}

/// Back button + service search + filter chips (rating, categories), floating over the map.
class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.controller,
    required this.loading,
    required this.query,
    required this.onChanged,
    required this.onClear,
    required this.onCategory,
    required this.onRating,
  });

  final TextEditingController controller;
  final bool loading;
  final MapQuery query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String?> onCategory;
  final VoidCallback onRating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final canPop = context.canPop();
    final radius = BorderRadius.circular(BzRadius.xl);

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
                  _RoundButton(tooltip: 'Orqaga', icon: BzIcons.back, onTap: () => context.pop()),
                  const SizedBox(width: BzSpace.s),
                ],
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(borderRadius: radius, boxShadow: [_shadow]),
                    child: TextField(
                      key: const Key('map-search'),
                      controller: controller,
                      textInputAction: TextInputAction.search,
                      onChanged: onChanged,
                      onSubmitted: onChanged,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Qaysi xizmat kerak? Soch olish, tort...',
                        prefixIcon: const Icon(BzIcons.search),
                        suffixIcon: loading
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : controller.text.isEmpty
                            ? null
                            : IconButton(tooltip: 'Tozalash', icon: const Icon(BzIcons.close), onPressed: onClear),
                        filled: true,
                        fillColor: scheme.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: radius,
                          borderSide: BorderSide(color: scheme.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 56,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: BzSpace.gutter, vertical: BzSpace.s),
              child: Row(
                children: [
                  _FilterChip(
                    key: const Key('map-rating'),
                    label: '${kMapGoodRating.toStringAsFixed(1)}+',
                    icon: Icons.star_rounded,
                    iconColor: BzColors.apricot,
                    selected: query.minRating != null,
                    onTap: onRating,
                  ),
                  const SizedBox(width: BzSpace.s),
                  _FilterChip(
                    label: 'Hammasi',
                    icon: BzIcons.category,
                    selected: query.category == null,
                    onTap: () => onCategory(null),
                  ),
                  for (final c in categories)
                    if (c.count > 0) ...[
                      const SizedBox(width: BzSpace.s),
                      _FilterChip(
                        key: ValueKey('map-cat-${c.key}'),
                        label: categoryShortLabel(c.label),
                        icon: categoryIconData(c.icon),
                        selected: query.category == c.key,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.iconColor,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(BzRadius.pill), boxShadow: [_shadow]),
        child: Material(
          color: selected ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(BzRadius.pill),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: iconColor ?? fg),
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
                Flexible(child: Text(label, style: theme.textTheme.labelLarge)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
