import SwiftUI

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
    if estado.llego {
      return atributos.ruta.isEmpty ? "Tu bus está cerca de ti" : "Tu bus de la ruta \(atributos.ruta) está cerca de ti"
    }
    return "Tu bus está a \(estado.distancia)"
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
        Ficha(atributos: atributos, alto: 40)
        ContenidoAviso(atributos: atributos, estado: estado, caduco: caduco, tituloGrande: true)
      }
      .opacity(caduco && !estado.llego ? 0.5 : 1)
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
    Ficha(atributos: atributos, alto: 40)
      .padding(.leading, 6)
      .frame(maxHeight: .infinity, alignment: .center)
      .opacity(caduco ? 0.5 : 1)
  }
}

struct IslaCentro: View {
  let atributos: AvisoAtributos
  let estado: AvisoAtributos.ContentState
  let caduco: Bool

  var body: some View {
    Group {
      if estado.llego {
        Text(Textos.titulo(atributos: atributos, estado: estado))
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white)
          .lineLimit(2)
          .multilineTextAlignment(.center)
      } else {
        Text(atributos.ruta.isEmpty ? Textos.titulo(atributos: atributos, estado: estado) : atributos.ruta)
          .font(.headline)
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
    }
    .opacity(caduco ? 0.5 : 1)
  }
}

struct IslaCola: View {
  let atributos: AvisoAtributos
  let estado: AvisoAtributos.ContentState
  let caduco: Bool

  var body: some View {
    Group {
      if estado.llego {
        Image(systemName: "bell.fill")
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(Tinta.verde)
      } else {
        Cifra(texto: estado.distancia, tamano: 26, color: .white, tamanoUnidad: 15, peso: .semibold)
          .fixedSize()
      }
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
    .padding(.trailing, 6)
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

private struct ContenidoAviso: View {
  let atributos: AvisoAtributos
  let estado: AvisoAtributos.ContentState
  let caduco: Bool
  let tituloGrande: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(Textos.titulo(atributos: atributos, estado: estado))
        .font(tituloGrande
          ? .system(size: 20, weight: .semibold, design: .rounded)
          : .title3.weight(.semibold))
        .foregroundStyle(.white)
        .lineLimit(estado.llego ? 2 : 1)
        .minimumScaleFactor(tituloGrande ? 0.8 : 0.75)
        .numericTransition()
      if !estado.llego && !atributos.ruta.isEmpty {
        Text(atributos.ruta)
          .font(tituloGrande ? .system(size: 13, weight: .medium) : .subheadline)
          .foregroundStyle(Tinta.secundaria)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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
      .clipShape(Circle())
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

private struct Ficha: View {
  let atributos: AvisoAtributos; let alto: CGFloat
  var body: some View {
    Group {
      if atributos.codigo.isEmpty { Image(systemName: "bus.fill").font(.system(size: alto * 0.5, weight: .semibold)) }
      else { Text(atributos.codigo).font(.system(size: alto * 0.47, weight: .heavy, design: .rounded)).tracking(-0.2).lineLimit(1) }
    }
    .foregroundStyle(.white).padding(.horizontal, alto * 0.23).frame(minWidth: alto, minHeight: alto, maxHeight: alto).fixedSize()
    // 0,26 del alto crea una ficha compacta con esquinas continuas.
    .background(RoundedRectangle(cornerRadius: alto * 0.26, style: .continuous).fill(atributos.colorFicha))
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

  private let anchoBase: CGFloat = 32
  private let altoBase: CGFloat = 60

  var body: some View {
    Canvas { context, size in
      let escalaX = size.width / anchoBase
      let escalaY = size.height / altoBase
      var dibujo = context
      dibujo.scaleBy(x: escalaX, y: escalaY)

      let capsula = Path(roundedRect: CGRect(x: 0, y: 0, width: anchoBase, height: altoBase), cornerRadius: anchoBase / 2)

      if !caduco {
        dibujo.drawLayer { capa in
          capa.addFilter(.blur(radius: altoBase * 0.04))
          capa.fill(capsula, with: .color(.black.opacity(0.24)))
        }
      }

      if caduco {
        dibujo.fill(capsula, with: .color(.white.opacity(0.35)))
      } else {
        let frente = Color(red: 0xE8 / 255, green: 0x6A / 255, blue: 0x5E / 255)
        let claro = Color(red: 0xEF / 255, green: 0x97 / 255, blue: 0x8E / 255)
        dibujo.fill(
          capsula,
          with: .linearGradient(
            Gradient(colors: [claro, frente]),
            startPoint: CGPoint(x: anchoBase / 2, y: 0),
            endPoint: CGPoint(x: anchoBase / 2, y: altoBase)
          )
        )
      }

      dibujo.stroke(
        capsula,
        with: .color(.white.opacity(caduco ? 0.5 : 0.92)),
        lineWidth: 2.6
      )

      if !caduco {
        var parabrisas = dibujo
        parabrisas.clip(to: capsula)
        let ventana = CGRect(
          x: (anchoBase - anchoBase * 0.72) / 2,
          y: altoBase * 0.26 - altoBase * 0.26 / 2,
          width: anchoBase * 0.72,
          height: altoBase * 0.26
        )
        parabrisas.fill(Path(ellipseIn: ventana), with: .color(.white.opacity(0.3)))
      }
    }
    .frame(width: 18, height: 34)
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

extension AvisoAtributos {
  var colorFicha: Color {
    Color(red: Double((color >> 16) & 0xFF) / 255, green: Double((color >> 8) & 0xFF) / 255, blue: Double(color & 0xFF) / 255)
  }
}
