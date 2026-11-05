import ActivityKit
import CoreLocation
import Flutter
import Foundation

/// El lado nativo de `mantener_vivo.dart`: mientras hay un aviso armado, un
/// CLLocationManager propio con segundo plano evita que iOS suspenda la app
/// con la pantalla bloqueada (sin eso no hay barrido, ni aviso, ni actividad
/// al día). Propio porque el stream de geolocator es uno solo y el del mapa
/// lo abre sin segundo plano. Las posiciones no se leen.
enum MantenerVivo {
  private static var gestor: CLLocationManager?

  static func registrar(con registrador: FlutterPluginRegistrar) {
    FlutterMethodChannel(
      name: "yaviene/mantener_vivo",
      binaryMessenger: registrador.messenger()
    ).setMethodCallHandler { llamada, responder in
      switch llamada.method {
      case "iniciar":
        iniciar()
        responder(nil)
      case "detener":
        gestor?.stopUpdatingLocation()
        gestor = nil
        responder(nil)
      default:
        responder(FlutterMethodNotImplemented)
      }
    }
  }

  private static func iniciar() {
    guard gestor == nil else { return }
    let nuevo = CLLocationManager()
    nuevo.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    nuevo.distanceFilter = 100
    nuevo.activityType = .otherNavigation
    nuevo.pausesLocationUpdatesAutomatically = false
    nuevo.allowsBackgroundLocationUpdates = true
    nuevo.showsBackgroundLocationIndicator = true
    nuevo.startUpdatingLocation()
    gestor = nuevo
  }
}

/// El lado nativo de `actividad_en_vivo.dart`: pone, pone al día y quita la
/// actividad en vivo del bus seguido. Antes de iOS 16.2, o con las
/// actividades apagadas en Ajustes, no hace nada: el aviso suena igual.
enum ActividadEnVivo {
  static var canal: FlutterMethodChannel?
  private static var avisoPendiente: String?

  static func registrar(con registrador: FlutterPluginRegistrar) {
    let nuevoCanal = FlutterMethodChannel(
      name: "yaviene/actividad_en_vivo",
      binaryMessenger: registrador.messenger()
    )
    canal = nuevoCanal
    nuevoCanal.setMethodCallHandler { llamada, responder in
      if llamada.method == "leerAvisoPendiente" {
        let pendiente = avisoPendiente
        avisoPendiente = nil
        return responder(pendiente)
      }
      if llamada.method == "confirmarAvisoPendiente" {
        avisoPendiente = nil
        return responder(nil)
      }
      // Antes de 16.2 no hay actividad: `sonar` lee nil como «no hay» y
      // el aviso sale en banner.
      guard #available(iOS 16.2, *) else { return responder(nil) }
      guard let datos = llamada.arguments as? [String: Any],
        let busId = datos["busId"] as? String, !busId.isEmpty
      else {
        return responder(
          FlutterError(code: "datos", message: "sin busId", details: nil))
      }
      switch llamada.method {
      case "mostrar":
        // Dart puede completar el aviso y pedir `terminar` en la misma
        // vuelta (bus ya dentro del radio). Responder después de ActivityKit
        // evita que `terminar` busque antes de que `request` cree la actividad.
        // Responde si quedó viva: iOS no deja pedirla con la app atrás, y
        // Dart la vuelve a pedir en el barrido siguiente.
        Gestor.mostrar(busId: busId, datos: datos) { viva in responder(viva) }
      case "terminar":
        Gestor.terminar(busId: busId, llego: datos["llego"] as? Bool ?? false)
        responder(nil)
      case "sonar":
        Gestor.sonar(busId: busId) { viva in responder(viva) }
      default:
        responder(FlutterMethodNotImplemented)
      }
    }
  }

  static func recibir(_ url: URL, viva: Bool) {
    guard valida(url) else { return }
    // El URL puede llegar antes de que el engine implícito o el handler Dart
    // estén listos. Conservarlo permite recuperarlo por leerAvisoPendiente.
    avisoPendiente = url.absoluteString
    if viva {
      canal?.invokeMethod("avisoTocado", arguments: url.absoluteString)
    }
  }

  private static func valida(_ url: URL) -> Bool {
    guard url.scheme == "yaviene", url.host == "aviso",
      let partes = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let busId = partes.queryItems?.first(where: { $0.name == "busId" })?.value,
      let routeId = partes.queryItems?.first(where: { $0.name == "routeId" })?.value
    else { return false }
    return !busId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && busId.count <= 256
      && !routeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && routeId.count <= 256
      && (partes.queryItems?.first(where: { $0.name == "companyId" })?.value
        .map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 256 }
        ?? true)
  }
}

