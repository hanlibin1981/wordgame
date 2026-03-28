import SwiftUI
import os

/// View for selecting game level
struct LevelSelectionView: View {
    private let logger = Logger(subsystem: "com.wordgame.ui", category: "LevelSelectionView")
    let book: WordBook
    /// Navigation path for NavigationStack context. If nil, uses sheet dismiss.
    var navigationPath: Binding<NavigationPath>?
    /// When in sheet context, write selected level here and dismiss.
    var selectedLevel: Binding<GameLevel?>?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameVM = GameViewModel()
    @State private var levels: [GameLevel] = []
    @State private var isLoading = true
    /// Maps level (chapter, stage) → LevelRecord
    @State private var levelRecords: [String: LevelRecord] = [:]
    /// Game progress — used as the primary source for unlock state
    @State private var gameProgress: GameProgress?

    /// Push a game onto the navigation stack or write to binding and dismiss.
    private func navigateToGame(_ level: GameLevel) {
        if let path = navigationPath {
            path.wrappedValue.append(
                LearningNavDestination.game(book: book, level: level)
            )
        } else {
            // Sheet context: signal selection via binding then dismiss
            selectedLevel?.wrappedValue = level
            dismiss()
        }
    }

    /// Go back: pop nav stack or dismiss sheet.
    private func goBack() {
        if let path = navigationPath {
            path.wrappedValue.removeLast()
        } else {
            dismiss()
        }
    }

    /// Returns the LevelRecord for a given level, if any.
    private func record(for level: GameLevel) -> LevelRecord? {
        levelRecords[recordKey(chapter: level.chapter, stage: level.isBossLevel ? 4 : level.stage)]
    }

    /// Returns true if the given level is locked (cannot be played yet).
    /// Uses lastPassedBossChapter to determine if a chapter's regular levels (1-3)
    /// are unlocked — this avoids the bug where passing a boss (currentStage=4)
    /// would incorrectly unlock all regular stages in the same chapter.
    ///
    /// Locking rules:
    /// - Chapter 1, Stage 1: always unlocked
    /// - Regular stage (1-3): unlocked when lastPassedBossChapter >= level.chapter - 1
    ///   (i.e., the boss of the previous chapter has been passed)
    /// - Boss (stage=4): unlocked only when the LevelRecord confirms stage-3 was beaten
    private func isLevelLocked(_ level: GameLevel) -> Bool {
        // First level is always accessible
        if level.chapter == 1 && level.stage == 1 && !level.isBossLevel {
            return false
        }

        if let gp = gameProgress {
            if level.isBossLevel {
                // Boss unlocks when stage 3 of the same chapter is passed
                let stage3Passed = isStagePassed(level.chapter, 3)
                return !stage3Passed
            } else {
                // Regular stage: unlocked when the boss of the previous chapter has been passed.
                // lastPassedBossChapter >= level.chapter - 1 means that chapter's boss is done.
                // Special case: chapter 1 stage 1 is already handled above.
                if level.chapter > 1 {
                    // For stage 1: requires previous chapter's boss (lastPassedBossChapter >= chapter - 1)
                    // For stage 2-3: also requires previous chapter's boss since stage 1
                    // is gated by same rule.
                    return gp.lastPassedBossChapter < level.chapter - 1
                }
                // Chapter 1, stages 2-3: unlocked by currentStage progression
                if gp.currentChapter > level.chapter {
                    return false
                }
                if gp.currentChapter == level.chapter && gp.currentStage >= level.stage {
                    return false
                }
                // Need previous stage in same chapter to be beaten
                let prevStage = level.stage - 1
                if prevStage == 0 { return false }
                return !isStagePassed(level.chapter, prevStage)
            }
        }

        // No progress yet: only stage 1-1 is unlocked
        return !(level.chapter == 1 && level.stage == 1 && !level.isBossLevel)
    }

    private func isStagePassed(_ chapter: Int, _ stage: Int) -> Bool {
        levelRecords[recordKey(chapter: chapter, stage: stage)]?.isPassed ?? false
    }

    private func isChapterCompleted(_ chapter: Int) -> Bool {
        // A chapter is completed when its boss level (stage 4) is passed
        isStagePassed(chapter, 4)
    }

