import Foundation
import XiangqiCore

/// 新对局配置：唯一模式为分析学习——人执红（先手），引擎执黑。
/// 引擎固定最强设置：每步思考 6 秒。
struct GameConfig: Sendable {
    var timeControl: TimeControl
    var threads: Int
    var hashMB: Int

    static let standard = GameConfig(timeControl: .movetime(6000), threads: 8, hashMB: 512)
}
