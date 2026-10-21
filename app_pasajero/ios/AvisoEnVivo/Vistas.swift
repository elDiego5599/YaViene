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
    // 22 pt mantienen aire entre el título de 25 pt y la pista con el bus grande.
    VStack(alignment: .leading, spacing: 22) {
      HStack(spacing: 12) {
        LogoYaViene(lado: 40)
        ContenidoAviso(atributos: atributos, estado: estado)
      }
      .opacity(caduco ? 0.5 : 1)
      // Con 18 pt de margen, el punto y la campana empiezan en x=18: el punto
      // tiene radio 3. El aro final llega 10 pt más allá de su centro (radio 7
      // + 3 de padding); 3 pt de margen lo alinean con el fin del rótulo.
      Pista(
        atributos: atributos,
        estado: estado,
        muestraRotulos: !estado.llego,
        caduco: caduco
      ).padding(.trailing, 3)
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
    VStack(alignment: .leading, spacing: 4) {
      Pista(atributos: atributos, estado: estado, muestraRotulos: false, caduco: caduco)
        // El margen exterior de 8 pt deja los elementos fuera de la curva.
        // Dentro, leading 6 + inicio 3 - radio 3 y leading 6 del rótulo ponen
        // punto y campana en x=14. A la derecha, el aro llega fin + 10
        // (radio 7 + 3); los márgenes 8 + 9 de pista y 8 + 6 del rótulo
        // dejan ambos bordes en x=ancho - 14.
        .padding(.leading, 6)
        .padding(.trailing, 9)
      if !estado.llego {
        RotulosPista(estado: estado, caduco: caduco, estiloTexto: .footnote, estiloCampana: .footnote)
          .padding(.leading, 6)
          .padding(.trailing, 6)
          .offset(y: -6)
      }
    }
    // 12 pt arriba bajan la pista 4; quedan 10 abajo. El inset exterior de
    // 8 pt protege la esquina redonda sin cambiar la alineación interior.
    .padding(.top, 12)
    .padding(.horizontal, 8)
    .padding(.bottom, 10)
  }
}

struct ContenidoAviso: View {
  let atributos: AvisoAtributos
  let estado: AvisoAtributos.ContentState

  var body: some View {
    let titulo = estado.llego
      ? Text(Textos.titulo(atributos: atributos, estado: estado))
        .font(.system(size: 25, weight: .semibold))
        .foregroundColor(.white)
      : (
      // #00A859 sobre negro da 6,75:1 de contraste (WCAG AA para texto normal).
      Text("Está a ")
        .font(.system(size: 25, weight: .semibold))
        .foregroundColor(.white)
        + Text(estado.distancia)
          .font(.system(size: 25, weight: .bold))
          .foregroundColor(Tinta.verde)
        + Text(" de ti")
          .font(.system(size: 25, weight: .semibold))
          .foregroundColor(.white)
      )
    // Solo la distancia, sin la ruta ni la placa debajo (dueño, 2026-10-21).
    VStack(alignment: .leading, spacing: 2) {
      titulo
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
  private let altura: CGFloat = 34
  private let altoBus: CGFloat = 25.4
  private let anchoBus: CGFloat = 54
  // Radio de llanta: 4,5 unidades del dibujo × 25,4 / 32 = 3,57 pt.
  private let radioLlanta: CGFloat = 4.5 * 25.4 / 32
  var body: some View {
    VStack(spacing: muestraRotulos ? 8 : 5) {
      GeometryReader { geo in
        let w = geo.size.width
        let inicio: CGFloat = 3 // Punto de 6 pt: su canto izquierdo coincide con el margen.
        let fin = max(w - 7, inicio) // El círculo termina a fin + 7; el aro agrega 3 pt.
        let lineaY = altura / 2
        let avance = estado.llego ? 1.0 : min(max(estado.avance, 0), 1)
        let desplazamiento = inicio + (fin - inicio) * avance
        let apoyoRueda = (26 - 16 + 4.5) * (altoBus / 32)
        let mitadBus = anchoBus / 2
        let centroBus = estado.llego ? fin - mitadBus : min(max(desplazamiento, inicio + mitadBus), fin - mitadBus)
        let xBus = centroBus
        let distanciaRodada = centroBus - (inicio + mitadBus)
        let xAviso = inicio + (fin - inicio) * min(max(estado.avanceAviso, 0), 1)
        let separacionCampana = mitadBus + 8 + 1 // media carrocería + radio 8 + 1 pt de aire.
        ZStack(alignment: .leading) {
          Capsule().fill(Tinta.carril).frame(height: 6).position(x: w / 2, y: lineaY)
          Capsule().fill(caduco ? Color.white.opacity(0.28) : Tinta.verde).frame(width: max(desplazamiento, inicio), height: 6)
            .shadow(color: caduco ? .clear : Tinta.verde.opacity(0.5), radius: 6)
            .position(x: max(desplazamiento, inicio) / 2, y: lineaY)
          Circle().fill(.white).frame(width: 6, height: 6).position(x: inicio, y: lineaY)
          if !estado.llego && abs(xAviso - xBus) >= separacionCampana && abs(fin - xAviso) >= 22 {
            Circle().fill(xBus >= xAviso ? Tinta.verde : Tinta.nodo)
              .overlay(Image(systemName: "bell.fill").font(.system(size: 8, weight: .semibold)).foregroundStyle(.white))
              .frame(width: 16, height: 16).position(x: xAviso, y: lineaY)
          }
          Circle().fill(caduco ? Color.white.opacity(0.35) : Tinta.verde).frame(width: 14, height: 14)
            .overlay(Circle().stroke(caduco ? Color.white.opacity(0.2) : .white, lineWidth: 2.5).padding(0.5))
            .overlay(Circle().stroke(caduco ? Color.clear : Tinta.verde.opacity(0.6), lineWidth: 1).padding(-3))
            .position(x: fin, y: lineaY)
          // Bus de 54 × 25,4 pt: mitad de 27 pt limita el centro en ambos
          // extremos. El apoyo de las ruedas es (10 + 4,5) × 25,4 / 32 =
          // 11,51 pt; se coloca el centro a esa distancia bajo la línea.
          // Giro sin patinar: distancia / radio de llanta, ahora 3,57 pt.
          AutobusDeLado(caduco: caduco, giro: .radians(distanciaRodada / radioLlanta))
            .frame(width: anchoBus, height: altoBus)
            .position(x: centroBus, y: lineaY - apoyoRueda)
        }
      }
      .frame(height: altura)
      if muestraRotulos && !estado.llego {
        // En la pantalla bloqueada, 8 pt sustituyen los 16 entre pista y rótulos.
        RotulosPista(estado: estado, caduco: caduco)
          .padding(.trailing, -3)
      }
    }.accessibilityHidden(true)
  }
}


private struct RotulosPista: View {
  let estado: AvisoAtributos.ContentState
  let caduco: Bool
  var estiloTexto: Font = .subheadline
  var estiloCampana: Font = .caption

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "bell.fill")
        .font(estiloCampana.weight(.semibold))
      Text(caduco ? "Sin datos nuevos, abre Ya Viene" : estado.aviso)
        .lineLimit(1)
        .minimumScaleFactor(0.9)
        .layoutPriority(1)
      Spacer(minLength: 4)
      Text("Tu punto")
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
    // Los estilos semánticos conservan Dynamic Type: subheadline en bloqueo,
    // footnote en la isla (13 pt en tamaño estándar), también para la campana.
    .font(estiloTexto)
    .foregroundStyle(Tinta.secundaria)
  }
}

