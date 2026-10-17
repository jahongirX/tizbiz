import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vmt;

/// Vector map styles (OpenFreeMap: free, no key, commercial use allowed). Override with
/// `--dart-define=MAP_STYLE=<style.json url>` (e.g. a MapTiler style with its key).
const _styleLight = String.fromEnvironment('MAP_STYLE', defaultValue: 'https://tiles.openfreemap.org/styles/liberty');
const _styleDark = String.fromEnvironment('MAP_STYLE_DARK', defaultValue: 'https://tiles.openfreemap.org/styles/dark');

/// Raster fallback when the vector style cannot be read (OSM tile usage policy: low volume,
/// identified user agent, attribution shown).
const _rasterFallback = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Attribution required by the tiles above.
const kMapAttribution = String.fromEnvironment(
  'MAP_ATTRIBUTION',
  defaultValue: '© OpenFreeMap · © OpenMapTiles · © OpenStreetMap',
);

/// The parsed vector style per brightness (kept for the app's lifetime: one fetch per style).
final mapStyleProvider = FutureProvider.family<vmt.Style, bool>((ref, dark) {
  return vmt.StyleReader(uri: dark ? _styleDark : _styleLight).read();
});

/// The base map layer: the vector style, or OSM raster tiles if the style failed to load.
class BaseMapLayer extends ConsumerWidget {
  const BaseMapLayer({super.key, required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(mapStyleProvider(dark));
    return style.when(
      data: (s) => vmt.VectorTileLayer(
        key: ValueKey('vector-$dark'),
        theme: s.theme,
        sprites: s.sprites,
        tileProviders: s.providers,
        layerMode: vmt.VectorTileLayerMode.vector,
        maximumZoom: 19,
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => TileLayer(urlTemplate: _rasterFallback, userAgentPackageName: 'uz.tizbiz.bizcat', maxZoom: 19),
    );
  }
}