    private func recordKey(chapter: Int, stage: Int) -> String {
        "\(chapter)-\(stage)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Button("返回") {
                        goBack()
                    }
                    Spacer()
                }

                Text("选择关卡")
                    .font(DesignFont.title2)

                Text(book.name)
                    .font(DesignFont.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.backgroundMain)

            Divider()

            // Levels grid
            if isLoading {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                    Text("加载关卡...")
                        .font(DesignFont.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if levels.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 48 * 2))
                        .foregroundStyle(.secondary)
                    Text("词库为空")
                        .font(DesignFont.headline)
                        .foregroundStyle(.secondary)
                    Text("请先添加单词再开始学习")
                        .font(DesignFont.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                            let locked = isLevelLocked(level)
                            Button {
                                if !locked {
                                    logger.debug("TAPPED: level=\(level.name), isBoss=\(level.isBossLevel), chapter=\(level.chapter), stage=\(level.stage)")
                                    navigateToGame(level)
                                } else {
                                    logger.debug("TAPPED BUT LOCKED: level=\(level.name), isBoss=\(level.isBossLevel)")
                                }
                            } label: {
                                LevelCard(
                                    level: level,
                                    isLocked: locked,
                                    isCompleted: record(for: level)?.isPassed ?? false,
                                    starsEarned: record(for: level)?.starsEarned ?? 0
                                )
                            }
                            .buttonStyle(.plain)
                            .opacity(locked ? 0.55 : 1.0)
                            .transitionEffect(index: index)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 480)
        .background(Color.backgroundMain)
        .onAppear {
            isLoading = true
            Task {
                let generatedLevels = gameVM.generateLevels(for: book)
                // Load all level records for this book
                var records: [String: LevelRecord] = [:]
                let allRecords = (try? DatabaseService.shared.fetchAllLevelRecords(forBookId: book.id)) ?? []
                for record in allRecords {
                    records[recordKey(chapter: record.chapter, stage: record.stage)] = record
                }
                // Also load game progress to determine current unlock state
                let progress = try? DatabaseService.shared.fetchOrCreateProgress(forBookId: book.id)
                await MainActor.run {
                    levels = generatedLevels
                    levelRecords = records
                    gameProgress = progress
                    isLoading = false
                }
            }
        }
    }
}

/// Card for a single level
struct LevelCard: View {
    let level: GameLevel
    let isLocked: Bool
    let isCompleted: Bool
    let starsEarned: Int

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(circleBackgroundColor)
                    .frame(width: 64, height: 64)
                    .scaleEffect(isHovered && !isLocked ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                } else if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(level.levelNumber)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }

                // Completed badge overlay (top-right)
                if isCompleted {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.successGreen)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 18, height: 18)
                        )
                        .offset(x: 24, y: -24)
                }
            }

            Text(level.name)
                .font(DesignFont.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(isLocked ? .secondary : .primary)

            // Stars for completed levels
            if isCompleted {
                HStack(spacing: 2) {
                    ForEach(0..<3) { index in
                        Image(systemName: index < starsEarned ? "star.fill" : "star")
                            .font(.system(size: 11))
                            .foregroundColor(index < starsEarned ? Color.warningOrange : Color.gray.opacity(0.4))
                    }
                }
            } else if level.isBossLevel {
                Text("BOSS")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.errorRed)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorderColor, lineWidth: isCompleted ? 1.5 : 0.5)
        )
        .shadow(
            color: isHovered && !isLocked ? backgroundColor.opacity(0.25) : .black.opacity(0.06),
            radius: isHovered && !isLocked ? 12 : 5,
            x: 0,
            y: isHovered && !isLocked ? 6 : 2
        )
        .scaleEffect(isHovered && !isLocked ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    /// Background color for the circle based on completion and lock state.
    private var circleBackgroundColor: Color {
        if isCompleted { return .successGreen }
        if level.isBossLevel { return .errorRed }
        switch level.stage {
        case 1: return .successGreen
        case 2: return .primaryBlue
        case 3: return .warningOrange
        default: return .gray
        }
    }

    /// General background color for shadow and hover effects.
    private var backgroundColor: Color {
        if level.isBossLevel { return .errorRed }
        switch level.stage {
        case 1: return .successGreen
        case 2: return .primaryBlue
        case 3: return .warningOrange
        default: return .gray
        }
    }

    private var cardBackgroundColor: Color {
        if isCompleted {
            return Color.successGreen.opacity(0.06)
        }
        return Color.cardBackground
    }

    private var cardBorderColor: Color {
        if isCompleted {
            return Color.successGreen.opacity(0.3)
        }
        return Color.clear
    }
}

#Preview {
    LevelSelectionView(
        book: WordBook(name: "测试词库", wordCount: 100),
        navigationPath: .constant(NavigationPath()),
        selectedLevel: nil
    )
}
