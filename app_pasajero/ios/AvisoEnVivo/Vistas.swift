import SwiftUI

enum Tinta {
  static let secundaria = Color(red: 0x9B / 255, green: 0xA3 / 255, blue: 0xAF / 255)
  static let carril = Color.white.opacity(0.16)
  static let verde = Color(red: 0x00, green: 0xA8 / 255, blue: 0x59 / 255)
  static let rojoBus = Color(red: 0xE5 / 255, green: 0x53 / 255, blue: 0x4B / 255)
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
        VStack(alignment: .leading, spacing: 2) {
          Text(Textos.titulo(atributos: atributos, estado: estado))
            // 20 pt da jerarquía al dato principal y cabe en una línea.
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(estado.llego ? 2 : 1)
            .minimumScaleFactor(0.8)
            .numericTransition()
          if !estado.llego && !atributos.ruta.isEmpty {
            // 13 pt mantiene la ruta como contexto secundario.
            Text(atributos.ruta).font(.system(size: 13, weight: .medium)).foregroundStyle(Tinta.secundaria).lineLimit(1)
          }
        }
      }
      .opacity(caduco && !estado.llego ? 0.5 : 1)
      if !estado.llego {
        Pista(atributos: atributos, estado: estado, muestraRotulos: false, caduco: caduco)
        HStack {
          Image(systemName: "bell.fill")
            // 10 pt deja el icono del aviso discreto junto al rótulo.
            .font(.system(size: 10, weight: .semibold))
          Text(caduco ? "Sin datos nuevos, abre Ya Viene" : estado.aviso)
          Spacer()
          Text("Tu punto")
        }
        // 12 pt permite leer los rótulos sin competir con la distancia.
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Tinta.secundaria)
      } else {
        Pista(atributos: atributos, estado: estado, muestraRotulos: false)
      }
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
  let atributos: AvisoAtributos; let estado: AvisoAtributos.ContentState; let caduco: Bool
  var body: some View { Ficha(atributos: atributos, alto: 30).padding(.leading, 4).opacity(caduco ? 0.5 : 1) }
}

struct IslaCola: View {
  let atributos: AvisoAtributos; let estado: AvisoAtributos.ContentState; let caduco: Bool
  var body: some View {
    Group {
      if estado.llego { Image(systemName: "bell.fill").font(.system(size: 20, weight: .semibold)).foregroundStyle(Tinta.verde) }
      else { Cifra(texto: estado.distancia, tamano: 24, color: .white).opacity(caduco ? 0.5 : 1) }
    }
  }
}

struct IslaCentro: View {
  let atributos: AvisoAtributos; let estado: AvisoAtributos.ContentState; let caduco: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(estado.llego ? "Está cerca de ti" : atributos.ruta)
        // 14 pt conserva el nombre de ruta en una línea en la isla.
        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
      if estado.llego && !atributos.ruta.isEmpty {
        // 11 pt añade contexto de ruta sin llenar de nuevo la isla.
        Text(atributos.ruta).font(.system(size: 11, weight: .medium)).foregroundStyle(Tinta.secundaria).lineLimit(1)
      }
    }
    .opacity(caduco && !estado.llego ? 0.5 : 1)
  }
}

struct IslaAbajo: View {
  let atributos: AvisoAtributos; let estado: AvisoAtributos.ContentState; let caduco: Bool
  var body: some View {
    if !estado.llego {
      Pista(atributos: atributos, estado: estado, muestraRotulos: false, caduco: caduco)
        .padding(.horizontal, 4).padding(.top, 6)
    }
  }
}

struct CompactaLider: View {
  let atributos: AvisoAtributos; let estado: AvisoAtributos.ContentState; let caduco: Bool
  var body: some View { Ficha(atributos: atributos, alto: 20).opacity(caduco ? 0.5 : 1) }
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
      if estado.llego { Image(systemName: "bell.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(Tinta.verde) }
      else { Ficha(atributos: atributos, alto: 16).opacity(caduco ? 0.5 : 1) }
    }
  }
}

