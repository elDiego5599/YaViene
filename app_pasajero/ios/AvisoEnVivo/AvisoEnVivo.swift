import ActivityKit
import SwiftUI
import WidgetKit

@main
struct AvisoEnVivoBundle: WidgetBundle {
  var body: some Widget { AvisoEnVivo() }
}

struct AvisoEnVivo: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: AvisoAtributos.self) { contexto in
      PantallaBloqueada(contexto: contexto)
        .activityBackgroundTint(.black)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { contexto in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          // La ficha de 34 pt se reconoce al expandir y deja el centro libre.
          Ficha(atributos: contexto.attributes, alto: 34)
            .padding(.leading, 6)
        }
        DynamicIslandExpandedRegion(.trailing) {
          if contexto.state.llego {
            // El glifo de 21 pt mantiene el mismo peso visual que la cifra.
            Image(systemName: "bell.fill")
              .font(.system(size: 21, weight: .semibold))
              .foregroundStyle(Tinta.verde)
          } else {
            Cifra(texto: contexto.state.distancia, tamano: 28)
              .opacity(contexto.isStale ? 0.55 : 1)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 9) {
            Text(Textos.titulo(contexto))
              // 16 pt cabe en una línea de isla y conserva jerarquía sobre la pista.
              .font(.system(size: 16, weight: .semibold, design: .rounded))
              .foregroundStyle(.white)
              .lineLimit(1)
            if !contexto.state.llego {
              Barra(estado: contexto.state)
                .opacity(contexto.isStale ? 0.5 : 1)
            } else {
              Text(Textos.pie(contexto))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
            }
          }
          .padding(.horizontal, 6)
          .padding(.top, 4)
        }
      } compactLeading: {
        // A 20 pt la ficha cabe junto a la cifra en la isla compacta.
        Ficha(atributos: contexto.attributes, alto: 20)
      } compactTrailing: {
        if contexto.state.llego {
          // El símbolo de 13 pt se alinea con la cifra de la presentación compacta.
          Image(systemName: "bell.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Tinta.verde)
        } else {
          // 15 pt mantiene cifra y unidad dentro del ancho compacto.
          Cifra(texto: contexto.state.distancia, tamano: 15)
            .opacity(contexto.isStale ? 0.55 : 1)
        }
      } minimal: {
        if contexto.state.llego {
          // El símbolo de 13 pt deja la actividad mínima reconocible.
          Image(systemName: "bus.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Tinta.bus)
        } else {
          // La ficha mínima de 16 pt conserva el código legible en un punto.
          Ficha(atributos: contexto.attributes, alto: 16)
        }
      }
      .keylineTint(Tinta.verde)
    }
  }
}

enum Tinta {
  static let secundaria = Color(red: 0.58, green: 0.62, blue: 0.69)
  static let apagada = Color(red: 0.23, green: 0.25, blue: 0.29)
  static let verde = Color(red: 0.00, green: 0.66, blue: 0.35)
  static let bus = Color(red: 0.91, green: 0.42, blue: 0.37)
}

enum Textos {
  static func titulo(_ c: ActivityViewContext<AvisoAtributos>) -> String {
    let ruta = c.attributes.ruta
    if c.state.llego {
      return ruta.isEmpty
        ? "Tu bus está cerca de ti" : "Tu bus de la ruta \(ruta) está cerca de ti"
    }
    return ruta.isEmpty ? "Tu bus está en camino" : ruta
  }

  static func pie(_ c: ActivityViewContext<AvisoAtributos>) -> String {
    if c.state.llego { return "" }
    if c.isStale { return "Sin datos nuevos, abre Ya Viene" }
    return c.state.aviso
  }
}

struct PantallaBloqueada: View {
  let contexto: ActivityViewContext<AvisoAtributos>

  var body: some View {
    // La fila de 38 pt iguala la ficha a un renglón cómodo y los 18 pt
    // laterales mantienen el contenido dentro del margen del sistema.
    VStack(alignment: .leading, spacing: 17) {
      HStack(alignment: .center, spacing: 12) {
        Ficha(atributos: contexto.attributes, alto: 38)
        VStack(alignment: .leading, spacing: 3) {
          Text(Textos.titulo(contexto))
            // 17 pt distingue la ruta del rótulo de los extremos.
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(2)
          if !contexto.state.llego {
            // «Te avisamos a 1,0 km», o que faltan datos.
            Text(Textos.pie(contexto))
              // 13 pt deja el aviso un nivel bajo la ruta.
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(Tinta.secundaria)
              .lineLimit(1)
          }
        }
        Spacer(minLength: 4)
        if !contexto.state.llego {
          Cifra(texto: contexto.state.distancia, tamano: 34)
            .opacity(contexto.isStale ? 0.55 : 1)
        }
      }
      if !contexto.state.llego {
        Barra(estado: contexto.state)
          .opacity(contexto.isStale ? 0.5 : 1)
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 17)
    .frame(maxWidth: .infinity, alignment: .leading)
    .activityBackgroundTint(.black)
  }
}

struct Cifra: View {
  let texto: String
  let tamano: CGFloat
  var conUnidad = true

