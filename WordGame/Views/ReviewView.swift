import SwiftUI

/// Review view — presents review words as individual game-like levels.
struct ReviewView: View {
    let book: WordBook
    @StateObject private var learningVM = LearningViewModel()
    @StateObject private var gameVM = GameViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var isLoadingLevels = true
    /// The review level currently being played (nil = not in game)
    @State private var activeLevel: ReviewLevel?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Level grid
            if isLoadingLevels {
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                    Text("加载复习关卡...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if learningVM.reviewLevels.isEmpty {
                emptyStateView
            } else {
                levelGrid
            }
        }
        .frame(minWidth: 600, minHeight: 480)
        .background(Color.backgroundMain)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("返回") { dismiss() }
            }
        }
        .sheet(item: $activeLevel) { level in
            ReviewGameView(
                book: book,
                level: level,
                reviewWords: learningVM.reviewWords,
                onComplete: { result in
                    handleLevelComplete(level, result: result)
                }
            )
        }
        .onAppear {
            loadReviewLevels()
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("选择复习关卡")
                .font(.system(size: 20, weight: .bold))

            Text(subtitleText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            if !learningVM.reviewLevels.isEmpty {
                let completed = learningVM.reviewLevels.filter { $0.isAllStudied }.count
                HStack(spacing: 8) {
                    ProgressView(value: Double(completed), total: Double(learningVM.reviewLevels.count))
                        .tint(completed == learningVM.reviewLevels.count ? Color.successGreen : Color.warningOrange)

                    Text("\(completed)/\(learningVM.reviewLevels.count) 关")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    private var subtitleText: String {
        switch learningVM.reviewContentState {
        case .dueWords:
            return "根据记忆曲线，科学安排复习时间"
        case .fallbackWords:
            return "当前没有到期内容，先做一轮已学词汇巩固"
        case .noPassedLevels:
            return "通关后会自动生成可复习词汇"
        }
    }

    private var emptyStateTitle: String {
        switch learningVM.reviewContentState {
        case .dueWords:   return "暂无需要复习的单词"
        case .fallbackWords: return "当前没有到期内容"
        case .noPassedLevels: return "还没有可复习的内容"
        }
    }

    private var emptyStateDescription: String {
        switch learningVM.reviewContentState {
        case .dueWords:
            return "已通关词汇暂时都不在本轮复习时间点"
        case .fallbackWords:
            return "已自动切换为巩固复习"
        case .noPassedLevels:
            return "先完成至少一个已通关关卡，再来这里集中复习"
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.successGreen)
            Text(emptyStateTitle)
                .font(.system(size: 16, weight: .medium))
            Text(emptyStateDescription)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Level Grid
    private var levelGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(Array(learningVM.reviewLevels.enumerated()), id: \.element.id) { index, level in
                    Button(action: {
                        activeLevel = level
                    }) {
                        ReviewLevelCard(
                            level: level,
                            isCompleted: level.isAllStudied,
                            isLocked: false
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("复习第\(level.id)关")
                    .accessibilityValue(level.isAllStudied ? "已完成" : "未完成")
                    .transitionEffect(index: index)
                }
            }
            .padding()
        }
    }

    // MARK: - Data Loading
    private func loadReviewLevels() {
        isLoadingLevels = true
        Task {
            let levels = gameVM.generateLevels(for: book)
            await learningVM.loadEbbinghausReviewWords(for: book, levels: levels)
            isLoadingLevels = false
        }
    }

    // MARK: - Level Completion
    private func handleLevelComplete(_ level: ReviewLevel, result: GameResult) {
        guard result.isPassed else { return }
        learningVM.markLevelStudied(level.id)
        learningVM.markReviewLevelCompleted(bookId: book.id, levelId: level.id)
    }
}

// MARK: - Review Level Card
struct ReviewLevelCard: View {
    let level: ReviewLevel
    let isCompleted: Bool
    let isLocked: Bool

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
                    Text("\(level.id)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }

                // Completion badge
                if isCompleted {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.successGreen)
                        .background(Circle().fill(Color.white).frame(width: 18, height: 18))
                        .offset(x: 24, y: -24)
                }
            }

            Text("第\(level.id)关")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isLocked ? .secondary : .primary)

            HStack(spacing: 2) {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 10))
                Text("\(level.totalWords) 词")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)

            if isCompleted {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                    Text("已完成")
                        .font(.system(size: 11))
                }
                .foregroundColor(.successGreen)
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
            color: isHovered && !isLocked ? circleBackgroundColor.opacity(0.25) : .black.opacity(0.06),
            radius: isHovered && !isLocked ? 12 : 5,
            x: 0, y: isHovered && !isLocked ? 6 : 2
        )
        .scaleEffect(isHovered && !isLocked ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in isHovered = hovering }
    }

    private var circleBackgroundColor: Color {
        if isCompleted { return .successGreen }
        if isLocked { return .gray }
        return .warningOrange
    }

    private var cardBackgroundColor: Color {
        if isCompleted { return Color.successGreen.opacity(0.06) }
        return Color.cardBackground
    }

    private var cardBorderColor: Color {
        if isCompleted { return Color.successGreen.opacity(0.3) }
        return Color.clear
    }
}

// MARK: - Review Game View (full-screen game experience)
/// Wraps GameView in full-screen cover for review mode.
struct ReviewGameView: View {
    let book: WordBook
    let level: ReviewLevel
    let reviewWords: [Word]
    let onComplete: (GameResult) -> Void

    /// Converts ReviewLevel to GameLevel for use with GameView
    private var gameLevel: GameLevel {
        GameLevel(
            id: level.id,
            bookId: book.id,
            chapter: 99,           // 99 denotes a review level (outside normal chapter range)
            stage: level.id,
            name: "复习第\(level.id)关",
            wordIds: level.wordIds,
            passingScore: 0,
            isBossLevel: false
        )
    }

    var body: some View {
        GameView(
            book: book,
            level: gameLevel,
            isReviewMode: true,
            reviewWords: reviewWords,
            onGameCompleted: onComplete,
            onContinueToNext: nil
        )
    }
}
