import SwiftUI
import XiangqiCore

struct SettingsPane: View {
    @State private var path = AppSettings.enginePath
    @State private var status: String?
    @State private var testing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("引擎设置").font(.title2.bold())
            HStack {
                TextField("引擎路径", text: $path, prompt: Text(AppSettings.defaultEnginePath))
                Button("浏览…") { chooseFile() }
            }
            Text("默认：\(AppSettings.defaultEnginePath)")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Button("测试连接") {
                    testing = true
                    status = nil
                    Task { await test() }
                }
                .disabled(path.isEmpty || testing)
                Button("恢复默认") { path = AppSettings.defaultEnginePath; status = nil }
                if testing { ProgressView().controlSize(.small) }
            }
            if let status {
                Text(status)
                    .font(.callout)
                    .foregroundColor(status.hasPrefix("✓") ? .green : .red)
            }
            Spacer()
        }
        .padding(20)
        .frame(width: 460, height: 220)
        .onChange(of: path) { AppSettings.enginePath = $0 }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }

    private func test() async {
        let s = UCISession()
        do {
            try await s.start(enginePath: path, options: [])
            let name = await s.engineName ?? "未知引擎"
            await s.shutdown()
            status = "✓ 连接成功：\(name)"
        } catch {
            await s.shutdown()
            status = "✗ 连接失败：\(error.localizedDescription)"
        }
    }
}
