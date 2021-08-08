import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let config: EnvConfig = EnvConfig()
    print("facebookAppId \(config.facebookAppId)")
    print("fbLoginProtocolScheme \(config.fbLoginProtocolScheme)")
    print("googleMapsApiKey \(config.googleMapsApiKey)")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
