import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @EnvironmentObject var wordBookVM: WordBookViewModel
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("ttsVoice") private var ttsVoice = "Alex"
    @AppStorage("questionsPerRound") private var questionsPerRound = 10
    @AppStorage("defaultWordBookId") private var defaultWordBookId: String = ""
    @State private var showResetAlert = false
    @State private var resetMessage: String?

    /// The currently selected default word book, if any.
    private var selectedDefaultBook: WordBook? {
        wordBookVM.wordBooks.first { $0.id == defaultWordBookId }
    }

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
                        DifficultySettingsView()
                    } label: {
                        HStack {
                            Text("默认难度")
                            Spacer()
                            Text("中等")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Learning Settings
                Section("学习设置") {
                    NavigationLink {
                        DefaultWordBookPickerView()
                    } label: {
                        HStack {
                            Text("默认词书")
                            Spacer()
                            Text(selectedDefaultBook?.name ?? "未选择")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                // Data Management
                Section("数据管理") {
                    NavigationLink {
                        BackupView()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise.icloud")
                            Text("备份与恢复词书")
                        }
                    }

                    Button(action: { showResetAlert = true }) {
                        Text("重置所有进度")
                            .foregroundColor(.errorRed)
                    }

                    if let message = resetMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                    performReset()
                }
            } message: {
                Text("确定要重置所有学习进度吗？此操作不可撤销。")
            }
        }
    }

    private func performReset() {
        do {
            try DatabaseService.shared.resetAllProgressGlobally()
            resetMessage = "所有进度已重置"
            // Clear message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                resetMessage = nil
            }
        } catch {
            resetMessage = "重置失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - Default Word Book Picker
struct DefaultWordBookPickerView: View {
    @EnvironmentObject var wordBookVM: WordBookViewModel
    @AppStorage("defaultWordBookId") private var defaultWordBookId: String = ""

    var body: some View {
        List {
            Section("选择默认词书") {
                ForEach(wordBookVM.wordBooks) { book in
                    Button(action: {
                        defaultWordBookId = book.id
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("\(book.wordCount) 词")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if defaultWordBookId == book.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.primaryBlue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("选择默认词书")
        .modifier(NavigationBarTitleInlineModifier())
    }
}

// MARK: - Difficulty Settings
enum GameDifficulty: String, CaseIterable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"

    var displayName: String {
        switch self {
        case .easy: return "简单"
        case .medium: return "中等"
        case .hard: return "困难"
        }
    }

    var description: String {
        switch self {
        case .easy: return "每关10题，无时间限制"
        case .medium: return "每关10题，轻度时间限制"
        case .hard: return "每关15题，严格时间限制"
        }
    }

    var questionCount: Int {
        switch self {
        case .easy: return 10
        case .medium: return 10
        case .hard: return 15
        }
    }

    var timeLimit: Int? {
        switch self {
        case .easy: return nil
        case .medium: return 30
        case .hard: return 15
        }
    }

    var passingThreshold: Int {
        switch self {
        case .easy: return 60
        case .medium: return 70
        case .hard: return 80
        }
    }
}

struct DifficultySettingsView: View {
    @AppStorage("gameDifficulty") private var selectedDifficulty = GameDifficulty.medium.rawValue

    var body: some View {
        List {
            ForEach(GameDifficulty.allCases, id: \.rawValue) { difficulty in
                Button(action: {
                    selectedDifficulty = difficulty.rawValue
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(difficulty.displayName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(difficulty.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if selectedDifficulty == difficulty.rawValue {
                            Image(systemName: "checkmark")
                                .foregroundColor(.primaryBlue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("难度设置")
        .modifier(NavigationBarTitleInlineModifier())
    }
}

// MARK: - macOS-compatible modifier
#if os(macOS)
struct NavigationBarTitleInlineModifier: ViewModifier {
    func body(content: Content) -> some View { content }
}
#else
struct NavigationBarTitleInlineModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationBarTitleDisplayMode(.inline)
    }
}
#endif

#Preview {
    SettingsView()
}
