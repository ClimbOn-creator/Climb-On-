import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../crag_sidebar.dart';
import '../config/offline_map_config.dart';
import '../models/climb_route.dart';
import '../models/crag.dart';
import '../models/map_path_catalog.dart';
import '../models/offline_bc_region.dart';
import '../models/saved_trail.dart';
import '../models/ski_route.dart';
import '../models/wall.dart';
import '../services/database_service.dart';
import '../state/admin_state.dart';
import '../state/activity_mode_state.dart';
import '../state/app_settings_state.dart';
import '../state/catalog_state.dart';
import '../state/climb_log_state.dart';
import '../state/map_path_state.dart';
import '../state/offline_region_state.dart';
import '../state/ski_route_state.dart';
import '../state/trail_library_state.dart';
import '../utils/number_parser.dart';
import '../widgets/pulsing_user_marker.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _recordingDraftKey = 'climb_on_recording_draft_v1';
  static const _minimumDataZoom = 6.5;
  double currentZoom = 14;
  LatLng? userLocation;
  double? userLocationAccuracyMeters;
  double? userAltitudeMeters;
  Crag? selectedCrag;
  Wall? selectedWall;
  Crag? selectedParkingCrag;
  SkiRoute? selectedSkiRoute;
  String? selectedSkiRouteId;
  _MapTileStyle tileStyle = _MapTileStyle.clean;
  bool editMode = false;
  bool pathEditMode = false;
  _PathDraftKind? pathDraftKind;
  int pathDraftColorValue = savedTrailColors.first;
  int traceColorIndex = 0;
  int? selectedPathPointIndex;
  List<LatLng> pathDraft = [];
  OfflineBcRegion? editingOfflineRegion;
  LatLng? currentMapCenter;
  double currentMapRotation = 0;
  final Set<_MapRouteFilter> activeFilters = {};
  final MapController mapController = MapController();
  ml.MapLibreMapController? mapLibreController;
  StreamSubscription<Position>? positionSubscription;
  Timer? recordingTimer;
  bool gpsRecording = false;
  bool appliedInitialSettings = false;
  String? appliedFocusedClimbRouteId;
  String? appliedFocusedSkiRouteId;
  _PathDraftKind? recordedPathKind;
  DateTime? recordingStartedAt;
  Duration recordingElapsed = Duration.zero;
  List<_RecordedTrackPoint> recordedTrack = [];
  int recordedColorValue = savedTrailColors.first;

  List<LatLng> get recordedPath => [
    for (final point in recordedTrack) point.location,
  ];

  bool get showClusters => currentZoom < 13;
  bool get showSkiAllCluster => currentZoom < 8;
  bool get showSkiRegionClusters => currentZoom >= 8 && currentZoom < 10;
  bool get showSkiAreaClusters => currentZoom >= 10 && currentZoom < 12.5;
  bool get mapIsRotated => currentMapRotation.abs() > 0.5;

  List<Crag> visibleCrags(List<Crag> sourceCrags) {
    if (activeFilters.isEmpty) return sourceCrags;

    return sourceCrags.where((crag) {
      return crag.walls.any((wall) => wall.routes.any(_routeMatchesFilters));
    }).toList();
  }

  SkiRoute? _activeSkiRoute(List<SkiRoute> routes) {
    final selectedId = selectedSkiRouteId ?? selectedSkiRoute?.id;
    if (selectedId != null) {
      for (final route in routes) {
        if (route.id == selectedId) return route;
      }
    }
    return selectedSkiRoute;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_restoreRecordedDraft());
    loadUserLocation();
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> loadUserLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
    if (!mounted) return;

    _setUserPosition(position);
    positionSubscription?.cancel();
    positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen(_setUserPosition);
  }

  void _setUserPosition(Position position) {
    if (!mounted) return;
    final point = LatLng(position.latitude, position.longitude);
    var addedRecordingPoint = false;
    setState(() {
      userLocation = point;
      userLocationAccuracyMeters = position.accuracy;
      userAltitudeMeters = position.altitude.isFinite
          ? position.altitude
          : null;
      if (gpsRecording && position.accuracy <= 50) {
        final shouldAdd =
            recordedTrack.isEmpty ||
            const Distance().as(
                  LengthUnit.Meter,
                  recordedTrack.last.location,
                  point,
                ) >=
                3;
        if (shouldAdd) {
          addedRecordingPoint = true;
          recordedTrack.add(
            _RecordedTrackPoint(
              location: point,
              altitudeMeters: position.altitude.isFinite
                  ? position.altitude
                  : null,
              recordedAt: DateTime.now(),
            ),
          );
        }
      }
    });
    if (addedRecordingPoint) unawaited(_persistRecordedDraft());
  }

  List<_CragCluster> clusterCrags(List<Crag> cragsToCluster) {
    final buckets = <String, List<Crag>>{};
    final bucketScale = currentZoom < 9
        ? 2
        : currentZoom < 11
        ? 5
        : 12;

    for (final crag in cragsToCluster) {
      final key =
          '${(crag.location.latitude * bucketScale).round()}_'
          '${(crag.location.longitude * bucketScale).round()}';
      buckets.putIfAbsent(key, () => []).add(crag);
    }

    return buckets.values.map((bucket) {
      final avgLat =
          bucket.map((crag) => crag.location.latitude).reduce((a, b) => a + b) /
          bucket.length;
      final avgLng =
          bucket
              .map((crag) => crag.location.longitude)
              .reduce((a, b) => a + b) /
          bucket.length;
      return _CragCluster(point: LatLng(avgLat, avgLng), crags: bucket);
    }).toList();
  }

  List<_SkiRouteCluster> clusterSkiRoutesByRegion(List<SkiRoute> routes) {
    return _clusterSkiRoutesBy(routes, (route) => route.region);
  }

  List<_SkiRouteCluster> clusterSkiRoutesByArea(List<SkiRoute> routes) {
    return _clusterSkiRoutesBy(routes, (route) => route.area);
  }

  List<_SkiRouteCluster> _clusterSkiRoutesBy(
    List<SkiRoute> routes,
    String Function(SkiRoute route) labelFor,
  ) {
    final regions = <String, List<SkiRoute>>{};
    for (final route in routes) {
      final label = labelFor(route).trim().isEmpty
          ? 'Unknown'
          : labelFor(route);
      regions.putIfAbsent(label, () => []).add(route);
    }

    return regions.entries.map((entry) {
      final bucket = entry.value;
      final avgLat =
          bucket.fold<double>(
            0,
            (sum, route) => sum + route.location.latitude,
          ) /
          bucket.length;
      final avgLng =
          bucket.fold<double>(
            0,
            (sum, route) => sum + route.location.longitude,
          ) /
          bucket.length;
      return _SkiRouteCluster(
        label: entry.key,
        point: LatLng(avgLat, avgLng),
        routes: bucket,
      );
    }).toList();
  }

  _SkiRouteCluster? clusterAllSkiRoutes(List<SkiRoute> routes) {
    if (routes.isEmpty) return null;
    final avgLat =
        routes.fold<double>(0, (sum, route) => sum + route.location.latitude) /
        routes.length;
    final avgLng =
        routes.fold<double>(0, (sum, route) => sum + route.location.longitude) /
        routes.length;
    return _SkiRouteCluster(
      label: 'Ski tours',
      point: LatLng(avgLat, avgLng),
      routes: routes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 860;
    final showTitleBar = width >= 1024;
    final mode = ref.watch(activityModeProvider);
    final settings = ref.watch(appSettingsProvider);
    if (!appliedInitialSettings && settings.loaded) {
      appliedInitialSettings = true;
      if (settings.prefer3d && _supportsMapLibre) {
        tileStyle = _MapTileStyle.terrain3d;
      }
    }
    final catalog = ref.watch(catalogProvider);
    final skiCatalog =
        ref.watch(skiRouteCatalogProvider).valueOrNull ?? const <SkiRoute>[];
    final activeSkiRoute = _activeSkiRoute(skiCatalog);
    final mapPaths =
        ref.watch(mapPathCatalogProvider).valueOrNull ?? const MapPathCatalog();
    final savedTrails = ref.watch(trailLibraryProvider).trails;
    final mapRegions =
        ref.watch(offlineRegionCatalogProvider).valueOrNull ?? offlineBcRegions;
    final catalogCrags = catalog.valueOrNull ?? const <Crag>[];
    final mapCrags = visibleCrags(catalogCrags);
    final focusedClimbRoute = ref.watch(focusedRouteProvider);
    final focusedSkiRoute = ref.watch(focusedSkiRouteProvider);
    _scheduleFocusedRouteSelection(
      focusedClimbRoute: focusedClimbRoute,
      focusedSkiRoute: focusedSkiRoute,
      catalogCrags: catalogCrags,
    );
    final mapLibreStyle = _mapLibreStyleFor(tileStyle);
    final useMapLibre =
        _supportsMapLibre &&
        (tileStyle == _MapTileStyle.terrain3d ||
            (!pathEditMode && mapLibreStyle != null));
    final initialCenter =
        userLocation ??
        (mode == ActivityMode.ski
            ? (skiCatalog.isEmpty
                  ? const LatLng(49.9120, -123.1050)
                  : skiCatalog.first.location)
            : mapCrags.isEmpty
            ? const LatLng(48.43989, -123.56344)
            : mapCrags.first.location);

    return Scaffold(
      appBar: showTitleBar ? AppBar(title: const Text('Map')) : null,
      body: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (useMapLibre)
                  _Terrain3DMap(
                    styleOverride: mapLibreStyle,
                    enableTerrain: tileStyle == _MapTileStyle.terrain3d,
                    center: currentMapCenter ?? initialCenter,
                    zoom: currentZoom,
                    mode: mode,
                    crags: mapCrags,
                    skiRoutes: skiCatalog,
                    paths: mapPaths,
                    savedTrails: savedTrails,
                    recordedPath: recordedPath,
                    recordedColorValue: recordedColorValue,
                    regions: mapRegions,
                    selectedCrag: selectedCrag,
                    selectedSkiRoute: activeSkiRoute,
                    userLocation: userLocation,
                    onCragTap: (crag) => _selectCrag(context, wide, crag),
                    onSkiRouteTap: (route) => _selectSkiRoute(context, route),
                    onControllerReady: (controller) {
                      mapLibreController = controller;
                    },
                    allowRotation: settings.twoFingerRotation,
                  )
                else
                  FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: currentZoom,
                      minZoom: 5,
                      maxZoom: 19,
                      cameraConstraint: CameraConstraint.containCenter(
                        bounds: LatLngBounds(
                          LatLng(bcMapBounds.south, bcMapBounds.west),
                          LatLng(bcMapBounds.north, bcMapBounds.east),
                        ),
                      ),
                      interactionOptions: InteractionOptions(
                        flags: settings.twoFingerRotation
                            ? InteractiveFlag.all
                            : InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onTap: (_, point) => _handleMapTap(point),
                      onPositionChanged: (position, _) {
                        if (position.zoom != null) {
                          final nextZoom = position.zoom!;
                          final clusterStateChanged =
                              (nextZoom < 13) != showClusters;
                          final dataVisibilityChanged =
                              (nextZoom < _minimumDataZoom) !=
                              (currentZoom < _minimumDataZoom);
                          final meaningfulZoomChange =
                              (nextZoom - currentZoom).abs() >= 0.5;

                          if (clusterStateChanged ||
                              dataVisibilityChanged ||
                              meaningfulZoomChange) {
                            setState(() => currentZoom = nextZoom);
                          }
                        }
                        currentMapCenter = position.center;
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: tileStyle.urlTemplate,
                        subdomains: tileStyle.subdomains,
                        retinaMode: tileStyle == _MapTileStyle.clean,
                        userAgentPackageName: 'com.climbon.app',
                      ),
                      if (currentZoom < 9)
                        PolygonLayer(
                          polygons: _offlineRegionPolygons(mapRegions),
                        ),
                      if (tileStyle == _MapTileStyle.satellite)
                        TileLayer(
                          urlTemplate:
                              'https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          retinaMode: true,
                          userAgentPackageName: 'com.climbon.app',
                        ),
                      PolylineLayer(
                        polylines: [
                          for (final trail in savedTrails)
                            Polyline(
                              points: trail.points,
                              color: trail.color,
                              strokeWidth: 5,
                              borderColor: Colors.white,
                              borderStrokeWidth: 1,
                            ),
                          ...(mode == ActivityMode.ski
                              ? currentZoom >= _minimumDataZoom
                                    ? _skiLines(
                                        mapPaths,
                                        skiCatalog,
                                        activeSkiRoute,
                                      )
                                    : const <Polyline>[]
                              : _approachLines(mapPaths)),
                          if (pathEditMode && pathDraft.length >= 2)
                            Polyline(
                              points:
                                  pathDraftKind == _PathDraftKind.regionBoundary
                                  ? [...pathDraft, pathDraft.first]
                                  : pathDraft,
                              color: Color(pathDraftColorValue),
                              strokeWidth: 5,
                            ),
                          if (recordedPath.length >= 2)
                            Polyline(
                              points: recordedPath,
                              color: Color(recordedColorValue),
                              strokeWidth: 6,
                              borderColor: Colors.white,
                              borderStrokeWidth: 2,
                            ),
                        ],
                      ),
                      if (userLocation != null &&
                          userLocationAccuracyMeters != null)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: userLocation!,
                              radius: userLocationAccuracyMeters!.clamp(1, 250),
                              useRadiusInMeter: true,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.16),
                              borderColor: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.46),
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        rotate: false,
                        markers: [
                          if (wide && currentZoom >= 6.5 && currentZoom < 9)
                            ..._offlineRegionMarkers(mapRegions),
                          ...(mode == ActivityMode.ski
                              ? _skiMarkers(context, skiCatalog, activeSkiRoute)
                              : _markers(context, wide, mapCrags)),
                          ..._pathEditorMarkers(),
                        ],
                      ),
                      SimpleAttributionWidget(
                        source: Text(tileStyle.attribution),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.82),
                      ),
                    ],
                  ),
                if (wide && !useMapLibre && currentZoom < 6.5)
                  Positioned(
                    right: 12,
                    bottom: 158,
                    child: _BcRegionLegend(regions: mapRegions),
                  ),
                if (useMapLibre && OfflineMapConfig.mapsConfigured)
                  Positioned(
                    right: 8,
                    bottom: 5,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Text(
                            OfflineMapConfig.openMapAttribution,
                            style: TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                    ),
                  ),
                _MapLayerSwitcher(
                  selected: tileStyle,
                  terrainAvailable:
                      _supportsMapLibre && OfflineMapConfig.terrainConfigured,
                  onChanged: (style) {
                    if (style == _MapTileStyle.terrain3d && pathEditMode) {
                      _cancelPathEditor();
                    }
                    setState(() {
                      tileStyle = style;
                      if (!_usesMapLibre(style)) mapLibreController = null;
                    });
                  },
                  onTerrainChanged: (enabled) {
                    if (enabled && pathEditMode) _cancelPathEditor();
                    setState(() {
                      tileStyle = enabled
                          ? _MapTileStyle.terrain3d
                          : _MapTileStyle.satellite;
                    });
                  },
                ),
                _AdminMapTools(
                  isAdmin:
                      ref.watch(isMapAdminProvider).valueOrNull == true &&
                      tileStyle != _MapTileStyle.terrain3d,
                  editMode: editMode,
                  selectedCrag: selectedCrag,
                  selectedWall: selectedWall,
                  selectedSkiRoute: activeSkiRoute,
                  mode: mode,
                  mapCenter: currentMapCenter ?? initialCenter,
                  onToggleEditMode: () {
                    setState(() => editMode = !editMode);
                  },
                  onEdit: _openCoordinateEditor,
                  onTracePath: (kind) =>
                      _startPathEditor(kind, mapPaths, activeSkiRoute),
                  onCreateSkiRoute: _startNewSkiRoutePath,
                  regions: mapRegions,
                  editingRegion: editingOfflineRegion,
                  onEditRegion: _startRegionBoundaryEditor,
                ),
                if (wide && tileStyle != _MapTileStyle.terrain3d)
                  _HeadingControl(
                    headingDegrees: currentMapRotation,
                    onHeadingChanged: _setMapHeading,
                    onResetNorth: () => _setMapHeading(0),
                  ),
                if (editMode && !pathEditMode)
                  const IgnorePointer(
                    child: Center(
                      child: Icon(
                        Icons.add_location_alt,
                        size: 38,
                        color: Colors.red,
                      ),
                    ),
                  ),
                if (pathEditMode)
                  _PathEditorTools(
                    pointCount: pathDraft.length,
                    lengthMeters: _pathLength(pathDraft),
                    hasSelectedPoint: selectedPathPointIndex != null,
                    onUndo: pathDraft.isEmpty ? null : _undoPathPoint,
                    onDeleteSelected: selectedPathPointIndex == null
                        ? null
                        : _deleteSelectedPathPoint,
                    onClear: pathDraft.isEmpty ? null : _clearPath,
                    onCancel: _cancelPathEditor,
                    onSave:
                        pathDraft.length <
                            (pathDraftKind == _PathDraftKind.regionBoundary
                                ? 3
                                : 2)
                        ? null
                        : _savePath,
                  ),
                if (!pathEditMode && tileStyle != _MapTileStyle.terrain3d)
                  _GpsRecorderTools(
                    top: mode == ActivityMode.climb ? 64 : 94,
                    recording: gpsRecording,
                    elapsed: recordingElapsed,
                    hasDraft: recordedTrack.isNotEmpty,
                    color: Color(recordedColorValue),
                    pointCount: recordedTrack.length,
                    lengthMeters: _pathLength(recordedPath),
                    ascentMeters: _verticalMeters(recordedTrack).ascent,
                    descentMeters: _verticalMeters(recordedTrack).descent,
                    onStart: _startRecording,
                    onStop: _stopGpsRecording,
                    onSave: _saveGpsRecording,
                    onDiscard: _discardGpsRecording,
                  ),
                if (mode == ActivityMode.climb)
                  _MapFilters(
                    activeFilters: activeFilters,
                    top: 8,
                    alignLeft: false,
                    onToggle: _toggleFilter,
                  )
                else
                  const _SkiMapLegend(top: 8),
                if (catalog.isLoading)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                if (selectedParkingCrag != null)
                  _ParkingCoordinateBanner(
                    crag: selectedParkingCrag!,
                    onClose: () => setState(() => selectedParkingCrag = null),
                    onCopy: _copyParkingCoordinates,
                    onShare: _shareParkingCoordinates,
                    onOpenMaps: _openParkingInMaps,
                  ),
              ],
            ),
          ),
          if (wide && selectedCrag != null)
            SizedBox(
              width: 380,
              child: CragSidebar(
                crag: selectedCrag!,
                selectedWall: selectedWall,
                onWallSelected: (wall) {
                  setState(() => selectedWall = wall);
                },
                onRouteSelected: _openRouteInFeed,
              ),
            ),
        ],
      ),
    );
  }

  List<Marker> _markers(BuildContext context, bool wide, List<Crag> mapCrags) {
    return [
      if (userLocation != null)
        Marker(
          point: userLocation!,
          width: 56,
          height: 56,
          child: const PulsingUserMarker(),
        ),
      if (currentZoom >= _minimumDataZoom && showClusters)
        ...clusterCrags(mapCrags).map((cluster) {
          final count = cluster.crags.length;
          final markerSize = currentZoom < 8
              ? (count > 9 ? 38.0 : 34.0)
              : currentZoom < 10
              ? (count > 9 ? 46.0 : 40.0)
              : (count > 9 ? 54.0 : 48.0);

          return Marker(
            point: cluster.point,
            width: markerSize,
            height: markerSize,
            child: Tooltip(
              message: count == 1
                  ? cluster.crags.first.name
                  : '$count nearby crags',
              child: GestureDetector(
                onTap: () {
                  if (count == 1) {
                    final crag = cluster.crags.first;
                    setState(() {
                      selectedCrag = crag;
                      selectedWall = crag.walls.isEmpty
                          ? null
                          : crag.walls.first;
                    });
                  } else {
                    mapController.move(
                      cluster.point,
                      (currentZoom + 2).clamp(10, 14),
                    );
                  }
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: currentZoom < 8 ? 2 : 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 5,
                        color: Color(0x55000000),
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        })
      else if (currentZoom >= _minimumDataZoom)
        ...mapCrags.map(
          (crag) => Marker(
            point: crag.location,
            width: 150,
            height: 52,
            child: Tooltip(
              message: crag.name,
              child: GestureDetector(
                onTap: () => _selectCrag(context, wide, crag),
                child: _LabeledMapMarker(
                  label: crag.name,
                  icon: Icons.terrain,
                  selected: selectedCrag == crag,
                ),
              ),
            ),
          ),
        ),
      if (currentZoom >= _minimumDataZoom)
        ...mapCrags
            .where(_shouldShowParking)
            .map(
              (crag) => Marker(
                point: crag.parking,
                width: 30,
                height: 30,
                child: Tooltip(
                  message: '${crag.name} parking',
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCrag = crag;
                        selectedWall = crag.walls.isEmpty
                            ? null
                            : crag.walls.first;
                        selectedParkingCrag = crag;
                      });
                    },
                    child: const _ParkingMarkerIcon(),
                  ),
                ),
              ),
            ),
    ];
  }

  List<Polygon> _offlineRegionPolygons(List<OfflineBcRegion> regions) {
    return [
      for (final region in regions)
        for (final boundary in region.polygons)
          Polygon(
            points: boundary,
            color: Color(region.colorValue).withValues(alpha: 0.18),
            borderColor: Color(region.colorValue).withValues(alpha: 0.92),
            borderStrokeWidth: 2,
            isFilled: true,
          ),
    ];
  }

  List<Marker> _offlineRegionMarkers(List<OfflineBcRegion> regions) {
    return [
      for (final region in regions)
        Marker(
          point: region.center,
          width: 128,
          height: 42,
          child: GestureDetector(
            onTap: () => mapController.move(region.center, 7.5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(region.colorValue).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    region.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  List<Marker> _skiMarkers(
    BuildContext context,
    List<SkiRoute> routes,
    SkiRoute? activeRoute,
  ) {
    final allCluster = clusterAllSkiRoutes(routes);
    return [
      if (userLocation != null)
        Marker(
          point: userLocation!,
          width: 56,
          height: 56,
          child: const PulsingUserMarker(),
        ),
      if (currentZoom >= _minimumDataZoom &&
          showSkiAllCluster &&
          allCluster != null)
        _skiClusterMarker(
          context,
          cluster: allCluster,
          label: 'All ski tours',
          zoomTarget: 8.5,
        )
      else if (currentZoom >= _minimumDataZoom && showSkiRegionClusters)
        for (final cluster in clusterSkiRoutesByRegion(routes))
          _skiClusterMarker(
            context,
            cluster: cluster,
            label: cluster.label,
            zoomTarget: 10.5,
          )
      else if (currentZoom >= _minimumDataZoom && showSkiAreaClusters)
        for (final cluster in clusterSkiRoutesByArea(routes))
          _skiClusterMarker(
            context,
            cluster: cluster,
            label: cluster.label,
            zoomTarget: 12.8,
          )
      else if (currentZoom >= _minimumDataZoom)
        ...routes.map(
          (route) => Marker(
            point: route.location,
            width: 160,
            height: 52,
            child: Tooltip(
              message: route.name,
              child: GestureDetector(
                onTap: () => _selectSkiRoute(context, route),
                child: _LabeledMapMarker(
                  label: route.name,
                  icon: Icons.downhill_skiing,
                  selected: activeRoute?.id == route.id,
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Marker _skiClusterMarker(
    BuildContext context, {
    required _SkiRouteCluster cluster,
    required String label,
    required double zoomTarget,
  }) {
    final count = cluster.routes.length;
    final markerSize = count > 99
        ? 70.0
        : count > 9
        ? 62.0
        : 54.0;

    return Marker(
      point: cluster.point,
      width: markerSize + 76,
      height: markerSize + 32,
      child: Tooltip(
        message: '$label · $count ski tours',
        child: GestureDetector(
          onTap: () => mapController.move(cluster.point, zoomTarget),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 5,
                      color: Color(0x55000000),
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: markerSize,
                  height: markerSize,
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Polyline> _skiLines(
    MapPathCatalog mapPaths,
    List<SkiRoute> routes,
    SkiRoute? activeRoute,
  ) {
    return [
      for (final route in routes.where((route) => route.id != activeRoute?.id))
        ..._skiRouteLines(mapPaths, route, false),
      if (activeRoute != null) ..._skiRouteLines(mapPaths, activeRoute, true),
    ];
  }

  List<Polyline> _skiRouteLines(
    MapPathCatalog mapPaths,
    SkiRoute route,
    bool selected,
  ) {
    final ascent = _skiAscentPoints(route, mapPaths);
    final descent = _skiDescentPoints(route, mapPaths);
    return [
      if (selected) ...[
        Polyline(points: ascent, color: Colors.white, strokeWidth: 12),
        Polyline(points: descent, color: Colors.white, strokeWidth: 9),
      ],
      Polyline(
        points: ascent,
        color: selected
            ? const Color(0xFFB6FF2E)
            : _PathDraftKind.skiAscent.color,
        strokeWidth: selected ? 8 : 7,
      ),
      Polyline(
        points: descent,
        color: selected
            ? const Color(0xFF38BDF8)
            : _PathDraftKind.skiDescent.color,
        strokeWidth: selected ? 5 : 4,
      ),
    ];
  }

  List<LatLng> _skiAscentPoints(SkiRoute route, MapPathCatalog mapPaths) {
    final saved = mapPaths.skiAscent(route.name);
    return saved.length >= 2 ? saved : [route.trailhead, route.location];
  }

  List<LatLng> _skiDescentPoints(SkiRoute route, MapPathCatalog mapPaths) {
    final saved = mapPaths.skiDescent(route.name);
    return saved.length >= 2 ? saved : [route.location, route.trailhead];
  }

  List<Polyline> _approachLines(MapPathCatalog mapPaths) {
    final crag = selectedCrag;
    if (crag == null) return [];

    final destination = selectedWall?.location ?? crag.location;
    final savedPath = mapPaths.cragPath(crag.id);

    return [
      Polyline(
        points: savedPath.length >= 2 ? savedPath : [crag.parking, destination],
        color: Colors.orange,
        strokeWidth: 5,
      ),
    ];
  }

  void _selectCrag(BuildContext context, bool wide, Crag crag) {
    setState(() {
      selectedCrag = crag;
      selectedWall = crag.walls.isEmpty ? null : crag.walls.first;
      selectedSkiRoute = null;
      selectedSkiRouteId = null;
    });
    ref.read(focusedRouteProvider.notifier).state = null;
    ref.read(focusedSkiRouteProvider.notifier).state = null;

    if (wide) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        var sheetWall = crag.walls.isEmpty ? null : crag.walls.first;
        return StatefulBuilder(
          builder: (context, setSheetState) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.82,
            minChildSize: 0.45,
            maxChildSize: 0.96,
            builder: (context, scrollController) => CragSidebar(
              crag: crag,
              selectedWall: sheetWall,
              scrollController: scrollController,
              onWallSelected: (wall) {
                setSheetState(() => sheetWall = wall);
                setState(() => selectedWall = wall);
              },
              onRouteSelected: (route) {
                Navigator.pop(sheetContext);
                _openRouteInFeed(route);
              },
            ),
          ),
        );
      },
    );
  }

  void _selectSkiRoute(BuildContext context, SkiRoute route) {
    setState(() {
      selectedSkiRoute = route;
      selectedSkiRouteId = route.id;
      selectedCrag = null;
      selectedWall = null;
    });
    ref.read(focusedSkiRouteProvider.notifier).state = route;
    ref.read(focusedRouteProvider.notifier).state = null;
    if (editMode) {
      _showMapMessage('${route.name} selected for ski line editing');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SkiRouteMapSheet(route: route),
    );
  }

  void _handleMapTap(LatLng point) {
    if (pathEditMode) {
      setState(() {
        final selectedIndex = selectedPathPointIndex;
        if (selectedIndex != null && selectedIndex < pathDraft.length) {
          pathDraft[selectedIndex] = point;
          selectedPathPointIndex = null;
        } else {
          pathDraft.add(point);
        }
      });
      return;
    }

    setState(() {
      selectedCrag = null;
      selectedWall = null;
      selectedParkingCrag = null;
      selectedSkiRoute = null;
      selectedSkiRouteId = null;
    });
    ref.read(focusedRouteProvider.notifier).state = null;
    ref.read(focusedSkiRouteProvider.notifier).state = null;
  }

  void _scheduleFocusedRouteSelection({
    required ClimbRoute? focusedClimbRoute,
    required SkiRoute? focusedSkiRoute,
    required List<Crag> catalogCrags,
  }) {
    if (focusedClimbRoute == null) appliedFocusedClimbRouteId = null;
    if (focusedSkiRoute == null) appliedFocusedSkiRouteId = null;

    if (focusedClimbRoute != null &&
        focusedClimbRoute.id != appliedFocusedClimbRouteId) {
      appliedFocusedClimbRouteId = focusedClimbRoute.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyFocusedClimbRoute(focusedClimbRoute, catalogCrags);
      });
    }

    if (focusedSkiRoute != null &&
        focusedSkiRoute.id != appliedFocusedSkiRouteId) {
      appliedFocusedSkiRouteId = focusedSkiRoute.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyFocusedSkiRoute(focusedSkiRoute);
      });
    }
  }

  void _applyFocusedClimbRoute(ClimbRoute route, List<Crag> catalogCrags) {
    for (final crag in catalogCrags) {
      for (final wall in crag.walls) {
        if (!wall.routes.any((candidate) => candidate.id == route.id)) {
          continue;
        }
        final target = route.location ?? wall.location;
        setState(() {
          selectedCrag = crag;
          selectedWall = wall;
          selectedParkingCrag = null;
          selectedSkiRoute = null;
          selectedSkiRouteId = null;
        });
        _moveMap(target, 14);
        return;
      }
    }
    appliedFocusedClimbRouteId = null;
  }

  void _applyFocusedSkiRoute(SkiRoute route) {
    setState(() {
      selectedSkiRoute = route;
      selectedSkiRouteId = route.id;
      selectedCrag = null;
      selectedWall = null;
      selectedParkingCrag = null;
    });
    _moveMap(route.location, 13);
  }

  void _moveMap(LatLng target, double zoom) {
    currentMapCenter = target;
    currentZoom = zoom;
    final controller = mapLibreController;
    if (controller != null) {
      controller.moveCamera(
        ml.CameraUpdate.newLatLngZoom(
          ml.LatLng(target.latitude, target.longitude),
          zoom,
        ),
      );
    } else {
      mapController.move(target, zoom);
    }
  }

  void _startPathEditor(
    _PathDraftKind kind,
    MapPathCatalog mapPaths, [
    SkiRoute? activeSkiRoute,
  ]) {
    if (kind == _PathDraftKind.cragApproach) {
      final crag = selectedCrag;
      if (crag == null) {
        _showMapMessage('Select a crag before tracing its approach');
        return;
      }
      final saved = mapPaths.cragPath(crag.id);
      final destination = selectedWall?.location ?? crag.location;
      setState(() {
        pathDraftColorValue = _nextTraceColor();
        pathDraftKind = kind;
        pathDraft = saved.length >= 2
            ? [...saved]
            : [crag.parking, destination];
        pathEditMode = true;
        selectedPathPointIndex = null;
      });
      return;
    }

    final route = activeSkiRoute ?? selectedSkiRoute;
    if (route == null) {
      _showMapMessage('Select a ski route before tracing its line');
      return;
    }
    final saved = kind == _PathDraftKind.skiAscent
        ? mapPaths.skiAscent(route.name)
        : mapPaths.skiDescent(route.name);
    setState(() {
      pathDraftColorValue = _nextTraceColor();
      selectedSkiRoute = route;
      selectedSkiRouteId = route.id;
      pathDraftKind = kind;
      pathDraft = saved.length >= 2
          ? [...saved]
          : kind == _PathDraftKind.skiAscent
          ? [route.trailhead, route.location]
          : [route.location, route.trailhead];
      pathEditMode = true;
      selectedPathPointIndex = null;
    });
  }

  void _startNewSkiRoutePath() {
    final center = currentMapCenter ?? userLocation;
    setState(() {
      pathDraftColorValue = _nextTraceColor();
      selectedSkiRoute = null;
      selectedSkiRouteId = null;
      selectedCrag = null;
      selectedWall = null;
      selectedParkingCrag = null;
      pathDraftKind = _PathDraftKind.skiAscent;
      pathDraft = center == null ? [] : [center];
      pathEditMode = true;
      selectedPathPointIndex = null;
    });
    _showMapMessage('Tap the ski map to draw the ascent line.');
  }

  void _startRegionBoundaryEditor(OfflineBcRegion region) {
    setState(() {
      pathDraftColorValue = _nextTraceColor();
      selectedCrag = null;
      selectedWall = null;
      selectedSkiRoute = null;
      selectedSkiRouteId = null;
      selectedParkingCrag = null;
      editingOfflineRegion = region;
      pathDraftKind = _PathDraftKind.regionBoundary;
      pathDraft = [...region.polygons.first];
      pathEditMode = true;
      selectedPathPointIndex = null;
      currentMapCenter = region.center;
      currentZoom = 6.5;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !pathEditMode) return;
      try {
        mapController.move(region.center, 6.5);
      } on Object {
        // The editor still opens at the saved center after a map-engine swap.
      }
    });
    _showMapMessage(
      'Editing ${region.name}. Tap to add points or select a numbered point to move it.',
    );
  }

  List<Marker> _pathEditorMarkers() {
    if (!pathEditMode) return const [];
    final pathColor = Color(pathDraftColorValue);

    return [
      for (var index = 0; index < pathDraft.length; index++)
        Marker(
          point: pathDraft[index],
          width: 34,
          height: 34,
          child: Tooltip(
            message: 'Point ${index + 1}',
            child: GestureDetector(
              onTap: () => setState(() {
                selectedPathPointIndex = selectedPathPointIndex == index
                    ? null
                    : index;
              }),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selectedPathPointIndex == index
                      ? pathColor
                      : const Color(0xFFFFFFFF),
                  shape: BoxShape.circle,
                  border: Border.all(color: pathColor, width: 3),
                  boxShadow: const [
                    BoxShadow(blurRadius: 4, color: Color(0x55000000)),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: selectedPathPointIndex == index
                          ? Colors.white
                          : const Color(0xFF1E2823),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  int _nextTraceColor() {
    final libraryCount = ref.read(trailLibraryProvider).trails.length;
    final color = savedTrailColorFor(libraryCount + traceColorIndex);
    traceColorIndex += 1;
    return color;
  }

  void _undoPathPoint() {
    if (pathDraft.isEmpty) return;
    setState(() {
      pathDraft.removeLast();
      selectedPathPointIndex = null;
    });
  }

  void _deleteSelectedPathPoint() {
    final index = selectedPathPointIndex;
    if (index == null || index >= pathDraft.length) return;
    setState(() {
      pathDraft.removeAt(index);
      selectedPathPointIndex = null;
    });
  }

  void _clearPath() {
    setState(() {
      pathDraft.clear();
      selectedPathPointIndex = null;
    });
  }

  void _cancelPathEditor() {
    setState(() {
      pathEditMode = false;
      pathDraftKind = null;
      pathDraft = [];
      selectedPathPointIndex = null;
      editingOfflineRegion = null;
    });
  }

  Future<void> _savePath() async {
    if (pathDraft.length < 2) return;
    final kind = pathDraftKind;
    final points = [...pathDraft];

    try {
      if (kind == _PathDraftKind.regionBoundary) {
        final region = editingOfflineRegion;
        if (region == null || points.length < 3) return;
        await const DatabaseService().updateOfflineRegionPolygons(
          regionId: region.id,
          polygons: [points, ...region.polygons.skip(1)],
        );
        ref.invalidate(offlineRegionCatalogProvider);
        _cancelPathEditor();
        _showMapMessage('${region.name} download boundary saved');
        return;
      } else if (kind == _PathDraftKind.cragApproach) {
        final crag = selectedCrag;
        if (crag == null) return;
        await const DatabaseService().updateCragApproachPath(
          cragId: crag.id,
          points: points,
        );
      } else {
        final route = selectedSkiRoute;
        if (route == null && kind == _PathDraftKind.skiAscent) {
          await _createSkiRouteFromPath(points);
          return;
        }
        if (route == null) return;
        await const DatabaseService().updateSkiRoutePath(
          routeName: route.name,
          segmentKind: kind == _PathDraftKind.skiDescent ? 'descent' : 'ascent',
          points: points,
        );
      }

      ref.invalidate(mapPathCatalogProvider);
      _cancelPathEditor();
      _showMapMessage('Trail saved with points spaced every 10 feet');
    } on Object catch (error) {
      _showMapMessage('Could not save trail: $error');
    }
  }

  Future<void> _createSkiRouteFromPath(List<LatLng> points) async {
    final draft = await showModalBottomSheet<_SkiRouteDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _NewSkiRouteSheet(
        distanceKm: _pathLength(points) / 1000,
        trailhead: points.first,
        highPoint: points.last,
      ),
    );
    if (draft == null || !mounted) return;

    final service = const DatabaseService();
    final route = await service.adminSaveSkiRoute(
      values: {
        'route_name': draft.name,
        'route_area': draft.area,
        'route_region': draft.region,
        'route_difficulty': draft.difficulty,
        'route_distance_km': draft.distanceKm,
        'route_elevation_gain_meters': draft.elevationGainMeters,
        'route_max_slope_angle_degrees': draft.maxSlopeAngleDegrees,
        'route_aspect': draft.aspect,
        'route_avalanche_terrain': draft.avalancheTerrain,
        'route_season': draft.season,
        'route_lat': points.last.latitude,
        'route_lng': points.last.longitude,
        'route_trailhead_lat': points.first.latitude,
        'route_trailhead_lng': points.first.longitude,
        'route_description': draft.description,
        'route_approach_notes': draft.approachNotes,
        'route_descent_notes': draft.descentNotes,
        'route_danger_info': draft.dangerInfo,
        'route_image_url': draft.imageUrl,
      },
      ascentPoints: points,
    );

    ref.invalidate(skiRouteCatalogProvider);
    ref.invalidate(mapPathCatalogProvider);
    _cancelPathEditor();
    setState(() {
      selectedSkiRoute = route;
      selectedSkiRouteId = route.id;
    });
    _showMapMessage('${route.name} added to the ski map');
  }

  double _pathLength(List<LatLng> points) {
    if (points.length < 2) return 0;
    const distance = Distance();
    var total = 0.0;
    for (var index = 1; index < points.length; index++) {
      total += distance.as(LengthUnit.Meter, points[index - 1], points[index]);
    }
    return total;
  }

  _VerticalMeters _verticalMeters(List<_RecordedTrackPoint> points) {
    if (points.length < 2) return const _VerticalMeters();
    var ascent = 0.0;
    var descent = 0.0;
    double? previousAltitude;

    for (final point in points) {
      final altitude = point.altitudeMeters;
      if (altitude == null) continue;
      if (previousAltitude != null) {
        final delta = altitude - previousAltitude;
        // Ignore tiny GPS altitude jitter so the totals don't creep upward while
        // someone is standing still at the trailhead.
        if (delta.abs() >= 1.5) {
          if (delta > 0) {
            ascent += delta;
          } else {
            descent += delta.abs();
          }
        }
      }
      previousAltitude = altitude;
    }

    return _VerticalMeters(ascent: ascent, descent: descent);
  }

  void _startRecording() {
    if (userLocation == null) {
      _showMapMessage('Waiting for a GPS location');
      return;
    }

    final now = DateTime.now();
    final colorValue = _nextTraceColor();
    setState(() {
      recordedPathKind = _PathDraftKind.cragApproach;
      recordedColorValue = colorValue;
      recordingStartedAt = now;
      recordingElapsed = Duration.zero;
      recordedTrack = [
        _RecordedTrackPoint(
          location: userLocation!,
          altitudeMeters: userAltitudeMeters,
          recordedAt: now,
        ),
      ];
      gpsRecording = true;
    });
    unawaited(_persistRecordedDraft());
    recordingTimer?.cancel();
    recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !gpsRecording || recordingStartedAt == null) return;
      setState(() {
        recordingElapsed = DateTime.now().difference(recordingStartedAt!);
      });
    });
    _showMapMessage('Recording started.');
  }

  void _stopGpsRecording() {
    recordingTimer?.cancel();
    setState(() => gpsRecording = false);
    unawaited(_persistRecordedDraft());
    _showMapMessage('Recording stopped. Review the line, then save it.');
  }

  void _discardGpsRecording() {
    recordingTimer?.cancel();
    setState(() {
      gpsRecording = false;
      recordedPathKind = null;
      recordingStartedAt = null;
      recordingElapsed = Duration.zero;
      recordedTrack = [];
    });
    unawaited(_clearRecordedDraft());
  }

  Future<void> _saveGpsRecording() async {
    if (recordedPathKind == null || recordedPath.length < 2) {
      _showMapMessage('Record a longer trail before saving');
      return;
    }
    final now = DateTime.now();
    final defaultName = 'Trail ${now.month}/${now.day}/${now.year}';
    final controller = TextEditingController(text: defaultName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save trail to your Library'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Trail name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save to Library'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;

    final vertical = _verticalMeters(recordedTrack);
    await ref
        .read(trailLibraryProvider)
        .add(
          SavedTrail(
            id: now.microsecondsSinceEpoch.toString(),
            name: name,
            createdAt: now,
            points: [...recordedPath],
            distanceMeters: _pathLength(recordedPath),
            ascentMeters: vertical.ascent,
            descentMeters: vertical.descent,
            durationSeconds: recordingElapsed.inSeconds,
            colorValue: recordedColorValue,
          ),
        );
    _discardGpsRecording();
    _showMapMessage('Trail saved to your Library');
  }

  Future<void> _restoreRecordedDraft() async {
    final store = await SharedPreferences.getInstance();
    final raw = store.getString(_recordingDraftKey);
    if (raw == null || raw.isEmpty || !mounted) return;
    try {
      final json = Map<String, Object?>.from(jsonDecode(raw) as Map);
      final points = (json['points'] as List? ?? const [])
          .whereType<Map>()
          .map((item) {
            final point = Map<String, Object?>.from(item);
            final time = DateTime.tryParse(
              point['recordedAt']?.toString() ?? '',
            );
            if (time == null) return null;
            return _RecordedTrackPoint(
              location: LatLng(
                (point['lat'] as num).toDouble(),
                (point['lng'] as num).toDouble(),
              ),
              altitudeMeters: (point['altitude'] as num?)?.toDouble(),
              recordedAt: time,
            );
          })
          .whereType<_RecordedTrackPoint>()
          .toList(growable: false);
      final kindName = json['kind']?.toString();
      final kind = _PathDraftKind.values.where((item) => item.name == kindName);
      if (points.isEmpty || kind.isEmpty) return;
      if (!mounted) return;
      setState(() {
        recordedTrack = points;
        recordedPathKind = kind.first;
        recordedColorValue =
            (json['colorValue'] as num?)?.toInt() ?? savedTrailColors.first;
        recordingStartedAt = points.first.recordedAt;
        recordingElapsed = points.last.recordedAt.difference(
          points.first.recordedAt,
        );
        gpsRecording = false;
      });
    } catch (_) {
      await store.remove(_recordingDraftKey);
    }
  }

  Future<void> _persistRecordedDraft() async {
    if (recordedTrack.isEmpty || recordedPathKind == null) return;
    final store = await SharedPreferences.getInstance();
    await store.setString(
      _recordingDraftKey,
      jsonEncode({
        'kind': recordedPathKind!.name,
        'colorValue': recordedColorValue,
        'points': [
          for (final point in recordedTrack)
            {
              'lat': point.location.latitude,
              'lng': point.location.longitude,
              'altitude': point.altitudeMeters,
              'recordedAt': point.recordedAt.toIso8601String(),
            },
        ],
      }),
    );
  }

  Future<void> _clearRecordedDraft() async {
    final store = await SharedPreferences.getInstance();
    await store.remove(_recordingDraftKey);
  }

  void _showMapMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setMapHeading(double degrees) {
    final normalized = degrees % 360;
    final heading = normalized < 0 ? normalized + 360 : normalized;
    if (_usesMapLibre(tileStyle)) {
      final controller = mapLibreController;
      final position = controller?.cameraPosition;
      if (controller != null && position != null) {
        unawaited(
          controller.moveCamera(
            ml.CameraUpdate.newCameraPosition(
              ml.CameraPosition(
                target: position.target,
                zoom: position.zoom,
                tilt: position.tilt,
                bearing: heading,
              ),
            ),
          ),
        );
      }
    } else {
      mapController.rotate(heading);
    }
    setState(() => currentMapRotation = heading);
  }

  String? _mapLibreStyleFor(_MapTileStyle style) {
    final value = switch (style) {
      _MapTileStyle.clean => OfflineMapConfig.cleanStyleUrl,
      _MapTileStyle.satellite => OfflineMapConfig.satelliteStyleUrl,
      _MapTileStyle.terrain3d => OfflineMapConfig.terrain3dStyleUrl,
    };
    return value.isEmpty ? null : value;
  }

  bool _usesMapLibre(_MapTileStyle style) {
    return _supportsMapLibre &&
        (style == _MapTileStyle.terrain3d ||
            (!kIsWeb && _mapLibreStyleFor(style) != null));
  }

  bool get _supportsMapLibre {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool _shouldShowParking(Crag crag) {
    if (selectedCrag == crag) return true;
    final location = userLocation;
    if (location == null) return false;

    const distance = Distance();
    return distance.as(LengthUnit.Meter, location, crag.parking) <= 800;
  }

  void _openRouteInFeed(ClimbRoute route) {
    ref.read(focusedRouteProvider.notifier).state = route;
    context.go('/feed');
  }

  void _toggleFilter(_MapRouteFilter filter) {
    setState(() {
      if (activeFilters.contains(filter)) {
        activeFilters.remove(filter);
      } else {
        activeFilters.add(filter);
      }

      if (selectedCrag != null) {
        selectedCrag = null;
        selectedWall = null;
        selectedParkingCrag = null;
      }
    });
  }

  bool _routeMatchesFilters(ClimbRoute route) {
    if (activeFilters.isEmpty) return true;

    final typeFilters = activeFilters.where((filter) {
      return filter == _MapRouteFilter.trad ||
          filter == _MapRouteFilter.sport ||
          filter == _MapRouteFilter.deepWaterSolo ||
          filter == _MapRouteFilter.aid;
    }).toSet();
    final pitchFilters = activeFilters.difference(typeFilters);

    final matchesType =
        typeFilters.isEmpty ||
        typeFilters.any((filter) {
          return switch (filter) {
            _MapRouteFilter.trad => route.type == ClimbRouteType.trad,
            _MapRouteFilter.sport => route.type == ClimbRouteType.sport,
            _MapRouteFilter.deepWaterSolo =>
              route.type == ClimbRouteType.deepWaterSolo,
            _MapRouteFilter.aid => route.type == ClimbRouteType.aid,
            _ => false,
          };
        });

    final matchesPitch =
        pitchFilters.isEmpty ||
        pitchFilters.any((filter) {
          return switch (filter) {
            _MapRouteFilter.boulder => route.pitchType == PitchType.boulder,
            _MapRouteFilter.multiPitch =>
              route.pitchType == PitchType.multiPitch,
            _MapRouteFilter.singlePitch =>
              route.pitchType == PitchType.singlePitch,
            _ => false,
          };
        });

    return matchesType && matchesPitch;
  }

  String _parkingCoordinates(Crag crag) {
    return '${crag.parking.latitude.toStringAsFixed(6)}, ${crag.parking.longitude.toStringAsFixed(6)}';
  }

  Future<void> _copyParkingCoordinates(Crag crag) async {
    await Clipboard.setData(ClipboardData(text: _parkingCoordinates(crag)));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Parking GPS copied')));
  }

  Future<void> _shareParkingCoordinates(Crag crag) async {
    final coordinates = _parkingCoordinates(crag);
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${crag.name} parking\n$coordinates\nhttps://www.google.com/maps/search/?api=1&query=$coordinates',
      ),
    );
  }

  Future<void> _openParkingInMaps(Crag crag) async {
    final coordinates = _parkingCoordinates(crag);
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$coordinates',
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openCoordinateEditor() async {
    final crag = selectedCrag;
    if (crag == null) return;

    final target = await showModalBottomSheet<_CoordinateEditTarget>(
      context: context,
      showDragHandle: true,
      builder: (context) => _CoordinateEditorSheet(
        crag: crag,
        selectedWall: selectedWall,
        mapCenter: currentMapCenter ?? crag.location,
      ),
    );
    if (target == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (target.kind) {
        case _CoordinateEditKind.crag:
          await const DatabaseService().updateCragLocation(
            cragId: crag.id,
            latitude: target.point.latitude,
            longitude: target.point.longitude,
          );
        case _CoordinateEditKind.parking:
          await const DatabaseService().updateCragParkingLocation(
            cragId: crag.id,
            latitude: target.point.latitude,
            longitude: target.point.longitude,
          );
        case _CoordinateEditKind.wallRoutes:
          final wall = selectedWall;
          if (wall == null) return;
          await const DatabaseService().updateWallRouteLocations(
            wallId: wall.id,
            latitude: target.point.latitude,
            longitude: target.point.longitude,
          );
        case _CoordinateEditKind.route:
          final route = target.route;
          if (route == null) return;
          await const DatabaseService().updateRouteLocation(
            routeId: route.id,
            latitude: target.point.latitude,
            longitude: target.point.longitude,
          );
      }

      if (!mounted) return;
      ref.invalidate(catalogProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Map point saved to Supabase')),
      );
    } on Object catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $error')));
    }
  }
}

class _Terrain3DMap extends StatefulWidget {
  const _Terrain3DMap({
    required this.styleOverride,
    required this.enableTerrain,
    required this.center,
    required this.zoom,
    required this.mode,
    required this.crags,
    required this.skiRoutes,
    required this.paths,
    required this.savedTrails,
    required this.recordedPath,
    required this.recordedColorValue,
    required this.regions,
    required this.selectedCrag,
    required this.selectedSkiRoute,
    required this.userLocation,
    required this.onCragTap,
    required this.onSkiRouteTap,
    required this.onControllerReady,
    required this.allowRotation,
  });

  final String? styleOverride;
  final bool enableTerrain;
  final LatLng center;
  final double zoom;
  final ActivityMode mode;
  final List<Crag> crags;
  final List<SkiRoute> skiRoutes;
  final MapPathCatalog paths;
  final List<SavedTrail> savedTrails;
  final List<LatLng> recordedPath;
  final int recordedColorValue;
  final List<OfflineBcRegion> regions;
  final Crag? selectedCrag;
  final SkiRoute? selectedSkiRoute;
  final LatLng? userLocation;
  final ValueChanged<Crag> onCragTap;
  final ValueChanged<SkiRoute> onSkiRouteTap;
  final ValueChanged<ml.MapLibreMapController> onControllerReady;
  final bool allowRotation;

  @override
  State<_Terrain3DMap> createState() => _Terrain3DMapState();
}

class _Terrain3DMapState extends State<_Terrain3DMap> {
  ml.MapLibreMapController? controller;
  bool styleLoaded = false;

  static final style = jsonEncode({
    'version': 8,
    'name': 'Climb On Satellite Terrain',
    'sources': {
      'satellite': {
        'type': 'raster',
        'tiles': [
          'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        ],
        'tileSize': 256,
        'maxzoom': 19,
        'attribution': 'Imagery © Esri and data providers',
      },
      'labels': {
        'type': 'raster',
        'tiles': [
          'https://a.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}@2x.png',
          'https://b.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}@2x.png',
          'https://c.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}@2x.png',
          'https://d.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}@2x.png',
        ],
        'tileSize': 512,
        'maxzoom': 20,
        'attribution': '© OpenStreetMap contributors © CARTO',
      },
      'terrain': {
        'type': 'raster-dem',
        'url': 'https://tiles.mapterhorn.com/tilejson.json',
        'tileSize': 256,
        'attribution': 'Terrain © MapTiler and OpenStreetMap contributors',
      },
    },
    'terrain': {'source': 'terrain', 'exaggeration': 1.12},
    'layers': [
      {
        'id': 'satellite',
        'type': 'raster',
        'source': 'satellite',
        'paint': {'raster-saturation': -0.05, 'raster-contrast': 0.08},
      },
      {
        'id': 'terrain-hillshade',
        'type': 'hillshade',
        'source': 'terrain',
        'paint': {
          'hillshade-exaggeration': 0.28,
          'hillshade-shadow-color': '#23342f',
          'hillshade-highlight-color': '#ffffff',
          'hillshade-accent-color': '#60776d',
        },
      },
      {'id': 'labels', 'type': 'raster', 'source': 'labels'},
    ],
  });

  @override
  void didUpdateWidget(covariant _Terrain3DMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      final target = widget.mode == ActivityMode.ski
          ? (widget.skiRoutes.isEmpty ? null : widget.skiRoutes.first.location)
          : widget.selectedCrag?.location ??
                (widget.crags.isEmpty ? null : widget.crags.first.location);
      if (target != null) {
        unawaited(
          controller?.animateCamera(
            ml.CameraUpdate.newCameraPosition(
              ml.CameraPosition(
                target: _point(target),
                zoom: 10.5,
                tilt: 62,
                bearing: 18,
              ),
            ),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      }
    }
    if (styleLoaded &&
        (oldWidget.mode != widget.mode ||
            oldWidget.paths != widget.paths ||
            oldWidget.savedTrails != widget.savedTrails ||
            oldWidget.recordedPath != widget.recordedPath ||
            oldWidget.regions != widget.regions ||
            oldWidget.selectedCrag != widget.selectedCrag ||
            oldWidget.selectedSkiRoute != widget.selectedSkiRoute)) {
      unawaited(_drawAnnotations());
    }
  }

  @override
  void dispose() {
    controller?.onSymbolTapped.remove(_handleSymbolTap);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ml.MapLibreMap(
      styleString: widget.styleOverride ?? style,
      initialCameraPosition: ml.CameraPosition(
        target: ml.LatLng(widget.center.latitude, widget.center.longitude),
        zoom: widget.zoom.clamp(8, 17),
        tilt: widget.enableTerrain ? 62 : 0,
        bearing: widget.enableTerrain ? 18 : 0,
      ),
      cameraTargetBounds: ml.CameraTargetBounds(
        ml.LatLngBounds(
          southwest: ml.LatLng(bcMapBounds.south, bcMapBounds.west),
          northeast: ml.LatLng(bcMapBounds.north, bcMapBounds.east),
        ),
      ),
      minMaxZoomPreference: const ml.MinMaxZoomPreference(5, 19),
      rotateGesturesEnabled: widget.allowRotation,
      tiltGesturesEnabled: widget.enableTerrain && widget.allowRotation,
      compassEnabled: true,
      scaleControlEnabled: true,
      onMapCreated: (value) {
        controller = value;
        widget.onControllerReady(value);
        value.onSymbolTapped.add(_handleSymbolTap);
      },
      onStyleLoadedCallback: () {
        styleLoaded = true;
        unawaited(_drawAnnotations());
      },
      onCameraIdle: () => unawaited(_drawAnnotations()),
    );
  }

  Future<void> _drawAnnotations() async {
    final map = controller;
    if (map == null || !styleLoaded) return;

    try {
      await map.clearLines();
      await map.clearCircles();
      await map.clearFills();
      await map.clearSymbols();

      final lines = <ml.LineOptions>[];
      final circles = <ml.CircleOptions>[];
      final fills = <ml.FillOptions>[];
      final symbols = <ml.SymbolOptions>[];
      final symbolData = <Map<String, dynamic>>[];
      final zoom = map.cameraPosition?.zoom ?? widget.zoom;
      final showMapData = zoom >= _MapScreenState._minimumDataZoom;
      if (zoom < 9) {
        for (final region in widget.regions) {
          final color =
              '#${(region.colorValue & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
          for (final boundary in region.polygons) {
            final geometry = boundary.map(_point).toList(growable: false);
            fills.add(
              ml.FillOptions(
                geometry: [geometry],
                fillColor: color,
                fillOpacity: 0.18,
                fillOutlineColor: color,
              ),
            );
            lines.add(
              ml.LineOptions(
                geometry: geometry,
                lineColor: color,
                lineWidth: 2.5,
                lineOpacity: 0.9,
              ),
            );
          }
          symbols.add(
            ml.SymbolOptions(
              geometry: _point(region.center),
              textField: region.name,
              textSize: 13,
              textColor: '#FFFFFF',
              textHaloColor: '#174A6A',
              textHaloWidth: 3,
              textAnchor: 'center',
              textMaxWidth: 14,
            ),
          );
          symbolData.add({'kind': 'offline-region', 'entityId': region.id});
        }
      }
      if (showMapData && widget.mode == ActivityMode.ski) {
        for (final route in widget.skiRoutes) {
          final ascent = widget.paths.skiAscent(route.name);
          final ascentPoints = ascent.length >= 2
              ? ascent
              : [route.trailhead, route.location];
          final descent = widget.paths.skiDescent(route.name);
          final descentPoints = descent.length >= 2
              ? descent
              : [route.location, route.trailhead];
          lines.add(
            ml.LineOptions(
              geometry: ascentPoints.map(_point).toList(growable: false),
              lineColor: '#D33B2F',
              lineWidth: 7,
              lineOpacity: 0.92,
            ),
          );
          lines.add(
            ml.LineOptions(
              geometry: descentPoints.map(_point).toList(growable: false),
              lineColor: '#F28C28',
              lineWidth: 4,
              lineOpacity: 0.96,
            ),
          );
          symbols.add(
            _labelSymbol(
              route.name,
              route.location,
              selected: route == widget.selectedSkiRoute,
            ),
          );
          symbolData.add({'kind': 'ski', 'entityId': route.id});
        }
      } else if (showMapData) {
        for (final crag in widget.crags) {
          symbols.add(
            _labelSymbol(
              crag.name,
              crag.location,
              selected: crag == widget.selectedCrag,
            ),
          );
          symbolData.add({'kind': 'crag', 'entityId': crag.id});
        }

        final selected = widget.selectedCrag;
        if (selected != null) {
          final saved = widget.paths.cragPath(selected.id);
          final points = saved.length >= 2
              ? saved
              : [selected.parking, selected.location];
          lines.add(
            ml.LineOptions(
              geometry: points.map(_point).toList(growable: false),
              lineColor: '#FFD166',
              lineWidth: 5,
              lineOpacity: 0.95,
            ),
          );
        }
      }

      for (final trail in widget.savedTrails) {
        lines.add(
          ml.LineOptions(
            geometry: trail.points.map(_point).toList(growable: false),
            lineColor: _hexColor(trail.colorValue),
            lineWidth: 5,
            lineOpacity: 0.96,
          ),
        );
      }
      if (widget.recordedPath.length >= 2) {
        lines.add(
          ml.LineOptions(
            geometry: widget.recordedPath.map(_point).toList(growable: false),
            lineColor: _hexColor(widget.recordedColorValue),
            lineWidth: 6,
            lineOpacity: 1,
          ),
        );
      }

      final location = widget.userLocation;
      if (location != null) {
        circles.add(
          ml.CircleOptions(
            geometry: _point(location),
            circleRadius: 7,
            circleColor: '#42A5F5',
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 3,
          ),
        );
      }

      if (fills.isNotEmpty) await map.addFills(fills);
      if (lines.isNotEmpty) await map.addLines(lines);
      if (circles.isNotEmpty) await map.addCircles(circles);
      if (symbols.isNotEmpty) await map.addSymbols(symbols, symbolData);
    } on Object {
      // Keep terrain navigation available if an annotation cannot be rendered.
    }
  }

  ml.LatLng _point(LatLng point) {
    return ml.LatLng(point.latitude, point.longitude);
  }

  String _hexColor(int value) {
    return '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  ml.SymbolOptions _labelSymbol(
    String name,
    LatLng location, {
    required bool selected,
  }) {
    return ml.SymbolOptions(
      geometry: _point(location),
      textField: '●  $name',
      textSize: selected ? 15 : 13,
      textColor: selected ? '#FFD166' : '#FFFFFF',
      textHaloColor: '#17352E',
      textHaloWidth: selected ? 3 : 2,
      textRotate: controller?.cameraPosition?.bearing ?? 0,
      textAnchor: 'center',
      textMaxWidth: 16,
      zIndex: selected ? 2 : 1,
    );
  }

  void _handleSymbolTap(ml.Symbol symbol) {
    final data = symbol.data;
    final kind = data?['kind'];
    final id = data?['entityId'];
    if (kind == 'crag') {
      for (final crag in widget.crags) {
        if (crag.id == id) {
          widget.onCragTap(crag);
          return;
        }
      }
    }
    if (kind == 'ski') {
      for (final route in widget.skiRoutes) {
        if (route.id == id) {
          widget.onSkiRouteTap(route);
          return;
        }
      }
    }
    if (kind == 'offline-region') {
      for (final region in widget.regions) {
        if (region.id == id) {
          unawaited(
            controller?.animateCamera(
              ml.CameraUpdate.newCameraPosition(
                ml.CameraPosition(
                  target: _point(region.center),
                  zoom: 7.5,
                  tilt: widget.enableTerrain ? 45 : 0,
                ),
              ),
              duration: const Duration(milliseconds: 700),
            ),
          );
          return;
        }
      }
    }
  }
}

enum _MapRouteFilter {
  boulder,
  multiPitch,
  trad,
  sport,
  deepWaterSolo,
  aid,
  singlePitch;

  String get label => switch (this) {
    boulder => 'Boulder',
    multiPitch => 'Multipitch',
    trad => 'Trad',
    sport => 'Sport',
    deepWaterSolo => 'Deep Water Solo',
    aid => 'Aid',
    singlePitch => 'Single pitch',
  };
}

class _RecordedTrackPoint {
  const _RecordedTrackPoint({
    required this.location,
    required this.altitudeMeters,
    required this.recordedAt,
  });

  final LatLng location;
  final double? altitudeMeters;
  final DateTime recordedAt;
}

class _VerticalMeters {
  const _VerticalMeters({this.ascent = 0, this.descent = 0});

  final double ascent;
  final double descent;
}

enum _PathDraftKind {
  cragApproach,
  skiAscent,
  skiDescent,
  regionBoundary;

  Color get color => switch (this) {
    cragApproach => const Color(0xFFF28C28),
    skiAscent => const Color(0xFFD33B2F),
    skiDescent => const Color(0xFFF28C28),
    regionBoundary => const Color(0xFF1565C0),
  };
}

class _CragCluster {
  const _CragCluster({required this.point, required this.crags});

  final LatLng point;
  final List<Crag> crags;
}

class _SkiRouteCluster {
  const _SkiRouteCluster({
    required this.label,
    required this.point,
    required this.routes,
  });

  final String label;
  final LatLng point;
  final List<SkiRoute> routes;
}

enum _MapTileStyle {
  clean(
    label: 'Clean 2D',
    icon: Icons.map,
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
    subdomains: ['a', 'b', 'c', 'd'],
    attribution: '© OpenStreetMap contributors © CARTO',
  ),
  satellite(
    label: 'Satellite',
    icon: Icons.satellite_alt,
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    subdomains: [],
    attribution:
        'Tiles © Esri and data providers · Labels © OpenStreetMap contributors © CARTO',
  ),
  terrain3d(
    label: 'Satellite 3D',
    icon: Icons.view_in_ar,
    urlTemplate: '',
    subdomains: [],
    attribution: 'Imagery © Esri and data providers',
  );

  const _MapTileStyle({
    required this.label,
    required this.icon,
    required this.urlTemplate,
    required this.subdomains,
    required this.attribution,
  });

  final String label;
  final IconData icon;
  final String urlTemplate;
  final List<String> subdomains;
  final String attribution;
}

class _BcRegionLegend extends StatelessWidget {
  const _BcRegionLegend({required this.regions});

  final List<OfflineBcRegion> regions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            blurRadius: 5,
            color: Color(0x33000000),
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        width: 164,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BC regions',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              for (final region in regions)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 11,
                        height: 11,
                        margin: const EdgeInsets.only(top: 1, right: 6),
                        decoration: BoxDecoration(
                          color: Color(region.colorValue),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          region.name,
                          style: const TextStyle(
                            fontSize: 9.5,
                            height: 1.12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapFilters extends StatelessWidget {
  const _MapFilters({
    required this.activeFilters,
    required this.top,
    required this.alignLeft,
    required this.onToggle,
  });

  final Set<_MapRouteFilter> activeFilters;
  final double top;
  final bool alignLeft;
  final ValueChanged<_MapRouteFilter> onToggle;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: alignLeft ? 12 : null,
      right: alignLeft ? null : 12,
      top: top,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 3,
        borderRadius: BorderRadius.circular(8),
        child: PopupMenuButton<_MapRouteFilter>(
          tooltip: 'Climb filters',
          onSelected: onToggle,
          itemBuilder: (context) => [
            for (final filter in _MapRouteFilter.values)
              CheckedPopupMenuItem(
                value: filter,
                checked: activeFilters.contains(filter),
                child: Text(filter.label),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_alt_outlined, size: 19),
                const SizedBox(width: 7),
                Text(
                  activeFilters.isEmpty
                      ? 'Filters'
                      : 'Filters ${activeFilters.length}',
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapLayerSwitcher extends StatelessWidget {
  const _MapLayerSwitcher({
    required this.selected,
    required this.terrainAvailable,
    required this.onChanged,
    required this.onTerrainChanged,
  });

  final _MapTileStyle selected;
  final bool terrainAvailable;
  final ValueChanged<_MapTileStyle> onChanged;
  final ValueChanged<bool> onTerrainChanged;

  @override
  Widget build(BuildContext context) {
    final satelliteSelected =
        selected == _MapTileStyle.satellite ||
        selected == _MapTileStyle.terrain3d;
    final displayedStyle = selected == _MapTileStyle.terrain3d
        ? _MapTileStyle.satellite
        : selected;

    return Positioned(
      left: 12,
      top: 8,
      child: SafeArea(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 3,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<_MapTileStyle>(
                  tooltip: 'Map layer',
                  initialValue: displayedStyle,
                  onSelected: onChanged,
                  itemBuilder: (context) => [
                    for (final style in const [
                      _MapTileStyle.clean,
                      _MapTileStyle.satellite,
                    ])
                      PopupMenuItem(
                        value: style,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(style.icon),
                          title: Text(style.label),
                        ),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(displayedStyle.icon, size: 18),
                        const SizedBox(width: 8),
                        Text(displayedStyle.label),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                if (satelliteSelected) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: terrainAvailable
                        ? 'Show satellite over 3D Canadian terrain'
                        : '3D activates when Canadian terrain is connected',
                    child: FilterChip(
                      avatar: const Icon(Icons.view_in_ar, size: 17),
                      label: const Text('3D'),
                      selected: selected == _MapTileStyle.terrain3d,
                      onSelected: terrainAvailable ? onTerrainChanged : null,
                      showCheckmark: false,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminMapTools extends StatelessWidget {
  const _AdminMapTools({
    required this.isAdmin,
    required this.editMode,
    required this.selectedCrag,
    required this.selectedWall,
    required this.selectedSkiRoute,
    required this.mode,
    required this.mapCenter,
    required this.onToggleEditMode,
    required this.onEdit,
    required this.onTracePath,
    required this.onCreateSkiRoute,
    required this.regions,
    required this.editingRegion,
    required this.onEditRegion,
  });

  final bool isAdmin;
  final bool editMode;
  final Crag? selectedCrag;
  final Wall? selectedWall;
  final SkiRoute? selectedSkiRoute;
  final ActivityMode mode;
  final LatLng mapCenter;
  final VoidCallback onToggleEditMode;
  final VoidCallback onEdit;
  final ValueChanged<_PathDraftKind> onTracePath;
  final VoidCallback onCreateSkiRoute;
  final List<OfflineBcRegion> regions;
  final OfflineBcRegion? editingRegion;
  final ValueChanged<OfflineBcRegion> onEditRegion;

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const SizedBox.shrink();

    return Positioned(
      left: 12,
      bottom: 12,
      child: SafeArea(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  avatar: const Icon(Icons.admin_panel_settings, size: 18),
                  label: const Text('Edit map'),
                  selected: editMode,
                  onSelected: (_) => onToggleEditMode(),
                  showCheckmark: false,
                ),
                if (editMode) ...[
                  if (mode == ActivityMode.climb)
                    FilledButton.icon(
                      onPressed: selectedCrag == null ? null : onEdit,
                      icon: const Icon(Icons.my_location, size: 18),
                      label: Text(
                        selectedWall == null
                            ? 'Move selected'
                            : 'Move ${selectedWall!.name}',
                      ),
                    ),
                  if (mode == ActivityMode.climb)
                    OutlinedButton.icon(
                      onPressed: selectedCrag == null
                          ? null
                          : () => onTracePath(_PathDraftKind.cragApproach),
                      icon: const Icon(Icons.timeline, size: 18),
                      label: const Text('Trace approach'),
                    )
                  else ...[
                    FilledButton.icon(
                      onPressed: onCreateSkiRoute,
                      icon: const Icon(Icons.add_road, size: 18),
                      label: const Text('New ski route'),
                    ),
                    OutlinedButton.icon(
                      onPressed: selectedSkiRoute == null
                          ? null
                          : () => onTracePath(_PathDraftKind.skiAscent),
                      icon: const Icon(Icons.north_east, size: 18),
                      label: const Text('Edit ascent'),
                    ),
                    OutlinedButton.icon(
                      onPressed: selectedSkiRoute == null
                          ? null
                          : () => onTracePath(_PathDraftKind.skiDescent),
                      icon: const Icon(Icons.south_east, size: 18),
                      label: const Text('Edit descent'),
                    ),
                  ],
                  PopupMenuButton<OfflineBcRegion>(
                    tooltip: 'Edit download section boundary',
                    onSelected: onEditRegion,
                    itemBuilder: (context) => [
                      for (final region in regions)
                        PopupMenuItem(
                          value: region,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Color(region.colorValue),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(child: Text(region.name)),
                            ],
                          ),
                        ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.gesture, size: 18),
                          const SizedBox(width: 7),
                          Text(
                            editingRegion == null
                                ? 'Edit download section'
                                : editingRegion!.name,
                          ),
                          const Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '${mapCenter.latitude.toStringAsFixed(6)}, '
                    '${mapCenter.longitude.toStringAsFixed(6)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeadingControl extends StatelessWidget {
  const _HeadingControl({
    required this.headingDegrees,
    required this.onHeadingChanged,
    required this.onResetNorth,
  });

  final double headingDegrees;
  final ValueChanged<double> onHeadingChanged;
  final VoidCallback onResetNorth;

  double get signedHeading =>
      headingDegrees > 180 ? headingDegrees - 360 : headingDegrees;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 34,
      child: SafeArea(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 4,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width < 520 ? 224 : 280,
            height: 72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 10, 4),
              child: Row(
                children: [
                  Tooltip(
                    message: 'Reset map to north',
                    child: IconButton(
                      onPressed: onResetNorth,
                      icon: Transform.rotate(
                        angle: headingDegrees * math.pi / 180,
                        child: const Icon(Icons.navigation),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Heading',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const Spacer(),
                            Text(
                              '${headingDegrees.round() % 360}°',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 28,
                          child: Slider(
                            value: signedHeading.clamp(-180, 180),
                            min: -180,
                            max: 180,
                            onChanged: onHeadingChanged,
                          ),
                        ),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('S', style: TextStyle(fontSize: 9)),
                            Text('W', style: TextStyle(fontSize: 9)),
                            Text('N', style: TextStyle(fontSize: 9)),
                            Text('E', style: TextStyle(fontSize: 9)),
                            Text('S', style: TextStyle(fontSize: 9)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GpsRecorderTools extends StatelessWidget {
  const _GpsRecorderTools({
    required this.top,
    required this.recording,
    required this.elapsed,
    required this.hasDraft,
    required this.color,
    required this.pointCount,
    required this.lengthMeters,
    required this.ascentMeters,
    required this.descentMeters,
    required this.onStart,
    required this.onStop,
    required this.onSave,
    required this.onDiscard,
  });

  final double top;
  final bool recording;
  final Duration elapsed;
  final bool hasDraft;
  final Color color;
  final int pointCount;
  final double lengthMeters;
  final double ascentMeters;
  final double descentMeters;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final distance = lengthMeters >= 1000
        ? '${(lengthMeters / 1000).toStringAsFixed(2)} km'
        : '${lengthMeters.round()} m';
    return Positioned(
      right: 12,
      top: top,
      child: SafeArea(
        child: Material(
          elevation: 5,
          color: Theme.of(context).colorScheme.surface,
          shape: hasDraft ? null : const CircleBorder(),
          borderRadius: hasDraft ? BorderRadius.circular(8) : null,
          child: Padding(
            padding: EdgeInsets.all(hasDraft ? 8 : 2),
            child: hasDraft
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            recording ? Icons.fiber_manual_record : Icons.route,
                            color: recording ? Colors.red : color,
                            size: 20,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            recording
                                ? _formatRecordingDuration(elapsed)
                                : '${_formatRecordingDuration(elapsed)} · saved offline',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$distance · ↑${ascentMeters.round()} m · ↓${descentMeters.round()} m',
                      ),
                      Text(
                        '$pointCount points',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (recording)
                            FilledButton.icon(
                              onPressed: onStop,
                              icon: const Icon(Icons.stop, size: 18),
                              label: const Text('Stop'),
                            )
                          else
                            FilledButton.icon(
                              onPressed: pointCount < 2 ? null : onSave,
                              icon: const Icon(Icons.bookmark_add, size: 18),
                              label: const Text('Save'),
                            ),
                          TextButton(
                            onPressed: onDiscard,
                            child: const Text('Discard'),
                          ),
                        ],
                      ),
                    ],
                  )
                : IconButton.filled(
                    tooltip: 'Record GPS route',
                    onPressed: onStart,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.fiber_manual_record,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

String _formatRecordingDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutes:$seconds';
  return '$minutes:$seconds';
}

class _ParkingMarkerIcon extends StatelessWidget {
  const _ParkingMarkerIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'P',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _PathEditorTools extends StatelessWidget {
  const _PathEditorTools({
    required this.pointCount,
    required this.lengthMeters,
    required this.hasSelectedPoint,
    required this.onUndo,
    required this.onDeleteSelected,
    required this.onClear,
    required this.onCancel,
    required this.onSave,
  });

  final int pointCount;
  final double lengthMeters;
  final bool hasSelectedPoint;
  final VoidCallback? onUndo;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onClear;
  final VoidCallback onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final length = lengthMeters >= 1000
        ? '${(lengthMeters / 1000).toStringAsFixed(2)} km'
        : '${lengthMeters.round()} m';

    return Positioned(
      right: 12,
      bottom: 170,
      child: SafeArea(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timeline, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$pointCount control points - $length',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                  if (hasSelectedPoint)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Tap the map to move the selected point.'),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      IconButton.outlined(
                        tooltip: 'Undo last point',
                        onPressed: onUndo,
                        icon: const Icon(Icons.undo),
                      ),
                      IconButton.outlined(
                        tooltip: 'Delete selected point',
                        onPressed: onDeleteSelected,
                        icon: const Icon(Icons.delete_outline),
                      ),
                      IconButton.outlined(
                        tooltip: 'Clear path',
                        onPressed: onClear,
                        icon: const Icon(Icons.clear_all),
                      ),
                      TextButton(
                        onPressed: onCancel,
                        child: const Text('Cancel'),
                      ),
                      FilledButton.icon(
                        onPressed: onSave,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Save trail'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkiRouteDraft {
  const _SkiRouteDraft({
    required this.name,
    required this.area,
    required this.region,
    required this.difficulty,
    required this.distanceKm,
    required this.elevationGainMeters,
    required this.maxSlopeAngleDegrees,
    required this.aspect,
    required this.avalancheTerrain,
    required this.season,
    required this.description,
    required this.approachNotes,
    required this.descentNotes,
    required this.dangerInfo,
    required this.imageUrl,
  });

  final String name;
  final String area;
  final String region;
  final String difficulty;
  final double distanceKm;
  final int elevationGainMeters;
  final int maxSlopeAngleDegrees;
  final String aspect;
  final String avalancheTerrain;
  final String season;
  final String description;
  final String approachNotes;
  final String descentNotes;
  final String dangerInfo;
  final String imageUrl;
}

class _NewSkiRouteSheet extends StatefulWidget {
  const _NewSkiRouteSheet({
    required this.distanceKm,
    required this.trailhead,
    required this.highPoint,
  });

  final double distanceKm;
  final LatLng trailhead;
  final LatLng highPoint;

  @override
  State<_NewSkiRouteSheet> createState() => _NewSkiRouteSheetState();
}

class _NewSkiRouteSheetState extends State<_NewSkiRouteSheet> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final area = TextEditingController();
  final region = TextEditingController(text: 'Vancouver Island');
  final distanceKm = TextEditingController();
  final elevationGain = TextEditingController();
  final maxSlopeAngle = TextEditingController(text: '0');
  final season = TextEditingController(text: 'Winter through spring');
  final description = TextEditingController();
  final approachNotes = TextEditingController();
  final descentNotes = TextEditingController();
  final dangerInfo = TextEditingController();
  final imageUrl = TextEditingController(
    text: 'https://images.unsplash.com/photo-1517824806704-9040b037703b',
  );

  String difficulty = 'Intermediate';
  String aspect = 'North';
  String avalancheTerrain = 'Challenging';

  @override
  void initState() {
    super.initState();
    distanceKm.text = widget.distanceKm.toStringAsFixed(2);
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      area,
      region,
      distanceKm,
      elevationGain,
      maxSlopeAngle,
      season,
      description,
      approachNotes,
      descentNotes,
      dangerInfo,
      imageUrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Form(
        key: formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Create ski route from this line',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Trailhead: ${widget.trailhead.latitude.toStringAsFixed(5)}, ${widget.trailhead.longitude.toStringAsFixed(5)}\n'
              'High point: ${widget.highPoint.latitude.toStringAsFixed(5)}, ${widget.highPoint.longitude.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 12),
            _SheetField(controller: name, label: 'Route name'),
            _SheetField(controller: area, label: 'Ski area or zone'),
            _SheetField(controller: region, label: 'Region'),
            _SheetMenu(
              label: 'Difficulty',
              value: difficulty,
              values: const [
                'Beginner',
                'Beginner to Intermediate',
                'Intermediate',
                'Advanced',
                'Expert',
              ],
              onChanged: (value) => setState(() => difficulty = value),
            ),
            _SheetField(
              controller: distanceKm,
              label: 'Distance in km',
              decimal: true,
            ),
            _SheetField(
              controller: elevationGain,
              label: 'Elevation gain in meters',
              numeric: true,
            ),
            _SheetField(
              controller: maxSlopeAngle,
              label: 'Maximum slope angle in degrees (0 if unknown)',
              numeric: true,
            ),
            _SheetMenu(
              label: 'Aspect',
              value: aspect,
              values: const [
                'North',
                'Northeast',
                'East',
                'Southeast',
                'South',
                'Southwest',
                'West',
                'Northwest',
                'Rolling',
              ],
              onChanged: (value) => setState(() => aspect = value),
            ),
            _SheetMenu(
              label: 'Avalanche terrain',
              value: avalancheTerrain,
              values: const ['Simple', 'Challenging', 'Complex'],
              onChanged: (value) => setState(() => avalancheTerrain = value),
            ),
            _SheetField(controller: season, label: 'Best season'),
            _SheetField(
              controller: description,
              label: 'Description',
              lines: 3,
            ),
            _SheetField(
              controller: approachNotes,
              label: 'Approach notes',
              lines: 2,
            ),
            _SheetField(
              controller: descentNotes,
              label: 'Descent notes',
              lines: 2,
            ),
            _SheetField(
              controller: dangerInfo,
              label: 'Danger/safety notes',
              lines: 2,
            ),
            _SheetField(controller: imageUrl, label: 'Picture URL'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Add route to ski map'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!formKey.currentState!.validate()) return;
    final slopeAngle = parseWholeNumberWithUnits(maxSlopeAngle.text) ?? 0;
    if (slopeAngle < 0 || slopeAngle > 90) return;
    Navigator.pop(
      context,
      _SkiRouteDraft(
        name: name.text.trim(),
        area: area.text.trim(),
        region: region.text.trim(),
        difficulty: difficulty,
        distanceKm: parseNumberWithUnits(distanceKm.text) ?? 0,
        elevationGainMeters: parseWholeNumberWithUnits(elevationGain.text) ?? 0,
        maxSlopeAngleDegrees: slopeAngle,
        aspect: aspect,
        avalancheTerrain: avalancheTerrain,
        season: season.text.trim(),
        description: description.text.trim(),
        approachNotes: approachNotes.text.trim(),
        descentNotes: descentNotes.text.trim(),
        dangerInfo: dangerInfo.text.trim(),
        imageUrl: imageUrl.text.trim(),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.label,
    this.lines = 1,
    this.numeric = false,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String label;
  final int lines;
  final bool numeric;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        minLines: lines,
        maxLines: lines,
        keyboardType: numeric || decimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        decoration: InputDecoration(labelText: label),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Required' : null,
      ),
    );
  }
}

class _SheetMenu extends StatelessWidget {
  const _SheetMenu({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final item in values)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}

class _ParkingCoordinateBanner extends StatelessWidget {
  const _ParkingCoordinateBanner({
    required this.crag,
    required this.onClose,
    required this.onCopy,
    required this.onShare,
    required this.onOpenMaps,
  });

  final Crag crag;
  final VoidCallback onClose;
  final ValueChanged<Crag> onCopy;
  final ValueChanged<Crag> onShare;
  final ValueChanged<Crag> onOpenMaps;

  String get coordinates {
    return '${crag.parking.latitude.toStringAsFixed(6)}, ${crag.parking.longitude.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: SafeArea(
        top: false,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 5,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(9),
                    child: Icon(Icons.local_parking, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${crag.name} parking',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(coordinates),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Copy GPS',
                  icon: const Icon(Icons.copy),
                  onPressed: () => onCopy(crag),
                ),
                IconButton(
                  tooltip: 'Share GPS',
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => onShare(crag),
                ),
                IconButton.filled(
                  tooltip: 'Open in maps',
                  icon: const Icon(Icons.map),
                  onPressed: () => onOpenMaps(crag),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledMapMarker extends StatelessWidget {
  const _LabeledMapMarker({
    required this.label,
    required this.icon,
    required this.selected,
  });

  final String label;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: selected ? colors.secondary : colors.primary,
        elevation: 3,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colors.onPrimary, size: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkiRouteMapSheet extends StatelessWidget {
  const _SkiRouteMapSheet({required this.route});

  final SkiRoute route;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.94,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  route.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text('${route.area}, ${route.region}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('${route.distanceKm} km')),
              Chip(label: Text('${route.elevationGainMeters} m gain')),
              Chip(label: Text(route.difficulty)),
              Chip(label: Text(route.aspect)),
              Chip(label: Text(route.slopeAngleLabel)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Slope angle is one part of avalanche assessment. Check the current bulletin, snowpack, aspect, terrain traps, and field observations.',
          ),
          const SizedBox(height: 16),
          Text(route.description),
          const SizedBox(height: 18),
          _SkiDetailLine(
            icon: Icons.north_east,
            color: _PathDraftKind.skiAscent.color,
            title: 'Ascent',
            body: route.approachNotes,
          ),
          const SizedBox(height: 12),
          _SkiDetailLine(
            icon: Icons.south_east,
            color: _PathDraftKind.skiDescent.color,
            title: 'Descent',
            body: route.descentNotes,
          ),
          const SizedBox(height: 12),
          _SkiDetailLine(
            icon: Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
            title: 'Hazards',
            body: route.dangerInfo,
          ),
          if (route.sourceUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(route.sourceUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('View public route source'),
            ),
            const SizedBox(height: 6),
            Text(
              'Research lead only — confirm access, conditions, and the route in the field.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _SkiDetailLine extends StatelessWidget {
  const _SkiDetailLine({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(body),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkiMapLegend extends StatelessWidget {
  const _SkiMapLegend({required this.top});

  final double top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      top: top,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 3,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _LegendLine(
                color: _PathDraftKind.skiAscent.color,
                label: 'Ascent',
              ),
              const SizedBox(height: 6),
              _LegendLine(
                color: _PathDraftKind.skiDescent.color,
                label: 'Descent',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

enum _CoordinateEditKind { crag, parking, wallRoutes, route }

class _CoordinateEditTarget {
  const _CoordinateEditTarget({
    required this.kind,
    required this.point,
    this.route,
  });

  final _CoordinateEditKind kind;
  final LatLng point;
  final ClimbRoute? route;
}

class _CoordinateEditorSheet extends StatefulWidget {
  const _CoordinateEditorSheet({
    required this.crag,
    required this.selectedWall,
    required this.mapCenter,
  });

  final Crag crag;
  final Wall? selectedWall;
  final LatLng mapCenter;

  @override
  State<_CoordinateEditorSheet> createState() => _CoordinateEditorSheetState();
}

class _CoordinateEditorSheetState extends State<_CoordinateEditorSheet> {
  late final TextEditingController latitudeController;
  late final TextEditingController longitudeController;
  ClimbRoute? selectedRoute;

  @override
  void initState() {
    super.initState();
    latitudeController = TextEditingController(
      text: widget.mapCenter.latitude.toStringAsFixed(7),
    );
    longitudeController = TextEditingController(
      text: widget.mapCenter.longitude.toStringAsFixed(7),
    );
    selectedRoute = widget.selectedWall?.routes.isEmpty == false
        ? widget.selectedWall!.routes.first
        : null;
  }

  @override
  void dispose() {
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wall = widget.selectedWall;
    final routes = wall?.routes ?? const <ClimbRoute>[];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit map position',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(widget.crag.name),
            if (wall != null) Text(wall.name),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      prefixIcon: Icon(Icons.north),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      prefixIcon: Icon(Icons.east),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _save(_CoordinateEditKind.crag),
                  icon: const Icon(Icons.terrain),
                  label: const Text('Save crag pin'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _save(_CoordinateEditKind.parking),
                  icon: const Icon(Icons.local_parking),
                  label: const Text('Save parking'),
                ),
                OutlinedButton.icon(
                  onPressed: wall == null
                      ? null
                      : () => _save(_CoordinateEditKind.wallRoutes),
                  icon: const Icon(Icons.scatter_plot),
                  label: const Text('Move selected boulder'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (routes.isNotEmpty) ...[
              DropdownButtonFormField<ClimbRoute>(
                initialValue: selectedRoute,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Single route point',
                  prefixIcon: Icon(Icons.route),
                ),
                items: [
                  for (final route in routes)
                    DropdownMenuItem(
                      value: route,
                      child: Text('${route.name} (${route.grade})'),
                    ),
                ],
                onChanged: (route) => setState(() => selectedRoute = route),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: selectedRoute == null
                    ? null
                    : () => _save(_CoordinateEditKind.route),
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Save selected route only'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _save(_CoordinateEditKind kind) {
    final lat = double.tryParse(latitudeController.text.trim());
    final lng = double.tryParse(longitudeController.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid latitude and longitude')),
      );
      return;
    }

    Navigator.pop(
      context,
      _CoordinateEditTarget(
        kind: kind,
        point: LatLng(lat, lng),
        route: kind == _CoordinateEditKind.route ? selectedRoute : null,
      ),
    );
  }
}
