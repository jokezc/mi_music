import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let umengConfigChannel = FlutterMethodChannel(name: "cn.jokeo.mi_music/umeng_config",
                                                   binaryMessenger: controller.binaryMessenger)
    
    umengConfigChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getUmengConfig" {
        if let config = self.getUmengConfig() {
          // 即使配置文件存在，如果 AppKey 为空，也返回空值（表示未配置）
          result([
            "appKey": config["UMAppKey"] ?? "",
            "channel": config["UMChannel"] ?? ""
          ])
        } else {
          // 配置文件不存在时，返回空值而不是错误（这是可选功能）
          result([
            "appKey": "",
            "channel": ""
          ])
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    // 友盟SDK初始化将在Flutter层完成
    // Flutter插件会自动处理原生初始化
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  /// 从 plist 文件读取友盟配置
  func getUmengConfig() -> [String: String]? {
    guard let path = Bundle.main.path(forResource: "umeng_config", ofType: "plist"),
          let plist = NSDictionary(contentsOfFile: path) as? [String: String] else {
      return nil
    }
    return plist
  }
}
