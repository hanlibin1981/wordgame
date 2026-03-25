import SwiftUI

/// Main game view for playing through a level
struct GameView: View {
    let book: WordBook
    let level: GameLevel?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameVM = GameViewModel()
    @State private var userAnswer = ""
    @State private var showResult = false
    /// Tracks whether audio is currently playing
    @State private var isAudioPlaying = false
    /// Tracks whether the last spelling/listening answer was correct (nil = no answer yet)
    @State private var lastAnswerCorrect: Bool?
    /// For star pop-in animation in game completed view
    @State private var visibleStars = 0
    /// Tracks the selected option in choice questions for visual feedback
    @State private var selectedOption: String?
    /// Consecutive wrong answer count for current question
    @State private var consecutiveWrongCount = 0
    /// Whether to show a hint after 3 consecutive wrong answers
    @State private var showHint = false
    /// Whether the current question has been passed (answered correctly)
    /// Stays true until the question changes
    @State private var hasPassedCurrentQuestion = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with progress
            gameHeader

            Divider()

            // Question area with transition animation
            ZStack {
                if gameVM.isGameCompleted {
                    gameCompletedView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if gameVM.isGameActive, let question = gameVM.currentQuestion {
                    questionArea(for: question)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                        .onDisappear {
                            if isAudioPlaying {
                                AudioService.shared.stop()
                                isAudioPlaying = false
                            }
                        }
                } else if gameVM.totalQuestions == 0 && !gameVM.isGameActive {
                    emptyStateView(message: "词库为空\n请先添加单词再开始学习")
                } else {
                    loadingView
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: gameVM.isGameCompleted)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: gameVM.currentQuestionIndex)
            .onChange(of: gameVM.currentQuestionIndex) { _, _ in
                userAnswer = ""
                showResult = false
                lastAnswerCorrect = nil
                consecutiveWrongCount = 0
                showHint = false
                selectedOption = nil
                hasPassedCurrentQuestion = false
            }
        }
        .onAppear {
            Task {
                await gameVM.startGame(for: book, level: level)
            }
        }
    }

    // MARK: - Header
    private var gameHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignFont.title2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Score
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.warningOrange)
                    Text("\(gameVM.score)")
                        .fontWeight(.bold)
                }

                Spacer()

                // Question counter
                Text("\(gameVM.currentQuestionIndex + 1) / \(gameVM.totalQuestions)")
                    .font(DesignFont.headline)
            }

            // Progress bar
            ProgressView(value: gameVM.progress)
                .tint(Color.primaryBlue)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: gameVM.progress)
        }
        .padding()
        .background(Color.backgroundMain)
    }

    // MARK: - Question Area
    @ViewBuilder
    private func questionArea(for question: GameQuestion) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Question content based on type
            switch question.questionType {
            case .choice:
                choiceQuestionView(for: question)
            case .spelling:
                spellingQuestionView(for: question)
            case .listening:
                listeningQuestionView(for: question)
            }

            Spacer()

            // Hint after 3 consecutive wrong answers
            if showHint, let correct = gameVM.currentQuestion?.correctAnswer {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.warningOrange)
                    Text("提示: 正确答案是「\(correct)」")
                        .font(DesignFont.subheadline)
                        .foregroundColor(.warningOrange)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.warningOrange.opacity(0.1))
                .cornerRadius(8)
            }

            // Navigation buttons
            HStack(spacing: 24) {
                if gameVM.currentQuestionIndex > 0 {
                    Button(action: { gameVM.goToPreviousQuestion() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("上一题")
                        }
                        .font(DesignFont.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if gameVM.currentQuestionIndex < gameVM.totalQuestions - 1 {
                    Button(action: { gameVM.goToNextQuestion() }) {
                        HStack(spacing: 4) {
                            Text("下一题")
                            Image(systemName: "chevron.right")
                        }
                        .font(DesignFont.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(hasPassedCurrentQuestion ? Color.primaryBlue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasPassedCurrentQuestion)
                }
            }
        }
        .padding()
    }

    // MARK: - Choice Question
    private func choiceQuestionView(for question: GameQuestion) -> some View {
        VStack(spacing: 24) {
            // Word display with subtle scale-in animation
            VStack(spacing: 8) {
                Text(question.word.word)
                    .font(DesignFont.largeTitle)
                    .scaleEffect(showResult ? 1.0 : 0.85)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showResult)

                if let phonetic = question.word.phonetic {
                    Text(phonetic)
                        .font(DesignFont.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                isAudioPlaying = true
                AudioService.shared.playWordAudio(word: question.word) {
                    DispatchQueue.main.async {
                        self.isAudioPlaying = false
                    }
                }
            }

            Text("请选择正确的中文释义")
                .font(DesignFont.headline)
                .foregroundStyle(.secondary)

            // Audio replay button
            Button(action: { replayAudio() }) {
                HStack(spacing: 6) {
                    Image(systemName: isAudioPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    Text(isAudioPlaying ? "正在播放..." : "再次播放")
                }
            }
            .foregroundColor(isAudioPlaying ? .secondary : .primaryBlue)
            .disabled(isAudioPlaying)

            // Options with spring entrance animation
            VStack(spacing: 12) {
                ForEach(Array((question.options ?? []).enumerated()), id: \.element) { index, option in
                    OptionButton(
                        text: option,
                        state: optionButtonState(for: option, correct: question.correctAnswer),
                        action: { selectOption(option) }
                    )
                    .disabled(isAudioPlaying)
                    .opacity(isAudioPlaying ? 0.5 : 1.0)
                    .transitionEffect(index: index)
                }
            }
        }
    }

    private func optionButtonState(for option: String, correct: String) -> OptionButtonState {
        guard showResult else { return .normal }
        if option == correct { return .correct }
        if option == selectedOption { return .wrong }
        return .normal
    }

    private func selectOption(_ option: String) {
        guard !showResult else { return }
        showResult = true
        selectedOption = option
        let isCorrect = option == (gameVM.currentQuestion?.correctAnswer ?? "")
        lastAnswerCorrect = isCorrect
        if isCorrect {
            hasPassedCurrentQuestion = true
        }
        Task {
            await gameVM.submitAnswer(option)
            if !isCorrect {
                consecutiveWrongCount += 1
                if consecutiveWrongCount >= 3 {
                    showHint = true
                }
            } else {
                consecutiveWrongCount = 0
                showHint = false
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            userAnswer = ""
            showResult = false
            lastAnswerCorrect = nil
            selectedOption = nil
        }
    }

    private func replayAudio() {
        guard !isAudioPlaying, let question = gameVM.currentQuestion else { return }
        isAudioPlaying = true
        AudioService.shared.playWordAudio(word: question.word) {
            DispatchQueue.main.async {
                self.isAudioPlaying = false
            }
        }
    }

    private func optionBackgroundColor(for option: String, question: GameQuestion) -> Color {
        if !showResult {
            return Color.gray.opacity(0.05)
        }
        if option == question.correctAnswer {
            return Color.successGreen.opacity(0.2)
        }
        if option == userAnswer && option != question.correctAnswer {
            return Color.errorRed.opacity(0.2)
        }
        return Color.gray.opacity(0.05)
    }

    // MARK: - Spelling Question
    private func spellingQuestionView(for question: GameQuestion) -> some View {
        VStack(spacing: 24) {
            // Meaning
            VStack(spacing: 8) {
                Text("请拼写这个单词")
                    .font(DesignFont.headline)
                    .foregroundStyle(.secondary)

                Text(question.word.meaning)
                    .font(DesignFont.title3)
            }
            .onAppear {
                isAudioPlaying = true
                AudioService.shared.playWordAudio(word: question.word) {
                    DispatchQueue.main.async {
                        self.isAudioPlaying = false
                    }
                }
            }

            // Sentence if available
            if let sentence = question.word.sentence, !sentence.isEmpty {
                Text(sentence)
                    .font(DesignFont.body)
                    .italic()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }

            // Audio replay button
            Button(action: { replayAudio() }) {
                HStack(spacing: 6) {
                    Image(systemName: isAudioPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    Text(isAudioPlaying ? "正在播放..." : "再次播放")
                }
            }
            .foregroundColor(isAudioPlaying ? .secondary : .primaryBlue)
            .disabled(isAudioPlaying)

            // Input field
            HStack(spacing: 12) {
                TextField("输入单词...", text: $userAnswer)
                    .font(DesignFont.title2)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isAudioPlaying || showResult)
                    .overlay {
                        if showResult, let correct = lastAnswerCorrect {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(correct ? Color.successGreen : Color.errorRed, lineWidth: 2)
                        }
                    }

                if showResult, let correct = lastAnswerCorrect {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(correct ? .successGreen : .errorRed)
                }
            }
            .onSubmit {
                submitSpelling()
            }

            Button(action: submitSpelling) {
                Text("确认")
                    .font(DesignFont.headline)
                    .frame(width: 120)
                    .padding()
                    .background(isAudioPlaying || userAnswer.isEmpty || showResult ? Color.gray : Color.primaryBlue)
                    .opacity(isAudioPlaying ? 0.5 : 1.0)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(isAudioPlaying || userAnswer.isEmpty || showResult)
        }
        .padding(.horizontal)
    }

    private func submitSpelling() {
        guard !userAnswer.isEmpty, !showResult, !isAudioPlaying else { return }
        let answer = userAnswer
        showResult = true
        Task {
            let isCorrect = answer.lowercased().trimmingCharacters(in: .whitespaces)
                == (gameVM.currentQuestion?.correctAnswer.lowercased() ?? "")
            lastAnswerCorrect = isCorrect
            if isCorrect {
                hasPassedCurrentQuestion = true
            } else {
                consecutiveWrongCount += 1
                if consecutiveWrongCount >= 3 {
                    showHint = true
                }
            }
            await gameVM.submitAnswer(answer)
            try? await Task.sleep(nanoseconds: 700_000_000)
            userAnswer = ""
            showResult = false
            lastAnswerCorrect = nil
        }
    }

    // MARK: - Listening Question
    private func listeningQuestionView(for question: GameQuestion) -> some View {
        VStack(spacing: 24) {
            // Auto-play on appear
            Color.clear
                .frame(width: 1, height: 1)
                .onAppear {
                    isAudioPlaying = true
                    AudioService.shared.playWordAudio(word: question.word) {
                        DispatchQueue.main.async {
                            self.isAudioPlaying = false
                        }
                    }
                }

            Text("听录音，写出单词")
                .font(DesignFont.headline)
                .foregroundStyle(.secondary)

            // Play/replay button
            Button(action: { replayAudio() }) {
                VStack(spacing: 8) {
                    Image(systemName: isAudioPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 40 * 2))
                    Text(isAudioPlaying ? "正在播放..." : "再次播放")
                        .font(DesignFont.caption)
                }
                .frame(width: 120, height: 120)
                .background(Color.primaryBlue.opacity(0.1))
                .cornerRadius(60)
            }
            .buttonStyle(.plain)
            .disabled(isAudioPlaying)

            // Hint
            if let sentence = question.word.sentence, !sentence.isEmpty {
                Text("提示: \(sentence)")
                    .font(DesignFont.caption)
                    .foregroundStyle(.secondary)
            }

            // Input
            HStack(spacing: 12) {
                TextField("输入单词...", text: $userAnswer)
                    .font(DesignFont.title2)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isAudioPlaying || showResult)
                    .overlay {
                        if showResult, let correct = lastAnswerCorrect {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(correct ? Color.successGreen : Color.errorRed, lineWidth: 2)
                        }
                    }

                if showResult, let correct = lastAnswerCorrect {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(correct ? .successGreen : .errorRed)
                }
            }
            .onSubmit {
                submitListeningAnswer()
            }

            Button(action: submitListeningAnswer) {
                Text("确认")
                    .font(DesignFont.headline)
                    .frame(width: 120)
                    .padding()
                    .background(isAudioPlaying || userAnswer.isEmpty || showResult ? Color.gray : Color.primaryBlue)
                    .opacity(isAudioPlaying ? 0.5 : 1.0)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(isAudioPlaying || userAnswer.isEmpty || showResult)
        }
    }

    private func submitListeningAnswer() {
        guard !userAnswer.isEmpty, !showResult else { return }
        let answer = userAnswer
        showResult = true
        Task {
            let isCorrect = answer.lowercased().trimmingCharacters(in: .whitespaces)
                == (gameVM.currentQuestion?.correctAnswer.lowercased() ?? "")
            lastAnswerCorrect = isCorrect
            if isCorrect {
                hasPassedCurrentQuestion = true
            } else {
                consecutiveWrongCount += 1
                if consecutiveWrongCount >= 3 {
                    showHint = true
                }
            }
            await gameVM.submitAnswer(answer)
            try? await Task.sleep(nanoseconds: 700_000_000)
            userAnswer = ""
            showResult = false
            lastAnswerCorrect = nil
        }
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("加载题目...")
                .font(DesignFont.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top)
        }
    }

    // MARK: - Empty State
    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 50 * 2))
                .foregroundStyle(.secondary)
            Text(message)
                .font(DesignFont.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("返回") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Game Completed
    private var gameCompletedView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Result icon
            if let result = gameVM.gameResult {
                Image(systemName: result.isPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 80 * 2))
                    .foregroundColor(result.isPassed ? .successGreen : .errorRed)

                Text(result.isPassed ? "恭喜通关!" : "继续加油!")
                    .font(DesignFont.largeTitle)

                // Stars with staggered bounce animation
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: result.starsEarned > index ? "star.fill" : "star")
                            .font(DesignFont.title)
                            .foregroundColor(.warningOrange)
                            .scaleEffect(visibleStars > index ? 1.0 : 0.5)
                            .opacity(visibleStars > index ? 1.0 : 0.3)
                            .sensoryFeedback(.success, trigger: visibleStars)
                    }
                }
                .onAppear {
                    // Stagger star pop-in one by one
                    for i in 0..<3 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(i) * 0.15)) {
                            visibleStars = i + 1
                        }
                    }
                }

                // Stats
                VStack(spacing: 12) {
                    HStack {
                        Text("正确")
                            .font(DesignFont.headline)
                        Spacer()
                        Text("\(result.correctCount)")
                            .font(DesignFont.headline)
                            .foregroundColor(.successGreen)
                    }

                    HStack {
                        Text("错误")
                            .font(DesignFont.headline)
                        Spacer()
                        Text("\(result.wrongCount)")
                            .font(DesignFont.headline)
                            .foregroundColor(.errorRed)
                    }

                    HStack {
                        Text("正确率")
                            .font(DesignFont.headline)
                        Spacer()
                        Text("\(Int(result.accuracy))%")
                            .font(DesignFont.headline)
                    }

                    HStack {
                        Text("得分")
                            .font(DesignFont.headline)
                        Spacer()
                        Text("\(result.score)")
                            .font(DesignFont.headline)
                            .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .frame(width: 250)
            }

            Spacer()

            // Actions
            VStack(spacing: 12) {
                Button(action: restartGame) {
                    HStack {
                        if gameVM.isSavingProgress {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        }
                        Text(gameVM.isSavingProgress ? "保存中..." : "再玩一次")
                    }
                    .font(DesignFont.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primaryBlue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(gameVM.isSavingProgress)

                Button(action: {
                    // Wait for progress save before navigating away
                    if !gameVM.isSavingProgress {
                        dismiss()
                    }
                }) {
                    HStack {
                        if gameVM.isSavingProgress {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        }
                        Text(gameVM.isSavingProgress ? "保存中..." : "返回")
                    }
                    .font(DesignFont.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                .disabled(gameVM.isSavingProgress)
            }
            .padding(.horizontal, 40)
            .padding(.bottom)
        }
    }

    private func restartGame() {
        visibleStars = 0
        Task {
            await gameVM.startGame(for: book, level: level)
        }
    }
}

// MARK: - Option Button with animation
enum OptionButtonState {
    case normal
    case correct
    case wrong

    var backgroundColor: Color {
        switch self {
        case .normal:   return Color.gray.opacity(0.05)
        case .correct:  return Color.successGreen.opacity(0.2)
        case .wrong:    return Color.errorRed.opacity(0.2)
        }
    }

    var borderColor: Color {
        switch self {
        case .normal:   return Color.gray.opacity(0.2)
        case .correct:  return Color.successGreen
        case .wrong:    return Color.errorRed
        }
    }
}

struct OptionButton: View {
    let text: String
    let state: OptionButtonState
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(DesignFont.option)
                .frame(maxWidth: .infinity)
                .padding()
                .background(state.backgroundColor)
                .foregroundColor(.primary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(state.borderColor, lineWidth: state == .normal ? 1 : 2)
                )
                .scaleEffect(isHovered && state == .normal ? 1.02 : 1.0)
                .shadow(
                    color: isHovered && state == .normal ? Color.black.opacity(0.08) : .clear,
                    radius: 4, x: 0, y: 2
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .sensoryFeedback(.selection, trigger: state)
    }
}

// MARK: - Transition Effect
struct TransitionEffect: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75).delay(Double(index) * 0.06)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func transitionEffect(index: Int) -> some View {
        modifier(TransitionEffect(index: index))
    }
}

#Preview {
    GameView(book: WordBook(name: "测试", wordCount: 100), level: nil)
}
