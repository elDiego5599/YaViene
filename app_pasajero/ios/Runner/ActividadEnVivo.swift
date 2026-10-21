import ActivityKit
import Flutter
import Foundation

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
        Gestor.mostrar(busId: busId, datos: datos) { responder(nil) }
      case "terminar":
        Gestor.terminar(busId: busId, llego: datos["llego"] as? Bool ?? false)
        responder(nil)
      default:
        responder(FlutterMethodNotImplemented)
      }
    }
  }

  static func recibir(_ url: URL, viva: Bool) {
    guard valida(url) else { return }
    if viva {
      canal?.invokeMethod("avisoTocado", arguments: url.absoluteString)
    } else {
      avisoPendiente = url.absoluteString
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
    alTerminar: @escaping () -> Void
  ) {
    let estado = AvisoAtributos.ContentState(
      distancia: datos["distancia"] as? String ?? "",
      aviso: datos["aviso"] as? String ?? "",
      avance: datos["avance"] as? Double ?? 0,
      avanceAviso: datos["avanceAviso"] as? Double ?? 0,
      llego: false
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
      placa: datos["placa"] as? String ?? "",
      ruta: datos["ruta"] as? String ?? ""
    )
    Task {
      defer { DispatchQueue.main.async { alTerminar() } }
      for actividad in porTerminar {
        await actividad.end(nil, dismissalPolicy: .immediate)
      }
      if let viva {
        await viva.update(contenido)
        return
      }
      guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
      do {
        _ = try Activity.request(attributes: atributos, content: contenido)
      } catch {
        NSLog("actividad en vivo de \(busId) no arrancó: \(error)")
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
