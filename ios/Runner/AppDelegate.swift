import Flutter
import MapKit
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ClimbOnTerrainMap") {
      registrar.register(
        ClimbOnTerrainMapFactory(messenger: registrar.messenger()),
        withId: "climb_on/terrain_map"
      )
    }
  }
}

private final class ClimbOnTerrainMapFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    ClimbOnWebTerrainMapView(
      frame: frame,
      viewId: viewId,
      arguments: args as? [String: Any] ?? [:],
      messenger: messenger
    )
  }
}

private final class ClimbOnWebTerrainMapView: NSObject, FlutterPlatformView,
  WKScriptMessageHandler
{
  private let webView: WKWebView
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewId: Int64,
    arguments: [String: Any],
    messenger: FlutterBinaryMessenger
  ) {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true
    webView = WKWebView(frame: frame, configuration: configuration)
    channel = FlutterMethodChannel(
      name: "climb_on/terrain_map/\(viewId)",
      binaryMessenger: messenger
    )
    super.init()

    configuration.userContentController.add(self, name: "climbOn")
    webView.isOpaque = true
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.bounces = false
    webView.loadHTMLString(html(arguments), baseURL: URL(string: "https://climbon.local/"))

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "updateMapData" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let values = call.arguments as? [String: Any] ?? [:]
      self?.sendMapData(values)
      result(nil)
    }
  }

  func view() -> UIView { webView }

  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    guard
      message.name == "climbOn",
      let value = message.body as? [String: Any],
      let kind = value["kind"] as? String,
      let id = value["id"] as? String
    else { return }
    channel.invokeMethod("markerTapped", arguments: ["kind": kind, "id": id])
  }

  private func sendMapData(_ values: [String: Any]) {
    let encoded = base64(values)
    webView.evaluateJavaScript("window.updateMapDataB64('\(encoded)')")
  }

  private func base64(_ value: Any) -> String {
    guard JSONSerialization.isValidJSONObject(value),
      let data = try? JSONSerialization.data(withJSONObject: value)
    else { return "e30=" }
    return data.base64EncodedString()
  }

  private func html(_ arguments: [String: Any]) -> String {
    let encoded = base64(arguments)
    return """
      <!doctype html>
      <html><head>
      <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
      <link rel="stylesheet" href="https://unpkg.com/maplibre-gl@5.24.0/dist/maplibre-gl.css">
      <script src="https://unpkg.com/maplibre-gl@5.24.0/dist/maplibre-gl.js"></script>
      <style>
        html,body,#map{width:100%;height:100%;margin:0;overflow:hidden;background:#101820}
        .maplibregl-ctrl-attrib{font-size:9px}
      </style></head><body><div id="map"></div><script>
      const initial = JSON.parse(atob('\(encoded)'));
      const bounds = [
        [initial.longitude - 2.5, initial.latitude - 1.75],
        [initial.longitude + 2.5, initial.latitude + 1.75]
      ];
      let currentData = initial;
      const map = new maplibregl.Map({
        container:'map',
        center:[initial.longitude, initial.latitude],
        zoom:Math.max(8, Math.min(17, initial.zoom || 14)),
        pitch:78,
        bearing:18,
        maxPitch:85,
        maxZoom:18,
        maxBounds:bounds,
        attributionControl:true,
        style:{
          version:8,
          sources:{
            satellite:{type:'raster',tiles:['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],tileSize:256,maxzoom:19,attribution:'Imagery © Esri and data providers'},
            terrainSource:{type:'raster-dem',url:'https://tiles.mapterhorn.com/tilejson.json'},
            hillshadeSource:{type:'raster-dem',url:'https://tiles.mapterhorn.com/tilejson.json'}
          },
          layers:[
            {id:'satellite',type:'raster',source:'satellite'},
            {id:'hillshade',type:'hillshade',source:'hillshadeSource',paint:{'hillshade-exaggeration':0.22}}
          ],
          terrain:{source:'terrainSource',exaggeration:1},
          sky:{}
        }
      });
      map.touchPitch.enable();
      map.touchZoomRotate.enable();

      function pointFeatures(data){
        const result=[];
        (data.crags||[]).forEach(p=>result.push({type:'Feature',properties:{id:p.id,name:p.name,kind:'crag',selected:false},geometry:{type:'Point',coordinates:[p.longitude,p.latitude]}}));
        (data.skiRoutes||[]).forEach(p=>result.push({type:'Feature',properties:{id:p.id,name:p.name,kind:'ski',selected:!!p.selected},geometry:{type:'Point',coordinates:[p.longitude,p.latitude]}}));
        if(data.parking) result.push({type:'Feature',properties:{id:'parking',name:data.parking.name,kind:'parking',selected:false},geometry:{type:'Point',coordinates:[data.parking.longitude,data.parking.latitude]}});
        return {type:'FeatureCollection',features:result};
      }
      function lineFeatures(data){
        return {type:'FeatureCollection',features:(data.polylines||[]).map((p,i)=>({type:'Feature',properties:{id:p.entityId||String(i),kind:p.entityId?'ski':'path',color:p.color||'#FFD166',width:Number(p.width||2.25),selected:!!p.selected},geometry:{type:'LineString',coordinates:(p.points||[]).map(v=>[v.longitude,v.latitude])}}))};
      }
      function update(data){
        currentData=data;
        const points=map.getSource('app-points'); if(points) points.setData(pointFeatures(data));
        const lines=map.getSource('app-lines'); if(lines) lines.setData(lineFeatures(data));
      }
      window.updateMapDataB64 = value => update(JSON.parse(atob(value)));
      map.on('load',()=>{
        map.addSource('app-lines',{type:'geojson',data:lineFeatures(currentData)});
        map.addLayer({id:'app-lines',type:'line',source:'app-lines',paint:{'line-color':['get','color'],'line-width':['case',['boolean',['get','selected'],false],6,['get','width']],'line-opacity':['case',['boolean',['get','selected'],false],1,0.86]}});
        map.addSource('app-points',{type:'geojson',data:pointFeatures(currentData)});
        map.addLayer({id:'crag-pins',type:'circle',source:'app-points',filter:['==',['get','kind'],'crag'],paint:{'circle-radius':7,'circle-color':'#14618c','circle-stroke-color':'#fff','circle-stroke-width':2}});
        map.addLayer({id:'ski-pins',type:'circle',source:'app-points',filter:['==',['get','kind'],'ski'],paint:{'circle-radius':['case',['boolean',['get','selected'],false],10,7],'circle-color':['case',['boolean',['get','selected'],false],'#FFD166','#D33B2F'],'circle-stroke-color':'#fff','circle-stroke-width':2}});
        map.addLayer({id:'parking-pin',type:'circle',source:'app-points',filter:['==',['get','kind'],'parking'],paint:{'circle-radius':8,'circle-color':'#F28C28','circle-stroke-color':'#fff','circle-stroke-width':2.5}});
        ['crag-pins','ski-pins'].forEach(layer=>map.on('click',layer,e=>{const p=e.features[0].properties;window.webkit.messageHandlers.climbOn.postMessage({kind:p.kind,id:p.id});}));
        map.on('click','app-lines',e=>{const p=e.features[0].properties;if(p.kind==='ski')window.webkit.messageHandlers.climbOn.postMessage({kind:'ski',id:p.id});});
        ['crag-pins','ski-pins','app-lines'].forEach(layer=>{map.on('mouseenter',layer,()=>map.getCanvas().style.cursor='pointer');map.on('mouseleave',layer,()=>map.getCanvas().style.cursor='');});
      });
      </script></body></html>
      """
  }
}

