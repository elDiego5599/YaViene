import ActivityKit
import Foundation

/// Lo que comparten la app y la extensión: la actividad en vivo de un
/// aviso armado (dueño, 2026-10-19). Este archivo se compila en los dos
/// objetivos, Runner y AvisoEnVivo; el lado de Dart lo llena por el canal
/// `yaviene/actividad_en_vivo` (`actividad_en_vivo.dart`).
@available(iOS 16.1, *)
struct AvisoAtributos: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// «1,5 km», la cifra de la hoja.
    var distancia: String
    /// «Te avisamos a 1,0 km».
    var aviso: String
    /// Lo que lleva el bus de la barra de 3 km: 0 al principio, 1 en tu punto.
    var avance: Double
    /// Dónde va la marca del aviso en la misma barra.
    var avanceAviso: Double
    /// El aviso sonó: el bus está cerca.
    var llego: Bool
  }

  var busId: String
  /// El código de la ficha (B18); vacío si la ruta no trae uno.
  var codigo: String
  /// El nombre de la ruta sin su código.
  var ruta: String
  /// El color de la ficha, en ARGB, el mismo de la ficha del aviso.
  var color: Int
}
