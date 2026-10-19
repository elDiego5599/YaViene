import ActivityKit
import SwiftUI
import WidgetKit

/// La actividad en vivo de un aviso armado: la pantalla bloqueada y la
/// Dynamic Island (dueño, 2026-10-19). Espeja la hoja del mapa: la ficha de
/// la ruta, la cifra de la distancia y la barra de lo que falta
/// (`barra_avance.dart`), con la marca donde va a sonar.
@main
struct AvisoEnVivoBundle: WidgetBundle {
  var body: some Widget {
    AvisoEnVivo()
  }
}

struct AvisoEnVivo: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: AvisoAtributos.self) { contexto in
      PantallaBloqueada(contexto: contexto)
        .activityBackgroundTint(.white)
        .activitySystemActionForegroundColor(Tinta.principal)
    } dynamicIsland: { contexto in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Ficha(atributos: contexto.attributes, lado: 36)
            .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Cifra(texto: contexto.state.distancia, tamano: 28)
            .foregroundStyle(.white)
            .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(Textos.titulo(contexto))
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 8) {
            Barra(
              estado: contexto.state,
              color: contexto.attributes.colorFicha,
              recorrido: .white.opacity(0.28)
            )
            if !contexto.state.llego {
              Text(Textos.pie(contexto))
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
            }
          }
          .padding(.horizontal, 4)
        }
      } compactLeading: {
        Ficha(atributos: contexto.attributes, lado: 22)
      } compactTrailing: {
        Cifra(texto: contexto.state.distancia, tamano: 15)
          .foregroundStyle(.white)
      } minimal: {
        Ficha(atributos: contexto.attributes, lado: 22)
      }
      .keylineTint(contexto.attributes.colorFicha)
    }
  }
}

/// La tinta de la app (`AppColors.textPrimary`, `textSecondary`).
enum Tinta {
  static let principal = Color(red: 0x0F / 255, green: 0x17 / 255, blue: 0x2A / 255)
  static let secundaria = Color(red: 0x5E / 255, green: 0x6B / 255, blue: 0x82 / 255)
  /// Lo que el bus ya dejó atrás (`AppColors.divider`).
  static let recorrido = Color(red: 0xE5 / 255, green: 0xE7 / 255, blue: 0xEB / 255)
}

enum Textos {
  /// Con el aviso sonado, el texto del aviso (`aviso.app` del glosario).
  static func titulo(_ c: ActivityViewContext<AvisoAtributos>) -> String {
    let ruta = c.attributes.ruta
    if c.state.llego {
      return ruta.isEmpty
        ? "Tu bus está cerca de ti" : "Tu bus de la ruta \(ruta) está cerca de ti"
    }
    return ruta.isEmpty ? "Tu bus" : ruta
  }

  /// La app no lee la ubicación con la pantalla apagada: pasado un rato sin
  /// datos, la actividad lo dice en vez de enseñar una cifra vieja como
  /// viva.
  static func pie(_ c: ActivityViewContext<AvisoAtributos>) -> String {
    if c.state.llego { return "" }
    if c.isStale { return "Sin datos nuevos, abre Ya Viene" }
    return c.state.aviso
  }
}

struct PantallaBloqueada: View {
  let contexto: ActivityViewContext<AvisoAtributos>

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        Ficha(atributos: contexto.attributes, lado: 40)
        VStack(alignment: .leading, spacing: 2) {
          Text(Textos.titulo(contexto))
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Tinta.principal)
            .lineLimit(2)
          if !contexto.state.llego {
            Text(Textos.pie(contexto))
              .font(.system(size: 13))
              .foregroundStyle(Tinta.secundaria)
              .lineLimit(1)
          }
        }
        Spacer(minLength: 8)
        if !contexto.state.llego {
          Cifra(texto: contexto.state.distancia, tamano: 28)
            .foregroundStyle(contexto.isStale ? Tinta.secundaria : Tinta.principal)
        }
      }
      Barra(
        estado: contexto.state,
        color: contexto.attributes.colorFicha,
        recorrido: Tinta.recorrido
      )
      .opacity(contexto.isStale ? 0.5 : 1)
    }
    .padding(16)
  }
}

/// La cifra de la distancia, que rueda al cambiar como la de la hoja.
struct Cifra: View {
  let texto: String
  let tamano: CGFloat

  var body: some View {
    let base = Text(texto)
      .font(.system(size: tamano, weight: .bold, design: .rounded))
      .monospacedDigit()
      .lineLimit(1)
      .minimumScaleFactor(0.7)
    if #available(iOS 17.0, *) {
      base.contentTransition(.numericText())
    } else {
      base
    }
  }
}

/// La ficha de la ruta (`ficha_ruta.dart`): su código en blanco sobre el
/// color de la empresa, con el radio y la letra en la misma proporción.
struct Ficha: View {
  let atributos: AvisoAtributos
  let lado: CGFloat

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: lado * 0.22, style: .continuous)
        .fill(atributos.colorFicha)
      if atributos.codigo.isEmpty {
        Image(systemName: "bus.fill")
          .font(.system(size: lado * 0.46, weight: .semibold))
          .foregroundStyle(.white)
      } else {
        Text(atributos.codigo)
          .font(.system(size: lado * 0.4, weight: .heavy))
          .tracking(-0.3)
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .padding(.horizontal, lado * 0.06)
      }
    }
    .frame(width: lado, height: lado)
  }
}

/// La barra de lo que falta (`BarraAvance`): 3 km que acaban en tu punto,
/// de gris lo que el bus dejó atrás y en color lo que le queda, con la
/// marca del aviso.
struct Barra: View {
  let estado: AvisoAtributos.ContentState
  let color: Color
  let recorrido: Color

  private let bus: CGFloat = 14
  private let punto: CGFloat = 12
  private let grosor: CGFloat = 4
  private let marca: CGFloat = 2

  var body: some View {
    GeometryReader { geo in
      let largo = geo.size.width - bus
      let avance = estado.llego ? 1 : min(max(estado.avance, 0), 1)
      let x = bus / 2 + largo * avance
      let xAviso = bus / 2 + largo * min(max(estado.avanceAviso, 0), 1)
      let medio = geo.size.height / 2
      ZStack(alignment: .topLeading) {
        Capsule().fill(recorrido)
          .frame(width: largo, height: grosor)
          .offset(x: bus / 2, y: medio - grosor / 2)
        Capsule().fill(color)
          .frame(width: max(geo.size.width - bus / 2 - x, 0), height: grosor)
          .offset(x: x, y: medio - grosor / 2)
        if !estado.llego {
          Capsule().fill(color)
            .frame(width: marca, height: 10)
            .offset(x: xAviso - marca / 2, y: medio - 5)
        }
        Circle().fill(color)
          .frame(width: punto, height: punto)
          .offset(x: geo.size.width - bus / 2 - punto / 2, y: medio - punto / 2)
        Circle().fill(color)
          .overlay(Circle().stroke(.white, lineWidth: 2.5))
          .frame(width: bus, height: bus)
          .offset(x: x - bus / 2, y: medio - bus / 2)
      }
    }
    .frame(height: 16)
    .accessibilityHidden(true)
  }
}

extension AvisoAtributos {
  var colorFicha: Color {
    Color(
      red: Double((color >> 16) & 0xFF) / 255,
      green: Double((color >> 8) & 0xFF) / 255,
      blue: Double(color & 0xFF) / 255
    )
  }
}
