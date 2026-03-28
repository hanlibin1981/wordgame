import SwiftUI

/// Review view using Ebbinghaus spaced repetition method
struct ReviewView: View {
    let book: WordBook
    @StateObject private var learningVM = LearningViewModel()
    @StateObject private var gameVM = GameViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var studiedWordIds: Set<String> = []

    private var allStudied: Bool {
        !learningVM.reviewWords.isEmpty &&
        learningVM.reviewWords.allSatisfy { studiedWordIds.contains($0.id) }
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
        case .dueWords:
            return "暂无需要复习的单词"
        case .fallbackWords:
            return "当前没有到期内容"
        case .noPassedLevels:
            return "还没有可复习的内容"
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

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            wordCardList
            bottomButton
        }
        .background(Color.backgroundMain)
        .onAppear {
            Task {
                let levels = gameVM.generateLevels(for: book)
                await learningVM.loadEbbinghausReviewWords(for: book, levels: levels)
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text("艾宾浩斯复习")
                .font(.system(size: 22, weight: .bold))

            Text(subtitleText)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            if learningVM.reviewWords.isEmpty {
                Text(emptyStateTitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                let studied = studiedWordIds.count
                let total = learningVM.reviewWords.count
                HStack(spacing: 8) {
                    ProgressView(value: Double(studied), total: Double(total))
                        .tint(studied == total ? Color.successGreen : Color.warningOrange)

                    Text("\(studied)/\(total)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(studied == total ? Color.successGreen : .secondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Word Card List
    private var wordCardList: some View {
        ScrollView {
            if learningVM.reviewWords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.successGreen)
                    Text(emptyStateTitle)
                        .font(.system(size: 16, weight: .medium))
                    Text(emptyStateDescription)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(learningVM.reviewWords.enumerated()), id: \.element.id) { idx, word in
                        reviewWordCard(for: word, index: idx)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }
        }
    }

    @ViewBuilder
    private func reviewWordCard(for word: Word, index: Int) -> some View {
        ReviewWordCard(
            word: word,
            index: index,
            isStudied: studiedWordIds.contains(word.id)
        )
    }

    // MARK: - Bottom Button
    private var bottomButton: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                Button(action: {
                    // Mark all as studied
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        studiedWordIds = Set(learningVM.reviewWords.map { $0.id })
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("全部标记")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.successGreen)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("返回首页")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(allStudied ? Color.primaryBlue : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!allStudied)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Rectangle().fill(Color.cardBackground))
        }
        .onChange(of: learningVM.reviewWords) { _, _ in
            studiedWordIds = []
        }
    }
}

/// Word card for review mode
struct ReviewWordCard: View {
    let word: Word
    let index: Int
    let isStudied: Bool

    @State private var isSentenceExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Studied checkmark / number
                ZStack {
                    Circle()
                        .fill(isStudied ? Color.successGreen : Color.warningOrange.opacity(0.15))
                        .frame(width: 28, height: 28)

                    if isStudied {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.warningOrange)
                    }
                }

                // Word + phonetic + meaning
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(word.word)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)

                        if let phonetic = word.phonetic, !phonetic.isEmpty {
                            Text("/\(phonetic)/")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(word.meaning)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    // Mastery level indicator
                    HStack(spacing: 4) {
                        ForEach(0..<6, id: \.self) { level in
                            Circle()
                                .fill(level <= word.masteryLevel ? Color.successGreen : Color.gray.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }
                        Text("掌握度")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    if let sentence = word.sentence, !sentence.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 6) {
                                Text("例句：")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.warningOrange)
                                    .lineLimit(1)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(sentence)
                                        .font(.system(size: 22, weight: .regular))
                                        .foregroundColor(.secondary)
                                        .italic()
                                        .lineLimit(isSentenceExpanded ? nil : 2)

                                    if isSentenceExpanded, let translation = word.sentenceTranslation, !translation.isEmpty {
                                        Text(translation)
                                            .font(.system(size: 22, weight: .regular))
                                            .foregroundColor(.primaryBlue)
                                            .lineLimit(nil)
                                    }
                                }

                                Spacer()

                                HStack(spacing: 8) {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isSentenceExpanded.toggle()
                                        }
                                    }) {
                                        Image(systemName: isSentenceExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.warningOrange)
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: {
                                        AudioService.shared.speak(sentence)
                                    }) {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(.warningOrange)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.warningOrange.opacity(0.07))
                        .cornerRadius(6)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSentenceExpanded.toggle()
                            }
                        }
                    }
                }

                Spacer()

                // Audio button
                Button(action: {
                    AudioService.shared.playWordAudio(word: word) { }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.primaryBlue.opacity(0.1))
                            .frame(width: 40, height: 40)

                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.primaryBlue)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            if isStudied {
                HStack {
                    Spacer()
                    Text("已复习 ✓")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.successGreen)
                    Spacer()
                }
                .padding(.vertical, 8)
                .background(Color.successGreen.opacity(0.06))
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isStudied ? Color.successGreen.opacity(0.3) : Color.warningOrange.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isStudied ? 0.06 : 0.04), radius: 6, x: 0, y: 2)
        .opacity(isStudied ? 0.85 : 1.0)
    }
}
