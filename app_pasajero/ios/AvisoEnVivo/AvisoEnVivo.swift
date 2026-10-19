import ActivityKit
import SwiftUI
import WidgetKit

/// La actividad en vivo de un aviso armado: la pantalla bloqueada y la
/// Dynamic Island (dueño, 2026-10-19). La ficha de la ruta, la cifra de la
/// hoja y la barra de lo que falta, con la marca donde va a sonar; la ruta
/// en el verde del mapa y el bus en su rojo.
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
        // Sobre el negro de la isla la ficha va en blanco con su código en
        // el color de la empresa: los colores de las empresas son oscuros y
        // sobre negro no se leían (dueño, 2026-10-19).
        DynamicIslandExpandedRegion(.leading) {
          Ficha(atributos: contexto.attributes, alto: 30, sobreNegro: true)
            .padding(.leading, 6)
            .padding(.top, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Group {
            if contexto.state.llego {
              Image(systemName: "bell.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Tinta.verde)
            } else {
              Cifra(
                texto: contexto.state.distancia, tamano: 30,
                tinta: contexto.isStale ? .white.opacity(0.5) : .white,
                tintaUnidad: .white.opacity(0.6))
            }
          }
          .padding(.trailing, 6)
          .padding(.top, 2)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
              Text(Textos.titulo(contexto))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
              if !contexto.state.llego {
                Text(Textos.pie(contexto))
                  .font(.system(size: 13, weight: .medium))
                  .foregroundStyle(.white.opacity(0.6))
                  .lineLimit(1)
              }
            }
            Barra(estado: contexto.state, recorrido: .white.opacity(0.22))
              .opacity(contexto.isStale ? 0.5 : 1)
          }
          .padding(.horizontal, 6)
          .padding(.top, 6)
        }
      } compactLeading: {
        Ficha(atributos: contexto.attributes, alto: 20, sobreNegro: true)
          .padding(.leading, 2)
      } compactTrailing: {
        if contexto.state.llego {
          Image(systemName: "bell.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Tinta.verde)
        } else {
          Cifra(
            texto: contexto.state.distancia, tamano: 15,
            tinta: contexto.isStale ? .white.opacity(0.5) : Tinta.verde,
            tintaUnidad: (contexto.isStale ? Color.white : Tinta.verde).opacity(0.7))
        }
      } minimal: {
        if contexto.state.llego {
          Image(systemName: "bell.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Tinta.verde)
        } else {
          Cifra(
            texto: contexto.state.distancia, tamano: 14,
            tinta: Tinta.verde, tintaUnidad: Tinta.verde, conUnidad: false)
        }
      }
      .keylineTint(Tinta.verde)
    }
  }
}

/// La tinta de la app.
enum Tinta {
  /// `AppColors.textPrimary`.
  static let principal = Color(red: 0x0F / 255, green: 0x17 / 255, blue: 0x2A / 255)
  /// `AppColors.textSecondary`.
  static let secundaria = Color(red: 0x5E / 255, green: 0x6B / 255, blue: 0x82 / 255)
  /// Lo que el bus ya dejó atrás (`AppColors.divider`).
  static let recorrido = Color(red: 0xE5 / 255, green: 0xE7 / 255, blue: 0xEB / 255)
  /// La ruta del mapa (`AppColors.primary`, `EstiloRuta`): 6,9:1 sobre el
  /// negro de la isla.
  static let verde = Color(red: 0x00 / 255, green: 0xA8 / 255, blue: 0x59 / 255)
  /// El bus del mapa (`AppColors.busActive`).
  static let bus = Color(red: 0xE8 / 255, green: 0x6A / 255, blue: 0x5E / 255)
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

/// Como la de un viaje en Uber o un vuelo en Flighty: arriba la ficha, la
/// ruta y la cifra grande; abajo el bus en camino a tu punto.
struct PantallaBloqueada: View {
  let contexto: ActivityViewContext<AvisoAtributos>

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .center, spacing: 12) {
        Ficha(atributos: contexto.attributes, alto: 36, sobreNegro: false)
        VStack(alignment: .leading, spacing: 2) {
          Text(Textos.titulo(contexto))
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Tinta.principal)
            .lineLimit(2)
          if !contexto.state.llego {
            Text(Textos.pie(contexto))
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(Tinta.secundaria)
              .lineLimit(1)
          }
        }
        Spacer(minLength: 8)
        if !contexto.state.llego {
          Cifra(
            texto: contexto.state.distancia, tamano: 32,
            tinta: contexto.isStale ? Tinta.secundaria : Tinta.principal,
            tintaUnidad: Tinta.secundaria)
        }
      }
      Barra(estado: contexto.state, recorrido: Tinta.recorrido)
        .opacity(contexto.isStale ? 0.5 : 1)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
  }
}