  var body: some View {
    let partes = texto.split(separator: " ", maxSplits: 1).map(String.init)
    let numero = partes.first ?? texto
    let unidad = partes.count > 1 ? partes[1] : ""
    // El 8 % separa cifra y unidad sin partirlas visualmente.
    let base = HStack(alignment: .firstTextBaseline, spacing: tamano * 0.08) {
      Text(numero)
        .font(.system(size: tamano, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
      if conUnidad && !unidad.isEmpty {
        Text(unidad)
          // La unidad al 48 % mantiene la cifra como primer nivel.
          .font(.system(size: tamano * 0.48, weight: .semibold, design: .rounded))
          .foregroundStyle(Tinta.secundaria)
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

struct Ficha: View {
  let atributos: AvisoAtributos
  let alto: CGFloat

  var body: some View {
    // El código ocupa cerca de media altura; el relleno lateral de 23 % y
    // el radio de 25 % mantienen la proporción de la ficha existente. El
    // tracking de 0,2 pt evita que los códigos de tres caracteres se abran.
    Group {
      if atributos.codigo.isEmpty {
        Image(systemName: "bus.fill")
          .font(.system(size: alto * 0.5, weight: .semibold))
      } else {
        Text(atributos.codigo)
          .font(.system(size: alto * 0.49, weight: .heavy, design: .rounded))
          .tracking(-0.2)
          .lineLimit(1)
      }
    }
    .foregroundStyle(.white)
    .padding(.horizontal, alto * 0.23)
    .frame(minWidth: alto, minHeight: alto, maxHeight: alto)
    // 0,25 del alto suaviza el código sin convertir la ficha en una píldora.
    .background(
      RoundedRectangle(cornerRadius: alto * 0.25, style: .continuous)
        .fill(atributos.colorFicha))
  }
}

struct Barra: View {
  let estado: AvisoAtributos.ContentState

  // 30 pt deja respirar al bus y el carril de 9 pt sigue legible en la isla.
  private let bus: CGFloat = 30
  private let pista: CGFloat = 9

  var body: some View {
    VStack(spacing: 5) {
      GeometryReader { geo in
        let inicio = bus / 2
        let fin = geo.size.width - bus / 2
        let largo = max(fin - inicio, 0)
        let avance = min(max(estado.avance, 0), 1)
        let x = inicio + largo * avance
        ZStack(alignment: .topLeading) {
          Capsule().fill(Tinta.apagada)
            .frame(width: largo, height: pista)
            .offset(x: inicio, y: (geo.size.height - pista) / 2)
          Capsule().fill(Tinta.verde)
            .frame(width: max(largo * avance, 0), height: pista)
            .offset(x: inicio, y: (geo.size.height - pista) / 2)
          // La marca de dónde va a sonar, mientras el bus no la pase.
          let xAviso = inicio + largo * min(max(estado.avanceAviso, 0), 1)
          if xAviso > x + bus / 2 && xAviso < fin - pista {
            Capsule().fill(.white)
              .frame(width: 3, height: pista + 8)
              .offset(x: xAviso - 1.5, y: (geo.size.height - pista - 8) / 2)
          }
          // Tu punto al final de la pista, como el destino de Uber.
          Circle().fill(.white)
            .overlay(Circle().fill(Tinta.verde).padding(4))
            .frame(width: pista + 7, height: pista + 7)
            .offset(x: fin - (pista + 7) / 2, y: (geo.size.height - pista - 7) / 2)
          Circle()
            .fill(Tinta.bus)
            // El borde de 2 pt separa el bus del carril negro.
            .overlay(Circle().stroke(.black, lineWidth: 2))
            .overlay(Image(systemName: "bus.fill")
              // 14 pt es la mitad del círculo y deja aire alrededor del glifo.
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(.white))
            .frame(width: bus, height: bus)
            .offset(x: x - bus / 2, y: (geo.size.height - bus) / 2)
        }
      }
      .frame(height: bus)
      HStack {
        Text("Bus")
        Spacer()
        Text("Tu punto")
      }
      // 11 pt deja los extremos secundarios frente a la cifra principal.
      .font(.system(size: 11, weight: .medium, design: .rounded))
      .foregroundStyle(Tinta.secundaria)
    }
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