/// El bus de la actividad en vivo, visto de lado con el frente a la
/// derecha, hacia tu punto (dueño, 2026-10-21). Solo vive aquí: en el mapa
/// sigue la cápsula de `createFlatTransitMarker`. Dibujado en 68 × 32 y
/// pintado al 79,4 %, 54 × 25,4 pt.
private struct AutobusDeLado: View {
  var caduco = false
  var giro: Angle = .zero

  private let ancho: CGFloat = 68
  private let alto: CGFloat = 32

  var body: some View {
    GeometryReader { geo in
      let escalaX = geo.size.width / ancho
      let escalaY = geo.size.height / alto
      ZStack(alignment: .topLeading) {
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

          // El arco negro de cada rueda queda en el Canvas.
          for x: CGFloat in [14, 54] {
            d.fill(Path(ellipseIn: CGRect(x: x - 6, y: 20, width: 12, height: 12)), with: .color(.black))
          }
        }
        ForEach([CGFloat(14), CGFloat(54)], id: \.self) { x in
          Rueda(caduco: caduco, giro: giro)
            .frame(width: 9 * escalaX, height: 9 * escalaY)
            .position(x: x * escalaX, y: 26 * escalaY)
        }
      }
    }
    .accessibilityHidden(true)
  }
}

private struct Rueda: View {
  let caduco: Bool
  let giro: Angle

  var body: some View {
    GeometryReader { geo in
      let lado = min(geo.size.width, geo.size.height)
      let centro = lado / 2
      let radioRin = lado * 0.31
      ZStack {
        Circle().fill(Tinta.nodo)
        Circle()
          .fill(Tinta.secundaria.opacity(caduco ? 0.5 : 1))
          .frame(width: lado * 0.62, height: lado * 0.62)
        ForEach(0..<5) { indice in
          Capsule()
            .fill(Tinta.nodo)
            .frame(width: max(0.7, lado * 0.09), height: radioRin * 0.9)
            .offset(y: -radioRin * 0.48)
            .rotationEffect(.degrees(Double(indice) * 72))
        }
        Circle()
          .fill(Tinta.nodo)
          .frame(width: lado * 0.22, height: lado * 0.22)
      }
      .frame(width: lado, height: lado)
      .position(x: centro, y: centro)
    }
    .rotationEffect(giro)
    .accessibilityHidden(true)
  }
}

private extension View {
  @ViewBuilder func numericTransition() -> some View {
    if #available(iOS 17.0, *) { self.contentTransition(.numericText()) } else { self }
  }
}