/// La cifra de la distancia («10,6 km»): el número grande y redondo, la
/// unidad más chica, como la hoja. Rueda al cambiar.
struct Cifra: View {
  let texto: String
  let tamano: CGFloat
  let tinta: Color
  let tintaUnidad: Color
  var conUnidad = true

  var body: some View {
    let partes = texto.split(separator: " ", maxSplits: 1).map(String.init)
    let numero = partes.first ?? texto
    let unidad = partes.count > 1 ? partes[1] : ""
    let base = HStack(alignment: .firstTextBaseline, spacing: tamano * 0.1) {
      Text(numero)
        .font(.system(size: tamano, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(tinta)
      if conUnidad && !unidad.isEmpty {
        Text(unidad)
          .font(.system(size: tamano * 0.55, weight: .semibold, design: .rounded))
          .foregroundStyle(tintaUnidad)
      }
    }
    .lineLimit(1)
    .minimumScaleFactor(0.6)
    if #available(iOS 17.0, *) {
      base.contentTransition(.numericText())
    } else {
      base
    }
  }
}

/// La ficha de la ruta (`ficha_ruta.dart`): su código sobre el color de la
/// empresa. Sobre el negro de la isla se invierte: blanca, con el código en
/// el color de la empresa, como un letrero de parada.
struct Ficha: View {
  let atributos: AvisoAtributos
  let alto: CGFloat
  let sobreNegro: Bool

  var body: some View {
    let fondo = sobreNegro ? Color.white : atributos.colorFicha
    let letra = sobreNegro ? atributos.colorFicha : Color.white
    Group {
      if atributos.codigo.isEmpty {
        Image(systemName: "bus.fill")
          .font(.system(size: alto * 0.5, weight: .semibold))
      } else {
        Text(atributos.codigo)
          .font(.system(size: alto * 0.5, weight: .heavy, design: .rounded))
          .tracking(-0.2)
          .lineLimit(1)
      }
    }
    .foregroundStyle(letra)
    .padding(.horizontal, alto * 0.24)
    .frame(minWidth: alto, minHeight: alto, maxHeight: alto)
    .background(
      RoundedRectangle(cornerRadius: alto * 0.26, style: .continuous).fill(fondo))
  }
}

/// La barra de lo que falta: 3 km que acaban en tu punto. La ruta en el
/// verde del mapa, más tenue lo que el bus ya dejó atrás, el bus en su rojo
/// con su ícono, y la marca de dónde va a sonar.
struct Barra: View {
  let estado: AvisoAtributos.ContentState
  let recorrido: Color

  private let bus: CGFloat = 22
  private let punto: CGFloat = 20
  private let grosor: CGFloat = 5

  var body: some View {
    GeometryReader { geo in
      let inicio = bus / 2
      let fin = geo.size.width - punto / 2
      let largo = fin - inicio
      let avance = estado.llego ? 1 : min(max(estado.avance, 0), 1)
      let x = inicio + largo * avance
      let xAviso = inicio + largo * min(max(estado.avanceAviso, 0), 1)
      let medio = geo.size.height / 2
      ZStack(alignment: .topLeading) {
        Capsule().fill(recorrido)
          .frame(width: largo, height: grosor)
          .offset(x: inicio, y: medio - grosor / 2)
        Capsule().fill(Tinta.verde)
          .frame(width: max(fin - x, 0), height: grosor)
          .offset(x: x, y: medio - grosor / 2)
        if !estado.llego && xAviso > x + bus / 2 {
          Capsule().fill(.white)
            .frame(width: 3, height: grosor + 6)
            .overlay(Capsule().stroke(Tinta.verde, lineWidth: 1.5))
            .offset(x: xAviso - 1.5, y: medio - (grosor + 6) / 2)
        }
        Image(systemName: "mappin.circle.fill")
          .font(.system(size: punto, weight: .semibold))
          .symbolRenderingMode(.palette)
          .foregroundStyle(.white, Tinta.verde)
          .frame(width: punto, height: punto)
          .offset(x: fin - punto / 2, y: medio - punto / 2)
        Circle().fill(Tinta.bus)
          .overlay(
            Image(systemName: "bus.fill")
              .font(.system(size: bus * 0.5, weight: .bold))
              .foregroundStyle(.white))
          .overlay(Circle().stroke(.white, lineWidth: 2))
          .frame(width: bus, height: bus)
          .offset(x: x - bus / 2, y: medio - bus / 2)
      }
    }
    .frame(height: 24)
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