private final class ClimbOnCragAnnotation: MKPointAnnotation {
  let cragId: String

  init(id: String, name: String, coordinate: CLLocationCoordinate2D) {
    cragId = id
    super.init()
    title = name
    self.coordinate = coordinate
  }
}

private final class ClimbOnParkingAnnotation: MKPointAnnotation {}

private final class ClimbOnTerrainMapView: NSObject, FlutterPlatformView, MKMapViewDelegate {
  private let mapView: MKMapView
  private let channel: FlutterMethodChannel
  private var polylineStyles: [ObjectIdentifier: (UIColor, CGFloat)] = [:]

  init(
    frame: CGRect,
    viewId: Int64,
    arguments: [String: Any],
    messenger: FlutterBinaryMessenger
  ) {
    mapView = MKMapView(frame: frame)
    channel = FlutterMethodChannel(
      name: "climb_on/terrain_map/\(viewId)",
      binaryMessenger: messenger
    )
    super.init()

    mapView.delegate = self
    mapView.mapType = .hybridFlyover
    mapView.showsBuildings = true
    mapView.showsCompass = true
    mapView.showsScale = true
    mapView.showsTraffic = false
    mapView.pointOfInterestFilter = .excludingAll
    mapView.isPitchEnabled = true
    mapView.isRotateEnabled = arguments["allowRotation"] as? Bool ?? true
    if #available(iOS 16.0, *) {
      mapView.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)
    }

    let latitude = arguments["latitude"] as? Double ?? 48.43989
    let longitude = arguments["longitude"] as? Double ?? -123.56344
    let zoom = arguments["zoom"] as? Double ?? 14
    let distance = max(350, 120_000 / pow(2, zoom - 10))
    let activeRegion = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
      span: MKCoordinateSpan(latitudeDelta: 3.5, longitudeDelta: 5)
    )
    mapView.setCameraBoundary(
      MKMapView.CameraBoundary(coordinateRegion: activeRegion),
      animated: false
    )
    mapView.setCameraZoomRange(
      MKMapView.CameraZoomRange(
        minCenterCoordinateDistance: 250,
        maxCenterCoordinateDistance: 250_000
      ),
      animated: false
    )
    mapView.camera = MKMapCamera(
      lookingAtCenter: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
      fromDistance: distance,
      pitch: 80,
      heading: 18
    )

    updateMapData(arguments)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "updateMapData":
        self?.updateMapData(call.arguments as? [String: Any] ?? [:])
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { mapView }

  private func updateMapData(_ values: [String: Any]) {
    updateCrags(values["crags"] as? [[String: Any]] ?? [])
    updatePolylines(values["polylines"] as? [[String: Any]] ?? [])
    if let parking = values["parking"] as? [String: Any] {
      addParking(parking)
    }
  }

  private func updateCrags(_ values: [[String: Any]]) {
    mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
    let annotations = values.compactMap { value -> ClimbOnCragAnnotation? in
      guard
        let id = value["id"] as? String,
        let name = value["name"] as? String,
        let latitude = value["latitude"] as? Double,
        let longitude = value["longitude"] as? Double
      else { return nil }
      return ClimbOnCragAnnotation(
        id: id,
        name: name,
        coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
      )
    }
    mapView.addAnnotations(annotations)
  }

  private func addParking(_ value: [String: Any]) {
    guard
      let name = value["name"] as? String,
      let latitude = value["latitude"] as? Double,
      let longitude = value["longitude"] as? Double
    else { return }
    let annotation = ClimbOnParkingAnnotation()
    annotation.title = name
    annotation.coordinate = CLLocationCoordinate2D(
      latitude: latitude,
      longitude: longitude
    )
    mapView.addAnnotation(annotation)
  }

  private func updatePolylines(_ values: [[String: Any]]) {
    mapView.removeOverlays(mapView.overlays)
    polylineStyles.removeAll()
    for value in values {
      guard let rawPoints = value["points"] as? [[String: Any]] else { continue }
      var coordinates = rawPoints.compactMap { point -> CLLocationCoordinate2D? in
        guard
          let latitude = point["latitude"] as? Double,
          let longitude = point["longitude"] as? Double
        else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
      }
      guard coordinates.count >= 2 else { continue }
      let polyline = MKPolyline(coordinates: &coordinates, count: coordinates.count)
      let color = color(value["color"] as? String ?? "#FFD166")
      let width = CGFloat(value["width"] as? Double ?? 5)
      polylineStyles[ObjectIdentifier(polyline)] = (color, width)
      mapView.addOverlay(polyline, level: .aboveLabels)
    }
  }

  private func color(_ hex: String) -> UIColor {
    let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard let number = UInt64(value, radix: 16), value.count == 6 else {
      return .systemYellow
    }
    return UIColor(
      red: CGFloat((number >> 16) & 0xff) / 255,
      green: CGFloat((number >> 8) & 0xff) / 255,
      blue: CGFloat(number & 0xff) / 255,
      alpha: 1
    )
  }

  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    if annotation is ClimbOnParkingAnnotation {
      let identifier = "climb-on-parking"
      let marker = mapView.dequeueReusableAnnotationView(
        withIdentifier: identifier
      ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
        annotation: annotation,
        reuseIdentifier: identifier
      )
      marker.annotation = annotation
      marker.markerTintColor = .systemOrange
      marker.glyphImage = UIImage(systemName: "parkingsign.circle.fill")
      marker.canShowCallout = true
      return marker
    }
    guard annotation is ClimbOnCragAnnotation else { return nil }
    let identifier = "climb-on-crag"
    let marker = mapView.dequeueReusableAnnotationView(
      withIdentifier: identifier
    ) as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(
      annotation: annotation,
      reuseIdentifier: identifier
    )
    marker.annotation = annotation
    marker.markerTintColor = UIColor(red: 0.08, green: 0.38, blue: 0.55, alpha: 1)
    marker.glyphImage = UIImage(systemName: "mountain.2.fill")
    marker.canShowCallout = true
    return marker
  }

  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    guard let polyline = overlay as? MKPolyline else {
      return MKOverlayRenderer(overlay: overlay)
    }
    let renderer = MKPolylineRenderer(polyline: polyline)
    let style = polylineStyles[ObjectIdentifier(polyline)] ?? (.systemYellow, 5)
    renderer.strokeColor = style.0
    renderer.lineWidth = style.1
    renderer.lineCap = .butt
    renderer.lineJoin = .round
    return renderer
  }

  func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
    guard let crag = view.annotation as? ClimbOnCragAnnotation else { return }
    channel.invokeMethod("cragTapped", arguments: ["id": crag.cragId])
  }
}
