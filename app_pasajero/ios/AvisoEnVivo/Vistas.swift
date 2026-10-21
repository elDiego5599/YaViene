import SwiftUI
import Foundation

func urlAviso(busId: String, routeId: String?) -> URL? {
  guard let routeId, !routeId.isEmpty else { return nil }
  var componentes = URLComponents()
  componentes.scheme = "yaviene"
  componentes.host = "aviso"
  componentes.queryItems = [
    URLQueryItem(name: "busId", value: busId),
    URLQueryItem(name: "routeId", value: routeId),
  ]
  return componentes.url
}

enum Tinta {
  static let secundaria = Color(red: 0x9B / 255, green: 0xA3 / 255, blue: 0xAF / 255)
  static let carril = Color.white.opacity(0.16)
  static let verde = Color(red: 0x00, green: 0xA8 / 255, blue: 0x59 / 255)
  static let rojoBus = Color(red: 0xE8 / 255, green: 0x6A / 255, blue: 0x5E / 255)
  static let vidrio = Color(red: 0x1A / 255, green: 0x1D / 255, blue: 0x22 / 255)
  static let nodo = Color(red: 0x2A / 255, green: 0x2E / 255, blue: 0x35 / 255)
}

enum Textos {
  static func titulo(atributos: AvisoAtributos, estado: AvisoAtributos.ContentState) -> String {
    estado.llego ? "Tu bus está cerca de ti" : "Está a \(estado.distancia) de ti"
  }

  static func accesibilidad(atributos: AvisoAtributos, estado: AvisoAtributos.ContentState) -> String {
    if estado.llego { return Textos.titulo(atributos: atributos, estado: estado) }
    let ruta = atributos.ruta.isEmpty ? "tu ruta" : "Ruta \(atributos.ruta)"
    return "\(ruta), tu bus está a \(estado.distancia), \(estado.aviso)"
  }
}

struct TarjetaBloqueada: View {
  let atributos: AvisoAtributos
  let estado: AvisoAtributos.ContentState
  let caduco: Bool

  var body: some View {
    // 22 entre el texto y la pista: el bus de lado asoma 4 sobre ella y con
    // 16 la línea quedaba pegada al título (dueño, 2026-10-21).
    VStack(alignment: .leading, spacing: 22) {
      HStack(spacing: 12) {
        LogoYaViene(lado: 40)
        ContenidoAviso(atributos: atributos, estado: estado)
      }
      .opacity(caduco ? 0.5 : 1)
      Pista(
        atributos: atributos,
        estado: estado,
        muestraRotulos: !estado.llego,
        caduco: caduco
      )
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.black)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(Textos.accesibilidad(atributos: atributos, estado: estado)))
  }
}

struct IslaLider: View {
  let atributos: AvisoAtributos
  let estado: AvisoAtributos.ContentState
  let caduco: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      // Abierta, la isla muestra el logo y la distancia, igual que la
      // pantalla bloqueada (dueño, 2026-10-21).
      LogoYaViene(lado: 44)
      ContenidoAviso(atributos: atributos, estado: estado)
    }
      .fixedSize(horizontal: true, vertical: false)
      .padding(.leading, 6)
      .frame(maxHeight: .infinity, alignment: .center)
      .opacity(caduco ? 0.5 : 1)
  }
}

struct IslaAbajo: View {
  let atributos: AvisoAtributos
  let estado: AvisoAtributos.ContentState
  let caduco: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Pista(atributos: atributos, estado: estado, muestraRotulos: false, caduco: caduco)
        .padding(.horizontal, 4)
      if !estado.llego {
        RotulosPista(estado: estado, caduco: caduco)
      }
    }
    // 10 arriba: los 4 de antes más los 4 que el bus asoma sobre la pista,
    // y la línea un poco más abajo (dueño, 2026-10-21).
    .padding(.top, 10)
    .padding(.horizontal, 8)
    .padding(.bottom, 4)
  }
}

struct ContenidoAviso: View {
  let atributos: AvisoAtributos
  let estado: AvisoAtributos.ContentState

  var body: some View {
    // Solo la distancia, sin la ruta ni la placa debajo (dueño, 2026-10-21).
    VStack(alignment: .leading, spacing: 2) {
      Text(Textos.titulo(atributos: atributos, estado: estado))
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.white)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .numericTransition()
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}

struct CompactaLider: View {
  let atributos: AvisoAtributos; let estado: AvisoAtributos.ContentState; let caduco: Bool
  var body: some View { LogoYaViene(lado: 22).opacity(caduco ? 0.5 : 1) }
}

struct CompactaCola: View {
  let atributos: AvisoAtributos; let estado: AvisoAtributos.ContentState; let caduco: Bool
  var body: some View {
    Group {
      if estado.llego { Image(systemName: "bell.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(Tinta.verde) }
      else { Cifra(texto: estado.distancia, tamano: 15, color: Tinta.verde, tamanoUnidad: 11).opacity(caduco ? 0.5 : 1) }
    }
  }
}

struct Minima: View {
  let atributos: AvisoAtributos; let estado: AvisoAtributos.ContentState; let caduco: Bool
  var body: some View {
    Group {
      if estado.llego {
        Image(systemName: "bell.fill")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Tinta.verde)
      } else {
        LogoYaViene(lado: 20)
      }
    }
    .opacity(caduco ? 0.5 : 1)
  }
}

private struct LogoYaViene: View {
  let lado: CGFloat