private struct Cifra: View {
  let texto: String; let tamano: CGFloat; var color: Color; var conUnidad = true; var tamanoUnidad: CGFloat? = nil
  var body: some View {
    let partes = texto.split(separator: " ", maxSplits: 1).map(String.init)
    HStack(alignment: .firstTextBaseline, spacing: 3) {
      Text(partes.first ?? texto).font(.system(size: tamano, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(color)
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
    .foregroundStyle(.white).padding(.horizontal, alto * 0.23).frame(minWidth: alto, minHeight: alto, maxHeight: alto)
    // 0,26 del alto crea una ficha compacta con esquinas continuas.
    .background(RoundedRectangle(cornerRadius: alto * 0.26, style: .continuous).fill(atributos.colorFicha))
  }
}

private struct Pista: View {
  let atributos: AvisoAtributos; let estado: AvisoAtributos.ContentState; var muestraRotulos: Bool
  var caduco = false
  private let altura: CGFloat = 22
  var body: some View {
    VStack(spacing: 5) {
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
          AutobusDesdeArriba(caduco: caduco).frame(width: 34, height: 14).position(x: centroBus, y: altura / 2)
        }
      }
      .frame(height: altura)
      if muestraRotulos {
        HStack { Text("Bus"); Spacer(); Text("Tu punto") }
          // 11 pt deja los extremos secundarios y legibles.
          .font(.system(size: 11, weight: .medium)).foregroundStyle(Tinta.secundaria)
      }
    }.accessibilityHidden(true)
  }
}

private struct AutobusDesdeArriba: View {
  var caduco = false
  var body: some View {
    ZStack(alignment: .leading) {
      RoundedRectangle(cornerRadius: 3.2, style: .continuous)
        .fill(LinearGradient(
          colors: caduco ? [Color.white.opacity(0.35), Color.white.opacity(0.35)] : [Color(red: 0xF2 / 255, green: 0x75 / 255, blue: 0x6B / 255), Tinta.rojoBus],
          startPoint: .top,
          endPoint: .bottom
        ))
        .overlay(RoundedRectangle(cornerRadius: 3.2, style: .continuous).stroke(.black.opacity(caduco ? 0.15 : 0.45), lineWidth: 0.6))
        .shadow(color: caduco ? .clear : .black.opacity(0.38), radius: 2, y: 1)
      // El parabrisas ancho abraza el frente redondeado, orientado a la derecha.
      UneParabrisas().fill(caduco ? Color.white.opacity(0.18) : Tinta.vidrio)
        .frame(width: 8, height: 9).frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 1)
      // Ventana trasera estrecha, separada del parabrisas.
      RoundedRectangle(cornerRadius: 1).fill(caduco ? Color.white.opacity(0.18) : Tinta.vidrio)
        .frame(width: 2.5, height: 6).padding(.leading, 2)
      // Dos tapas claras de techo ayudan a leer la silueta como autobús.
      HStack(spacing: 2) {
        RoundedRectangle(cornerRadius: 1.2).fill(caduco ? Color.white.opacity(0.35) : Tinta.rojoBus.opacity(0.62)).frame(width: 5, height: 3)
        RoundedRectangle(cornerRadius: 1.2).fill(caduco ? Color.white.opacity(0.35) : Tinta.rojoBus.opacity(0.62)).frame(width: 5, height: 3)
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
      // Los espejos sobresalen apenas en las esquinas delanteras.
      VStack(spacing: 6) {
        Capsule().fill(caduco ? Color.white.opacity(0.35) : Tinta.rojoBus).frame(width: 3, height: 1).offset(x: 1)
        Capsule().fill(caduco ? Color.white.opacity(0.35) : Tinta.rojoBus).frame(width: 3, height: 1).offset(x: 1)
      }.frame(maxWidth: .infinity, alignment: .trailing).offset(x: 1)
    }
    .saturation(caduco ? 0 : 1)
    .accessibilityHidden(true)
  }
}

private struct UneParabrisas: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX + 1, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY))
    path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + 2), control: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 2))
    path.addQuadCurve(to: CGPoint(x: rect.maxX - 2, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX + 1, y: rect.maxY))
    path.closeSubpath()
    return path
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