@available(iOS 16.2, *)
private enum Gestor {
  /// La app no lee la ubicación con la pantalla apagada: pasado este rato
  /// sin datos nuevos, la actividad dice que no los tiene.
  static let vigencia: TimeInterval = 2 * 60

  /// Lo que se queda en la pantalla bloqueada el aviso que sonó.
  static let despedida: TimeInterval = 10 * 60

  static func mostrar(
    busId: String,
    datos: [String: Any],
    alTerminar: @escaping (Bool) -> Void
  ) {
    let estado = AvisoAtributos.ContentState(
      distancia: datos["distancia"] as? String ?? "",
      aviso: datos["aviso"] as? String ?? "",
      avance: datos["avance"] as? Double ?? 0,
      avanceAviso: datos["avanceAviso"] as? Double ?? 0,
      llego: datos["llego"] as? Bool ?? false
    )
    let contenido = ActivityContent(
      state: estado, staleDate: Date().addingTimeInterval(vigencia))
    let actividades = Activity<AvisoAtributos>.activities
    let viva = actividades.first {
      $0.attributes.busId == busId && $0.activityState == .active
    }
    let porTerminar = actividades.filter {
      $0.id != viva?.id
    }
    let atributos = AvisoAtributos(
      busId: busId,
      routeId: datos["routeId"] as? String ?? "",
      companyId: datos["companyId"] as? String,
      placa: datos["placa"] as? String ?? "",
      ruta: datos["ruta"] as? String ?? ""
    )
    Task {
      var quedoViva = false
      defer { DispatchQueue.main.async { alTerminar(quedoViva) } }
      for actividad in porTerminar {
        await actividad.end(nil, dismissalPolicy: .immediate)
      }
      if let viva {
        await viva.update(contenido)
        quedoViva = true
        return
      }
      guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
      do {
        _ = try Activity.request(attributes: atributos, content: contenido)
        quedoViva = true
      } catch {
        // Con la app atrás (pantalla bloqueada) iOS la niega: Dart lo sabe
        // por la respuesta y la vuelve a pedir.
        NSLog("actividad en vivo de \(busId) no arrancó: \(error)")
      }
    }
  }

  /// Lo que la isla sigue diciendo que el bus está cerca tras abrirse. Una
  /// actividad terminada sale de la isla en el acto (la despedida solo vale
  /// en la pantalla bloqueada), así que se termina después; cabe en los
  /// ~30 s de fondo que iOS da tras soltar la ubicación.
  static let enLaIsla: TimeInterval = 25

  /// El bus llegó: la actividad da el aviso (pantalla encendida, sonido y,
  /// en la isla, abierta), se queda [enLaIsla] en la isla y [despedida] en
  /// la pantalla bloqueada diciendo que está cerca. Es el único aviso: el
  /// banner solo sale si responde `false`.
  static func sonar(busId: String, alTerminar: @escaping (Bool) -> Void) {
    guard let viva = Activity<AvisoAtributos>.activities.first(where: {
      $0.attributes.busId == busId && $0.activityState == .active
    }) else { return alTerminar(false) }
    var estado = viva.content.state
    estado.llego = true
    let contenido = ActivityContent(state: estado, staleDate: nil)
    let alerta = AlertConfiguration(
      title: "Tu bus está cerca de ti", body: "", sound: .default)
    let sonoEn = Date()
    // Dart desarma el aviso al saber que sonó y suelta la ubicación: sin
    // este tiempo de fondo, iOS suspendería la app antes de terminarla.
    var fondo = UIBackgroundTaskIdentifier.invalid
    fondo = UIApplication.shared.beginBackgroundTask(withName: "aviso en la isla") {
      UIApplication.shared.endBackgroundTask(fondo)
      fondo = .invalid
    }
    Task {
      await viva.update(contenido, alertConfiguration: alerta)
      DispatchQueue.main.async { alTerminar(true) }
      try? await Task.sleep(nanoseconds: UInt64(enLaIsla * 1_000_000_000))
      await viva.end(
        contenido, dismissalPolicy: .after(sonoEn.addingTimeInterval(despedida)))
      DispatchQueue.main.async {
        guard fondo != .invalid else { return }
        UIApplication.shared.endBackgroundTask(fondo)
        fondo = .invalid
      }
    }
  }

  static func terminar(busId: String, llego: Bool) {
    guard let viva = Activity<AvisoAtributos>.activities.first(where: {
      $0.attributes.busId == busId && $0.activityState == .active
    }) else { return }
    var estado = viva.content.state
    estado.llego = llego
    let politica: ActivityUIDismissalPolicy =
      llego ? .after(Date().addingTimeInterval(despedida)) : .immediate
    Task {
      await viva.end(ActivityContent(state: estado, staleDate: nil), dismissalPolicy: politica)
    }
  }
}
