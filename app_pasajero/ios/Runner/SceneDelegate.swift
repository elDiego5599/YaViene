import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let url = connectionOptions.urlContexts.first?.url {
      ActividadEnVivo.recibir(url, viva: false)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
    guard let url = contexts.first?.url else { return }
    ActividadEnVivo.recibir(url, viva: true)
  }
}
