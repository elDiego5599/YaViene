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
      TarjetaBloqueada(
        atributos: contexto.attributes,
        estado: contexto.state,
        caduco: contexto.isStale
      )
      .activityBackgroundTint(.black)
    } dynamicIsland: { contexto in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          EmptyView()
        }
        DynamicIslandExpandedRegion(.center) {
          EmptyView()
        }
        DynamicIslandExpandedRegion(.trailing) {
          EmptyView()
        }
        DynamicIslandExpandedRegion(.bottom) {
          IslaExpandida(atributos: contexto.attributes, estado: contexto.state, caduco: contexto.isStale)
        }
      } compactLeading: {
        CompactaLider(atributos: contexto.attributes, estado: contexto.state, caduco: contexto.isStale)
      } compactTrailing: {
        CompactaCola(atributos: contexto.attributes, estado: contexto.state, caduco: contexto.isStale)
      } minimal: {
        Minima(atributos: contexto.attributes, estado: contexto.state, caduco: contexto.isStale)
      }
      .keylineTint(Tinta.verde)
    }
  }
}
