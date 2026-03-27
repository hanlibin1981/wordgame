import SwiftUI

// MARK: - Word Learning View
struct WordLearningView: View {
    let book: WordBook
    let level: GameLevel?
    let learningWords: [Word]
    let onStartGame: () -> Void
    let onDismiss: () -> Void

    @Binding var studiedWordIds: Set<String>
    @Binding var gamePhase: GamePhase

    @State private var localAudioPlaying: [String: Bool] = [:]

    private var allStudied: Bool {
        learningWords.allSatisfy { studiedWordIds.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            wordCardList
            bottomButton
        }
        .background(Color.backgroundMain)
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text("学习本关单词")
                .font(.system(size: 22, weight: .bold))

            Text("点击 ✓ 标记已学习，听完音频后再开始闯关")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            // Progress bar
            let total = max(1, learningWords.count)
            let studied = studiedWordIds.count
            HStack(spacing: 8) {
                ProgressView(value: Double(studied), total: Double(total))
                    .tint(studied == total ? Color.successGreen : Color.primaryBlue)

                Text("\(studied)/\(total)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(studied == total ? Color.successGreen : Color.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Word Card List
    private var wordCardList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(learningWords.enumerated()), id: \.element.id) { idx, word in
                    wordCard(for: word, index: idx)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
    }

    @ViewBuilder
    private func wordCard(for word: Word, index: Int) -> some View {
        LearningWordCard(
            word: word,
            index: index,
            isStudied: studiedWordIds.contains(word.id),
            isAudioPlaying: localAudioPlaying[word.id] ?? false,
            onStudy: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    _ = studiedWordIds.insert(word.id)
                }
            },
            onPlayAudio: {
                localAudioPlaying[word.id] = true
                AudioService.shared.playWordAudio(word: word) {
                    DispatchQueue.main.async {
                        localAudioPlaying[word.id] = false
                    }
                }
            }
        )
    }

    // MARK: - Bottom Button
    private var bottomButton: some View {
        VStack(spacing: 0) {
            Divider()

            Button(action: onStartGame) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("开始闯关")
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(allStudied ? Color.primaryBlue : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!allStudied)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Rectangle().fill(Color.cardBackground))
        }
    }
}

// MARK: - Learning Word Card
struct LearningWordCard: View {
    let word: Word
    let index: Int
    let isStudied: Bool
    let isAudioPlaying: Bool
    let onStudy: () -> Void
    let onPlayAudio: () -> Void

    @State private var isSentenceExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Studied checkmark / number
                Button(action: onStudy) {
                    ZStack {
                        Circle()
                            .fill(isStudied ? Color.successGreen : Color.gray.opacity(0.15))
                            .frame(width: 28, height: 28)

                        if isStudied {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

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

                    if let sentence = word.sentence, !sentence.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            // 可展开的例句区域
                            HStack(alignment: .top, spacing: 6) {
                                Text("例句：")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.warningOrange)
                                    .lineLimit(1)

                                Text(sentence)
                                    .font(.system(size: 15))
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .lineLimit(isSentenceExpanded ? nil : 2)

                                Spacer()

                                HStack(spacing: 8) {
                                    // 展开/收起按钮
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

                                    // 朗读按钮
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

                            // 展开时显示中文翻译
                            if isSentenceExpanded {
                                if let translation = word.sentenceTranslation, !translation.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("翻译：")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.primaryBlue)
                                        Text(translation)
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 6)
                                } else {
                                    Text("点击音频按钮听例句朗读")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
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
                Button(action: onPlayAudio) {
                    ZStack {
                        Circle()
                            .fill(Color.primaryBlue.opacity(0.1))
                            .frame(width: 40, height: 40)

                        Image(systemName: isAudioPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.primaryBlue)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isAudioPlaying)
            }
            .padding(16)

            if isStudied {
                HStack {
                    Spacer()
                    Text("已学习 ✓")
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
                .stroke(isStudied ? Color.successGreen.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(isStudied ? 0.06 : 0.04), radius: 6, x: 0, y: 2)
        .opacity(isStudied ? 0.85 : 1.0)
    }
}
