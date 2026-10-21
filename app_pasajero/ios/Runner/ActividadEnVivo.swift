import ActivityKit
import Flutter
import Foundation

/// El lado nativo de `actividad_en_vivo.dart`: pone, pone al día y quita la
/// actividad en vivo del bus seguido. Antes de iOS 16.2, o con las
/// actividades apagadas en Ajustes, no hace nada: el aviso suena igual.
enum ActividadEnVivo {
  static func registrar(con registrador: FlutterPluginRegistrar) {
    let canal = FlutterMethodChannel(
      name: "yaviene/actividad_en_vivo",
      binaryMessenger: registrador.messenger()
    )
    canal.setMethodCallHandler { llamada, responder in
      guard #available(iOS 16.2, *) else { return responder(nil) }
      guard let datos = llamada.arguments as? [String: Any],
        let busId = datos["busId"] as? String, !busId.isEmpty
      else {
        return responder(
          FlutterError(code: "datos", message: "sin busId", details: nil))
      }
      switch llamada.method {
      case "mostrar":
        Gestor.mostrar(busId: busId, datos: datos)
        responder(nil)
      case "terminar":
        Gestor.terminar(busId: busId, llego: datos["llego"] as? Bool ?? false)
        responder(nil)
      default:
        responder(FlutterMethodNotImplemented)
      }
    }
  }
}

@available(iOS 16.2, *)
private enum Gestor {
  /// La app no lee la ubicación con la pantalla apagada: pasado este rato
  /// sin datos nuevos, la actividad dice que no los tiene.
  static let vigencia: TimeInterval = 2 * 60

  /// Lo que se queda en la pantalla bloqueada el aviso que sonó.
  static let despedida: TimeInterval = 10 * 60

  static func actividad(de busId: String) -> Activity<AvisoAtributos>? {
    Activity<AvisoAtributos>.activities.first { $0.attributes.busId == busId }
  }

  static func mostrar(busId: String, datos: [String: Any]) {
    let estado = AvisoAtributos.ContentState(
      distancia: datos["distancia"] as? String ?? "",
      aviso: datos["aviso"] as? String ?? "",
      avance: datos["avance"] as? Double ?? 0,
      avanceAviso: datos["avanceAviso"] as? Double ?? 0,
      llego: false
    )
    let contenido = ActivityContent(
      state: estado, staleDate: Date().addingTimeInterval(vigencia))
    if let viva = actividad(de: busId) {
      Task { await viva.update(contenido) }
      return
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let atributos = AvisoAtributos(
      busId: busId,
      placa: datos["placa"] as? String ?? "",
      ruta: datos["ruta"] as? String ?? ""
    )
    do {
      _ = try Activity.request(attributes: atributos, content: contenido)
    } catch {
      NSLog("actividad en vivo de \(busId) no arrancó: \(error)")
    }
  }

  static func terminar(busId: String, llego: Bool) {
    guard let viva = actividad(de: busId) else { return }
    var estado = viva.content.state
    estado.llego = llego
    let politica: ActivityUIDismissalPolicy =
      llego ? .after(Date().addingTimeInterval(despedida)) : .immediate
    Task {
      await viva.end(ActivityContent(state: estado, staleDate: nil), dismissalPolicy: politica)
    }
  }
}
