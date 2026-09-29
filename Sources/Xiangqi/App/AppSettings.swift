import Foundation

enum AppSettings {
    /// 本机默认引擎（设置面板“恢复默认”用）。
    static let defaultEnginePath = NSHomeDirectory() + "/pikafish/pikafish"

    /// 引擎路径：优先用随 App 打包的内嵌引擎（Contents/Resources/pikafish），
    /// 次选用户配置或 ~/pikafish（方便本机调试）。
    static var enginePath: String {
        get {
            if let bundled = bundledEnginePath, FileManager.default.isExecutableFile(atPath: bundled) {
                return bundled
            }
            if let saved = UserDefaults.standard.string(forKey: "enginePath") {
                return saved
            }
            return defaultEnginePath
        }
        set { UserDefaults.standard.set(newValue, forKey: "enginePath") }
    }
    static var engineDirectory: String {
        (enginePath as NSString).deletingLastPathComponent
    }

    /// Bundle 内引擎路径（App 可执行文件同级的 Resources/pikafish）。
    private static var bundledEnginePath: String? {
        let exec = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/pikafish").path
        return FileManager.default.fileExists(atPath: exec) ? exec : nil
    }
}
