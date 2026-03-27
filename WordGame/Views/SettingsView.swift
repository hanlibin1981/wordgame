import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var wordBookVM: WordBookViewModel
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("ttsVoice") private var ttsVoice = "Alex"
    @AppStorage("questionsPerRound") private var questionsPerRound = 10
    @AppStorage("defaultWordBookId") private var defaultWordBookId: String = ""
    @AppStorage("gameDifficulty") private var gameDifficulty = GameDifficulty.medium.rawValue
    @State private var showResetAlert = false
    @State private var resetMessage: String?

    private var selectedDefaultBook: WordBook? {
        wordBookVM.wordBooks.first { $0.id == defaultWordBookId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 语音设置
                    SettingsCard(title: "语音设置", icon: "speaker.wave.2.fill", iconColor: .primaryBlue) {
                        SettingsToggleRow(
                            title: "启用声音",
                            subtitle: "题目播报与音效",
                            icon: "speaker.fill",
                            isOn: $soundEnabled
                        )

                        Divider().padding(.vertical, 4)

                        SettingsPickerRow(
                            title: "TTS 语音",
                            icon: "person.wave.2.fill",
                            selection: $ttsVoice,
                            options: [
                                ("Alex (美式)", "Alex"),
                                ("Daniel (英式)", "Daniel"),
                                ("Victoria (英式女声)", "Victoria")
                            ]
                        )
                    }

                    // 游戏设置
                    SettingsCard(title: "游戏设置", icon: "gamecontroller.fill", iconColor: .successGreen) {
                        SettingsStepperRow(
                            title: "每关题目数",
                            subtitle: "每轮闯关的题目数量",
                            icon: "number",
                            value: $questionsPerRound,
                            range: 5...20,
                            step: 5
                        )

                        Divider().padding(.vertical, 4)

                        NavigationLink {
                            DifficultySettingsView()
                        } label: {
                            SettingsNavRow(
                                title: "游戏难度",
                                subtitle: GameDifficulty(rawValue: gameDifficulty)?.displayName ?? "中等",
                                icon: "gauge.with.dots.needle.bottom.50percent"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // 学习设置
                    SettingsCard(title: "学习设置", icon: "book.fill", iconColor: .warningOrange) {
                        NavigationLink {
                            DefaultWordBookPickerView()
                        } label: {
                            SettingsNavRow(
                                title: "默认词书",
                                subtitle: selectedDefaultBook?.name ?? "未选择",
                                icon: "text.book.closed.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // 数据管理
                    SettingsCard(title: "数据管理", icon: "externaldrive.fill", iconColor: .primaryBlue) {
                        NavigationLink {
                            BackupView()
                        } label: {
                            SettingsNavRow(
                                title: "备份与恢复",
                                subtitle: "导出或导入词书数据",
                                icon: "arrow.clockwise.icloud.fill"
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.vertical, 4)

                        Button {
                            showResetAlert = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.errorRed)
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("重置所有进度")
                                        .font(DesignFont.body)
                                        .foregroundColor(.errorRed)
                                    Text("清除所有学习记录与闯关进度")
                                        .font(DesignFont.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)

                        if let msg = resetMessage {
                            Text(msg)
                                .font(DesignFont.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }

                    // 关于
                    SettingsCard(title: "关于", icon: "info.circle.fill", iconColor: .secondary) {
                        HStack(spacing: 12) {
                            Image(systemName: "app.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primaryBlue)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("版本")
                                    .font(DesignFont.body)
                                Text("1.0.0")
                                    .font(DesignFont.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)

                        Divider().padding(.vertical, 4)

                        HStack(spacing: 12) {
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primaryBlue)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("开发者")
                                    .font(DesignFont.body)
                                Text("WordGame Team")
                                    .font(DesignFont.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .background(Color.backgroundMain)
            .navigationTitle("设置")
            .alert("重置进度", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) { performReset() }
            } message: {
                Text("确定要重置所有学习进度吗？此操作不可撤销。")
            }
        }
    }

    private func performReset() {
        do {
            try DatabaseService.shared.resetAllProgressGlobally()
            resetMessage = "所有进度已重置"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { resetMessage = nil }
        } catch {
            resetMessage = "重置失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - Settings Card Container
struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(DesignFont.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Separator
            Rectangle()
                .fill(Color.borderLight)
                .frame(height: 1)

            // Card content
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.cardBackground)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Settings Row Components
struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primaryBlue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DesignFont.body)
                Text(subtitle).font(DesignFont.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.primaryBlue)
        }
        .padding(.vertical, 6)
    }
}

struct SettingsPickerRow: View {
    let title: String
    let icon: String
    @Binding var selection: String
    let options: [(String, String)]

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primaryBlue)
                .frame(width: 28)

            Text(title)
                .font(DesignFont.body)

            Spacer()

            Picker("", selection: $selection) {
                ForEach(options, id: \.1) { label, value in
                    Text(label).tag(value)
                }
            }
            .pickerStyle(.menu)
            .tint(.primaryBlue)
        }
        .padding(.vertical, 6)
    }
}

struct SettingsStepperRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primaryBlue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DesignFont.body)
                Text(subtitle).font(DesignFont.caption).foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    if value - step >= range.lowerBound {
                        value -= step
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(value <= range.lowerBound ? Color.gray : .primaryBlue)
                }
                .buttonStyle(.plain)
                .disabled(value <= range.lowerBound)

                Text("\(value)")
                    .font(DesignFont.headline)
                    .frame(minWidth: 32)

                Button {
                    if value + step <= range.upperBound {
                        value += step
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(value >= range.upperBound ? Color.gray : .primaryBlue)
                }
                .buttonStyle(.plain)
                .disabled(value >= range.upperBound)
            }
        }
        .padding(.vertical, 6)
    }
}

struct SettingsNavRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primaryBlue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(DesignFont.body)
                Text(subtitle).font(DesignFont.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

// Color extension for border
extension Color {
    static let borderLight = Color(hex: "E5E7EB")
}

// MARK: - Default Word Book Picker
struct DefaultWordBookPickerView: View {
    @EnvironmentObject var wordBookVM: WordBookViewModel
    @AppStorage("defaultWordBookId") private var defaultWordBookId: String = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(wordBookVM.wordBooks) { book in
                    Button {
                        defaultWordBookId = book.id
                    } label: {
                        WordBookPickerRow(
                            book: book,
                            isSelected: defaultWordBookId == book.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color.backgroundMain)
        .navigationTitle("选择默认词书")
        .modifier(NavigationBarTitleInlineModifier())
    }
}

struct WordBookPickerRow: View {
    let book: WordBook
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: book.isPreset ? "star.fill" : "folder")
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .white : (book.isPreset ? .warningOrange : .primaryBlue))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? Color.primaryBlue : (book.isPreset ? Color.warningOrange.opacity(0.12) : Color.primaryBlue.opacity(0.12)))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(book.name)
                    .font(DesignFont.headline)
                    .foregroundColor(.primary)
                Text("\(book.wordCount) 词")
                    .font(DesignFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.primaryBlue)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: isSelected ? 8 : 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.primaryBlue.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
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

    var icon: String {
        switch self {
        case .easy: return "face.smiling"
        case .medium: return "equal"
        case .hard: return "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .easy: return .successGreen
        case .medium: return .warningOrange
        case .hard: return .errorRed
        }
    }
}

struct DifficultySettingsView: View {
    @AppStorage("gameDifficulty") private var selectedDifficulty = GameDifficulty.medium.rawValue

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(GameDifficulty.allCases, id: \.rawValue) { difficulty in
                    Button {
                        selectedDifficulty = difficulty.rawValue
                    } label: {
                        DifficultyRow(
                            difficulty: difficulty,
                            isSelected: selectedDifficulty == difficulty.rawValue
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color.backgroundMain)
        .navigationTitle("难度设置")
        .modifier(NavigationBarTitleInlineModifier())
    }
}

struct DifficultyRow: View {
    let difficulty: GameDifficulty
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: difficulty.icon)
                .font(.system(size: 18))
                .foregroundColor(isSelected ? .white : difficulty.color)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? difficulty.color : difficulty.color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(difficulty.displayName)
                    .font(DesignFont.headline)
                    .foregroundColor(.primary)
                Text(difficulty.description)
                    .font(DesignFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(difficulty.color)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: isSelected ? 8 : 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? difficulty.color.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
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
