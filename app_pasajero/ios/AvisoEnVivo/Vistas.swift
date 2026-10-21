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

  static func subtitulo(atributos: AvisoAtributos) -> String {
    switch (atributos.ruta.isEmpty, atributos.placa.isEmpty) {
    case (false, false): "\(atributos.ruta) · \(atributos.placa)"
    case (false, true): atributos.ruta
    case (true, false): atributos.placa
    case (true, true): ""
    }
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
    VStack(alignment: .leading, spacing: 16) {
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
      // Abierta, la isla muestra el logo, la distancia y debajo la ruta con
      // la placa, igual que la pantalla bloqueada (dueño, 2026-10-21).
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
    .padding(.top, 4)
    .padding(.horizontal, 8)
    .padding(.bottom, 4)
  }
}

struct ContenidoAviso: View {
  let atributos: AvisoAtributos
  let estado: AvisoAtributos.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(Textos.titulo(atributos: atributos, estado: estado))
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(.white)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .numericTransition()
      let subtitulo = Textos.subtitulo(atributos: atributos)
      if !subtitulo.isEmpty {
        Text(subtitulo)
          .font(.subheadline)
          .foregroundStyle(Tinta.secundaria)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
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
          AutobusDesdeArriba(caduco: caduco).frame(width: 34, height: 18).position(x: centroBus, y: altura / 2)
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

private struct AutobusDesdeArriba: View {
  var caduco = false

  private let anchoBase: CGFloat = 34
  private let altoBase: CGFloat = 80

  var body: some View {
    Canvas { context, size in
      let escalaX = size.width / anchoBase
      let escalaY = size.height / altoBase
      var dibujo = context
      dibujo.scaleBy(x: escalaX, y: escalaY)

      let carroceria = Path(roundedRect: CGRect(x: 0, y: 0, width: anchoBase, height: altoBase), cornerRadius: 8)

      if !caduco {
        dibujo.drawLayer { capa in
          // Sombra de contacto gris, centrada y sin dirección como en el mapa.
          capa.addFilter(.blur(radius: 3.2))
          capa.fill(carroceria, with: .color(Color(red: 0x30 / 255, green: 0x34 / 255, blue: 0x3B / 255).opacity(0.30)))
        }
      }

      if caduco {
        dibujo.fill(carroceria, with: .color(Color(red: 0x94 / 255, green: 0xA3 / 255, blue: 0xB8 / 255).opacity(0.58)))
      } else {
        // El rojo lleno y encima la luz: blanco al 34 % a la izquierda, nada
        // al 58 % y negro al 25 % a la derecha, el mismo lerp del mapa.
        dibujo.fill(carroceria, with: .color(Tinta.rojoBus))
        dibujo.fill(
          carroceria,
          with: .linearGradient(
            Gradient(stops: [
              .init(color: .white.opacity(0.34), location: 0),
              .init(color: .clear, location: 0.58),
              .init(color: .black.opacity(0.25), location: 1),
            ]),
            startPoint: .zero,
            endPoint: CGPoint(x: anchoBase, y: 0)
          )
        )
      }

      dibujo.stroke(
        carroceria,
        with: .color(.white.opacity(caduco ? 0.5 : 0.92)),
        lineWidth: 1.3
      )

      if !caduco {
        var techo = dibujo
        techo.clip(to: carroceria)
        let vidrio = Color(red: 0x17 / 255, green: 0x29 / 255, blue: 0x36 / 255)
        let parabrisas = Path(roundedRect: CGRect(x: 4, y: 5, width: 26, height: 15), cornerRadius: 5)
        techo.fill(parabrisas, with: .linearGradient(Gradient(colors: [vidrio, Color(red: 0x34 / 255, green: 0x4D / 255, blue: 0x5C / 255)]), startPoint: CGPoint(x: 7, y: 5), endPoint: CGPoint(x: 27, y: 20)))
        techo.fill(Path(roundedRect: CGRect(x: 7, y: 7, width: 12, height: 2), cornerRadius: 1), with: .color(.white.opacity(0.48)))
        techo.fill(Path(roundedRect: CGRect(x: 8, y: 67, width: 18, height: 7), cornerRadius: 3), with: .color(Color(red: 0x25 / 255, green: 0x3A / 255, blue: 0x47 / 255)))
        for y: CGFloat in [28, 40] {
          let tapa = Path(roundedRect: CGRect(x: 7, y: y, width: 20, height: 8), cornerRadius: 2)
          techo.fill(tapa, with: .color(Color.black.opacity(0.24)))
          for linea in [y + 2, y + 4, y + 6] {
            techo.stroke(Path { $0.move(to: CGPoint(x: 10, y: linea)); $0.addLine(to: CGPoint(x: 24, y: linea)) }, with: .color(.white.opacity(0.20)), lineWidth: 0.8)
          }
        }
        for x: CGFloat in [4, 30] {
          techo.fill(Path(roundedRect: CGRect(x: x - 1.1, y: 2, width: 2.2, height: 3), cornerRadius: 1), with: .color(Color(red: 1, green: 0.95, blue: 0.76)))
        }
      } else {
        dibujo.fill(Path(roundedRect: CGRect(x: 7, y: 9, width: 20, height: 62), cornerRadius: 4), with: .color(.white.opacity(0.10)))
      }
    }
    .frame(width: 14.45, height: 34)
    .rotationEffect(.degrees(90))
    .frame(width: 34, height: 18)
    .accessibilityHidden(true)
  }
}

private extension View {
  @ViewBuilder func numericTransition() -> some View {
    if #available(iOS 17.0, *) { self.contentTransition(.numericText()) } else { self }
  }
}
