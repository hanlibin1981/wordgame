import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("ttsVoice") private var ttsVoice = "Alex"
    @AppStorage("questionsPerRound") private var questionsPerRound = 10
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                // Sound Settings
                Section("声音设置") {
                    Toggle("启用声音", isOn: $soundEnabled)

                    Picker("TTS语音", selection: $ttsVoice) {
                        Text("Alex (美式)").tag("Alex")
                        Text("Daniel (英式)").tag("Daniel")
                        Text("Victoria (英式女声)").tag("Victoria")
                    }
                }

                // Game Settings
                Section("游戏设置") {
                    Stepper("每关题目数: \(questionsPerRound)", value: $questionsPerRound, in: 5...20, step: 5)

                    NavigationLink {
                        Text("难度设置 (待实现)")
                    } label: {
                        Text("默认难度")
                    }
                }

                // Data Management
                Section("数据管理") {
                    Button(action: { showResetAlert = true }) {
                        Text("重置所有进度")
                            .foregroundColor(.errorRed)
                    }
                }

                // About
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("开发者")
                        Spacer()
                        Text("WordGame Team")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .alert("重置进度", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) { }
                Button("重置", role: .destructive) {
                    resetProgress()
                }
            } message: {
                Text("确定要重置所有学习进度吗？此操作不可撤销。")
            }
        }
    }

    private func resetProgress() {
        // TODO: Implement progress reset
        print("Resetting all progress...")
    }
}

#Preview {
    SettingsView()
}
