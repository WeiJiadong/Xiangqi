import Foundation
import XiangqiCore

/// 极简断言：测试函数返回 [String?]，nil=通过，非 nil=失败描述。
/// 无 XCTest/Testing 依赖，`swift run XiangqiTests` 执行。

func expect(_ cond: Bool, _ msg: String = "", file: String = #fileID, line: UInt = #line) -> String? {
    cond ? nil : "(\(file):\(line)) \(msg.isEmpty ? "assertion failed" : msg)"
}

func expectEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "", file: String = #fileID, line: UInt = #line) -> String? {
    a == b ? nil : "(\(file):\(line)) \(msg.isEmpty ? "\(a) != \(b)" : msg + ": \(a) != \(b)")"
}

func expectNil<T>(_ a: T?, _ msg: String = "", file: String = #fileID, line: UInt = #line) -> String? {
    a == nil ? nil : "(\(file):\(line)) expected nil, got \(a!)"
}

func expectNotNil<T>(_ a: T?, _ msg: String = "", file: String = #fileID, line: UInt = #line) -> String? {
    a != nil ? nil : "(\(file):\(line)) expected non-nil\(msg.isEmpty ? "" : ": " + msg)"
}