  var body: some View {
    Image("LogoYaViene")
      .resizable()
      .frame(width: lado, height: lado)
      // Cuadradito como el ícono de la app: esquinas continuas al 22,5 %
      // del lado, la proporción del ícono de iOS (dueño, 2026-10-21).
      .clipShape(RoundedRectangle(cornerRadius: lado * 0.225, style: .continuous))
  }
}

private struct Cifra: View {
  let texto: String; let tamano: CGFloat; var color: Color; var conUnidad = true; var tamanoUnidad: CGFloat? = nil; var peso: Font.Weight = .bold
  var body: some View {
    let partes = texto.split(separator: " ", maxSplits: 1).map(String.init)
    HStack(alignment: .firstTextBaseline, spacing: 3) {
      Text(partes.first ?? texto).font(.system(size: tamano, weight: peso, design: .rounded)).monospacedDigit().foregroundStyle(color)
      if conUnidad && partes.count > 1 {
        // 13 pt en la isla amplia separa unidad y cifra con jerarquía suave.
        Text(partes[1]).font(.system(size: tamanoUnidad ?? (tamano == 24 ? 13 : tamano * 0.72), weight: .semibold)).foregroundStyle(Tinta.secundaria)
      }
    }.lineLimit(1).numericTransition()
  }
}

private struct Pista: View {
  let atributos: AvisoAtributos; let estado: AvisoAtributos.ContentState; var muestraRotulos: Bool
  var caduco = false
  private let altura: CGFloat = 22
  var body: some View {
    VStack(spacing: muestraRotulos ? 16 : 5) {
      GeometryReader { geo in
        let w = geo.size.width
        let inicio: CGFloat = 3
        let fin = max(w - 7, inicio)
        let avance = estado.llego ? 1.0 : min(max(estado.avance, 0), 1)
        let desplazamiento = inicio + (fin - inicio) * avance
        let centroBus = estado.llego ? fin - 25 : min(max(desplazamiento, inicio + 17), fin - 17)
        let xBus = centroBus
        let xAviso = inicio + (fin - inicio) * min(max(estado.avanceAviso, 0), 1)
        ZStack(alignment: .leading) {
          Capsule().fill(Tinta.carril).frame(height: 6).position(x: w / 2, y: altura / 2)
          Capsule().fill(caduco ? Color.white.opacity(0.28) : Tinta.verde).frame(width: max(desplazamiento, inicio), height: 6)
            .shadow(color: caduco ? .clear : Tinta.verde.opacity(0.5), radius: 6)
            .position(x: max(desplazamiento, inicio) / 2, y: altura / 2)
          Circle().fill(.white).frame(width: 6, height: 6).position(x: inicio, y: altura / 2)
          if !estado.llego && abs(xAviso - xBus) >= 22 && abs(fin - xAviso) >= 22 {
            Circle().fill(xBus >= xAviso ? Tinta.verde : Tinta.nodo)
              .overlay(Image(systemName: "bell.fill").font(.system(size: 8, weight: .semibold)).foregroundStyle(.white))
              .frame(width: 16, height: 16).position(x: xAviso, y: altura / 2)
          }
          Circle().fill(caduco ? Color.white.opacity(0.35) : Tinta.verde).frame(width: 14, height: 14)
            .overlay(Circle().stroke(caduco ? Color.white.opacity(0.2) : .white, lineWidth: 2.5).padding(0.5))
            .overlay(Circle().stroke(caduco ? Color.clear : Tinta.verde.opacity(0.6), lineWidth: 1).padding(-3))
            .position(x: fin, y: altura / 2)
          // Las ruedas sobre la pista: su borde de abajo cae 15,25 bajo el
          // tope del bus de 16, así que el centro va 7 sobre la línea.
          AutobusDeLado(caduco: caduco).frame(width: 34, height: 16).position(x: centroBus, y: altura / 2 - 7)
        }
      }
      .frame(height: altura)
      if muestraRotulos && !estado.llego {
        RotulosPista(estado: estado, caduco: caduco)
      }
    }.accessibilityHidden(true)
  }
}


private struct RotulosPista: View {
  let estado: AvisoAtributos.ContentState
  let caduco: Bool

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "bell.fill")
        .font(.system(size: 10, weight: .semibold))
      Text(caduco ? "Sin datos nuevos, abre Ya Viene" : estado.aviso)
        .lineLimit(1)
        .minimumScaleFactor(0.9)
        .layoutPriority(1)
      Spacer(minLength: 4)
      Text("Tu punto")
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
    // Subheadline iguala ambas etiquetas a la fila de la tarjeta.
    .font(.subheadline)
    .foregroundStyle(Tinta.secundaria)
  }
}

/// El bus de la actividad en vivo, visto de lado con el frente a la
/// derecha, hacia tu punto (dueño, 2026-10-21). Solo vive aquí: en el mapa
/// sigue la cápsula de `createFlatTransitMarker`. Dibujado en 68 × 32 y
/// pintado a la mitad, 34 × 16 pt.
private struct AutobusDeLado: View {
  var caduco = false

  private let ancho: CGFloat = 68
  private let alto: CGFloat = 32

  var body: some View {
    Canvas { context, size in
      var d = context
      d.scaleBy(x: size.width / ancho, y: size.height / alto)

      // Carrocería: la trasera casi recta (radio 4) y el frente más romo
      // arriba (9), como el morro de un bus urbano.
      let caja = Path(
        roundedRect: CGRect(x: 1, y: 3, width: 66, height: 23),
        cornerRadii: RectangleCornerRadii(topLeading: 4, bottomLeading: 3, bottomTrailing: 3, topTrailing: 9),
        style: .continuous
      )
      let rojo = caduco ? Color(red: 0x5C / 255, green: 0x61 / 255, blue: 0x69 / 255) : Tinta.rojoBus
      d.fill(caja, with: .color(rojo))
      // Luz de arriba: el techo 22 % más claro y el faldón 22 % más oscuro.
      d.fill(
        caja,
        with: .linearGradient(
          Gradient(stops: [
            .init(color: .white.opacity(0.22), location: 0),
            .init(color: .clear, location: 0.45),
            .init(color: .black.opacity(0.22), location: 1),
          ]),
          startPoint: CGPoint(x: 0, y: 3),
          endPoint: CGPoint(x: 0, y: 26)
        )
      )

      var dentro = d
      dentro.clip(to: caja)
      let vidrio = caduco ? Color(red: 0x2A / 255, green: 0x2E / 255, blue: 0x35 / 255) : Tinta.vidrio
      // Cinco ventanas de pasajeros de 7 con parales de 2.
      for i in 0..<5 {
        let x = 5 + CGFloat(i) * 9
        dentro.fill(Path(roundedRect: CGRect(x: x, y: 7, width: 7, height: 8), cornerRadius: 1.5), with: .color(vidrio))
      }
      // La puerta de adelante, de dos hojas, hasta el faldón.
      dentro.fill(Path(roundedRect: CGRect(x: 50, y: 7, width: 6, height: 16), cornerRadius: 1.5), with: .color(vidrio))
      dentro.fill(Path(CGRect(x: 52.75, y: 7, width: 0.5, height: 16)), with: .color(rojo.opacity(0.9)))
      // El parabrisas, alto, siguiendo el morro.
      dentro.fill(
        Path(roundedRect: CGRect(x: 58, y: 6, width: 8, height: 12),
             cornerRadii: RectangleCornerRadii(topLeading: 1.5, bottomLeading: 1.5, bottomTrailing: 1, topTrailing: 6),
             style: .continuous),
        with: .color(vidrio)
      )
      if !caduco {
        // Reflejo diagonal en el vidrio: blanco al 18 %.
        for x: CGFloat in [6, 24, 59] {
          dentro.fill(Path { p in
            p.move(to: CGPoint(x: x + 3, y: 7)); p.addLine(to: CGPoint(x: x + 5, y: 7))
            p.addLine(to: CGPoint(x: x + 2, y: 15)); p.addLine(to: CGPoint(x: x, y: 15))
          }, with: .color(.white.opacity(0.18)))
        }
        // Una franja blanca a lo largo, bajo las ventanas.
        dentro.fill(Path(CGRect(x: 1, y: 17, width: 49, height: 1.2)), with: .color(.white.opacity(0.55)))
        // Faro adelante y piloto atrás.
        dentro.fill(Path(roundedRect: CGRect(x: 64, y: 20, width: 3, height: 2.4), cornerRadius: 1), with: .color(Color(red: 1, green: 0.95, blue: 0.76)))
        dentro.fill(Path(roundedRect: CGRect(x: 1, y: 19, width: 2, height: 3), cornerRadius: 0.8), with: .color(Color(red: 0.55, green: 0.08, blue: 0.08)))
      }

      // Ruedas con su arco negro (el fondo de la tarjeta) y el rin gris.
      for x: CGFloat in [14, 54] {
        d.fill(Path(ellipseIn: CGRect(x: x - 6, y: 20, width: 12, height: 12)), with: .color(.black))
        d.fill(Path(ellipseIn: CGRect(x: x - 4.5, y: 21.5, width: 9, height: 9)), with: .color(Tinta.nodo))
        d.fill(Path(ellipseIn: CGRect(x: x - 2, y: 24, width: 4, height: 4)), with: .color(Tinta.secundaria.opacity(caduco ? 0.5 : 1)))
      }
    }
    .accessibilityHidden(true)
  }
}

private extension View {
  @ViewBuilder func numericTransition() -> some View {
    if #available(iOS 17.0, *) { self.contentTransition(.numericText()) } else { self }
  }
}
