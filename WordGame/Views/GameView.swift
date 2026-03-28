import SwiftUI

// MARK: - Game Phase
enum GamePhase {
    case learning
    case playing
    case completed
}

// MARK: - Main Game View
/// Main game view for playing through a level
struct GameView: View {
    let book: WordBook
    let level: GameLevel?
    /// When true, runs in review mode — skips learning phase, uses provided word pool
    var isReviewMode: Bool = false
    /// Words to use in review mode (only used when isReviewMode == true)
    var reviewWords: [Word] = []
    /// Callback when user wants to continue to the next level.
    /// Called with (book, nextLevel) when tapped, nil when no next level.
    var onContinueToNext: ((WordBook, GameLevel) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameVM = GameViewModel()
    @State private var userAnswer = ""
    /// Focus state for spelling/listening input field auto-focus after audio.
    @FocusState private var isInputFocused: Bool
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
    /// Maps question index → whether that question has been correctly answered.
    /// Used to restore "下一题" button state when navigating backwards.
    @State private var answeredCorrectly: [Int: Bool] = [:]
    /// Pending UI resets to apply after the current Task completes.
    /// Prevents state from being cleared while an async auto-advance Task is running.
    @State private var pendingReset: (() -> Void)?
    /// Current game phase: learning → playing → completed
    /// In review mode, start directly at .playing (skip learning phase)
    @State private var gamePhase: GamePhase = .learning
    /// Set of word IDs that have been marked as studied in the learning phase
    @State private var studiedWordIds: Set<String> = []
    /// Prevent duplicate auto-play when SwiftUI re-renders the same question view.
    @State private var lastAutoPlayedQuestionID: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header with progress
            gameHeader

            Divider()

            // Phase-based content
            ZStack {
                switch gamePhase {
                case .learning:
                    wordLearningView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))

                case .playing:
                    if gameVM.isGameActive, let question = gameVM.currentQuestion {
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
                    } else if gameVM.totalQuestions == 0 {
                        emptyStateView(message: "词库为空\n请先添加单词再开始学习")
                    } else {
                        loadingView
                    }

                case .completed:
                    gameCompletedView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: gamePhase)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: gameVM.currentQuestionIndex)
            .onChange(of: gameVM.currentQuestionIndex) { oldIndex, newIndex in
                // Apply any pending reset from the previous question's answer processing
                pendingReset?()
                pendingReset = nil
                lastAutoPlayedQuestionID = nil
                // Reset UI state for the new question
                userAnswer = ""
                showResult = false
                lastAnswerCorrect = nil
                consecutiveWrongCount = 0
                showHint = false
                selectedOption = nil
            }
        }
        .onAppear {
            Task {
                if isReviewMode {
                    // Review mode: skip learning phase, start questions immediately
                    gamePhase = .playing
                    await gameVM.startReviewGame(for: book, level: level!, reviewWords: reviewWords)
                } else {
                    // Normal mode: start with learning phase
                    await gameVM.startGame(for: book, level: level)
                }
            }
        }
        .onChange(of: gameVM.isGameCompleted) { _, completed in
            if completed {
                gamePhase = .completed
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

    // MARK: - Word Learning Phase
    private var wordLearningView: some View {
        WordLearningView(
            book: book,
            level: level,
            learningWords: gameVM.learningWords,
            onStartGame: startGameplay,
            onDismiss: { dismiss() },
            studiedWordIds: $studiedWordIds,
            gamePhase: $gamePhase
        )
    }

    /// Transition from learning phase to playing phase and start the game.
    /// No-op in review mode since we start directly in playing phase.
    private func startGameplay() {
        guard !isReviewMode else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            gamePhase = .playing
        }
        // Clear studiedWordIds for new game session
        studiedWordIds = []
        lastAutoPlayedQuestionID = nil
        gameVM.markCurrentQuestionPresented()
    }

    private func autoPlayAudioIfNeeded(for question: GameQuestion, focusInputAfterPlayback: Bool = false) {
        guard lastAutoPlayedQuestionID != question.id else { return }
        lastAutoPlayedQuestionID = question.id
        isAudioPlaying = true
        if focusInputAfterPlayback {
            isInputFocused = false
        }
        AudioService.shared.playWordAudio(word: question.word) {
            DispatchQueue.main.async {
                self.isAudioPlaying = false
                if focusInputAfterPlayback {
                    self.isInputFocused = true
                }
            }
        }
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

                // Only show "下一题" for choice questions (spelling/listening auto-advance)
                if gameVM.currentQuestionIndex < gameVM.totalQuestions - 1,
                   question.questionType == .choice {
                    Button(action: { gameVM.goToNextQuestion() }) {
                        HStack(spacing: 4) {
                            Text("下一题")
                            Image(systemName: "chevron.right")
                        }
                        .font(DesignFont.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(answeredCorrectly[gameVM.currentQuestionIndex] == true ? Color.primaryBlue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(answeredCorrectly[gameVM.currentQuestionIndex] != true)
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
                autoPlayAudioIfNeeded(for: question)
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
            answeredCorrectly[gameVM.currentQuestionIndex] = true
        }

        // Capture reset closure — applied when the auto-advance Task finishes
        // (or immediately if no auto-advance is needed for wrong answers)
        let reset = {
            self.userAnswer = ""
            self.showResult = false
            self.lastAnswerCorrect = nil
            self.selectedOption = nil
        }

        Task {
            await gameVM.submitAnswer(option)
            if !isCorrect {
                // All question types increment consecutiveWrongCount inside Task for consistency
                self.consecutiveWrongCount += 1
                if self.consecutiveWrongCount >= 3 {
                    self.showHint = true
                }
                // Wrong answer: user must use navigation buttons
                reset()
                self.pendingReset = nil
            } else {
                self.consecutiveWrongCount = 0
                self.showHint = false
                // Auto-advance after correct answer
                try? await Task.sleep(nanoseconds: 500_000_000)
                if self.gameVM.currentQuestionIndex + 1 < self.gameVM.totalQuestions {
                    self.gameVM.goToNextQuestion()
                } else {
                    await self.gameVM.endGame()
                }
                reset()
                self.pendingReset = nil
            }
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
                autoPlayAudioIfNeeded(for: question, focusInputAfterPlayback: true)
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

            // Input field - centered with fixed width
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    TextField("输入单词...", text: $userAnswer)
                        .font(DesignFont.title2)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                        .disabled(isAudioPlaying || showResult)
                        .focused($isInputFocused)
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
        let isCorrect = answer.lowercased().trimmingCharacters(in: .whitespaces)
            == (gameVM.currentQuestion?.correctAnswer.lowercased() ?? "")
        lastAnswerCorrect = isCorrect
        if isCorrect {
            answeredCorrectly[gameVM.currentQuestionIndex] = true
        }

        let reset = {
            self.userAnswer = ""
            self.showResult = false
            self.lastAnswerCorrect = nil
        }

        Task {
            await gameVM.submitAnswer(answer)
            if !isCorrect {
                self.consecutiveWrongCount += 1
                if self.consecutiveWrongCount >= 3 {
                    self.showHint = true
                }
                reset()
            } else {
                self.consecutiveWrongCount = 0
                self.showHint = false
                try? await Task.sleep(nanoseconds: 700_000_000)
                if self.gameVM.currentQuestionIndex + 1 < self.gameVM.totalQuestions {
                    self.gameVM.goToNextQuestion()
                } else {
                    await self.gameVM.endGame()
                }
                reset()
            }
        }
    }

    // MARK: - Listening Question
    private func listeningQuestionView(for question: GameQuestion) -> some View {
        VStack(spacing: 24) {
            // Auto-play on appear
            Color.clear
                .frame(width: 1, height: 1)
                .onAppear {
                    autoPlayAudioIfNeeded(for: question, focusInputAfterPlayback: true)
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

            // Input - centered with fixed width
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    TextField("输入单词...", text: $userAnswer)
                        .font(DesignFont.title2)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                        .disabled(isAudioPlaying || showResult)
                        .focused($isInputFocused)
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
        let isCorrect = answer.lowercased().trimmingCharacters(in: .whitespaces)
            == (gameVM.currentQuestion?.correctAnswer.lowercased() ?? "")
        lastAnswerCorrect = isCorrect
        if isCorrect {
            answeredCorrectly[gameVM.currentQuestionIndex] = true
        }

        let reset = {
            self.userAnswer = ""
            self.showResult = false
            self.lastAnswerCorrect = nil
        }

        Task {
            await gameVM.submitAnswer(answer)
            if !isCorrect {
                self.consecutiveWrongCount += 1
                if self.consecutiveWrongCount >= 3 {
                    self.showHint = true
                }
                reset()
            } else {
                self.consecutiveWrongCount = 0
                self.showHint = false
                try? await Task.sleep(nanoseconds: 700_000_000)
                if self.gameVM.currentQuestionIndex + 1 < self.gameVM.totalQuestions {
                    self.gameVM.goToNextQuestion()
                } else {
                    await self.gameVM.endGame()
                }
                reset()
            }
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
        ZStack {
            Color.backgroundMain
                .ignoresSafeArea()

            if let result = gameVM.gameResult {
                // Main content card — centered, max-width, with sticky bottom buttons
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 28) {
                            // ── Header: icon + title + stars ──
                            completionHeader(result: result)

                            Divider()

                            // ── Stats: 2×2 grid with large numbers ──
                            statsGrid(result: result)

                            // ── Per-question breakdown ──
                            questionBreakdown
                        }
                        .padding(28)
                    }
                    .frame(maxWidth: 520)

                    // ── Sticky action buttons ──
                    actionButtons
                }
                .background(Color.cardBackground)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 8)
                .frame(maxWidth: 540, maxHeight: 680)
            }
        }
        .onAppear {
            // Kick off star animations when view appears
            guard visibleStars == 0 else { return }
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        visibleStars = i + 1
                    }
                }
            }
        }
    }

    // MARK: - Completion Header
    private func completionHeader(result: GameResult) -> some View {
        VStack(spacing: 16) {
            // Result icon with ambient ring
            ZStack {
                Circle()
                    .fill(result.isPassed
                          ? Color.successGreen.opacity(0.12)
                          : Color.errorRed.opacity(0.12))
                    .frame(width: 120, height: 120)

                Circle()
                    .stroke(result.isPassed ? Color.successGreen.opacity(0.3) : Color.errorRed.opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)

                Image(systemName: result.isPassed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(result.isPassed ? .successGreen : .errorRed)
            }
            .scaleEffect(visibleStars > 0 ? 1.0 : 0.6)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: visibleStars)

            // Title
            Text(result.isPassed
                 ? (isReviewMode ? "复习完成!" : "恭喜通关!")
                 : (isReviewMode ? "继续加油!" : "继续加油!"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(result.isPassed ? .successGreen : .errorRed)

            // Stars
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    starView(index: index, earned: result.starsEarned)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Star View
    private func starView(index: Int, earned: Int) -> some View {
        Image(systemName: earned > index ? "star.fill" : "star")
            .font(.system(size: 32))
            .foregroundColor(.warningOrange)
            .shadow(color: earned > index ? .warningOrange.opacity(0.4) : .clear, radius: 6)
            .scaleEffect(visibleStars > index ? 1.0 : 0.5)
            .opacity(visibleStars > index ? 1.0 : 0.3)
            .sensoryFeedback(.success, trigger: visibleStars)
    }

    // MARK: - Stats Grid
    private func statsGrid(result: GameResult) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            StatCell(
                icon: "checkmark.circle.fill",
                iconColor: .successGreen,
                value: "\(result.correctCount)",
                label: "正确",
                valueColor: .successGreen
            )

            StatCell(
                icon: "xmark.circle.fill",
                iconColor: .errorRed,
                value: "\(result.wrongCount)",
                label: "错误",
                valueColor: .errorRed
            )

            StatCell(
                icon: "percent",
                iconColor: .primaryBlue,
                value: "\(Int(result.accuracy))%",
                label: "正确率",
                valueColor: .primaryBlue
            )

            StatCell(
                icon: "star.fill",
                iconColor: .warningOrange,
                value: "\(result.score)",
                label: "得分",
                valueColor: .warningOrange
            )
        }
    }

    // MARK: - Question Breakdown
    private var questionBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("答题详情")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(gameVM.questions.enumerated()), id: \.offset) { index, question in
                    let correct = question.isCorrect == true

                    HStack(spacing: 12) {
                        // Status icon
                        Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(correct ? .successGreen : .errorRed)
                            .frame(width: 20)

                        // Question number + word
                        VStack(alignment: .leading, spacing: 2) {
                            Text("第\(index + 1)题")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)

                            Text(question.word.word)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(correct ? .secondary : .primary)
                        }

                        Spacer()

                        // Wrong answer display
                        if !correct {
                            Text("「\(question.correctAnswer)」")
                                .font(.system(size: 13))
                                .foregroundColor(.errorRed)
                                .lineLimit(1)
                        } else {
                            Text(question.word.meaning)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(index % 2 == 0 ? Color.clear : Color.gray.opacity(0.04))

                    if index < gameVM.questions.count - 1 {
                        Divider()
                    }
                }
            }
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.12), lineWidth: 1)
            )
        }
    }

    // MARK: - Next Level
    /// The next level to continue to, based on current progress.
    /// Nil when all levels are completed.
    private var nextLevel: GameLevel? {
        guard gameVM.gameResult?.isPassed == true else { return nil }
        let allLevels = gameVM.generateLevels(for: book)
        return allLevels.first { lvl in
            let record = try? DatabaseService.shared.fetchLevelRecord(
                bookId: book.id, chapter: lvl.chapter, stage: lvl.isBossLevel ? 4 : lvl.stage
            )
            return !(record?.isPassed ?? false)
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 10) {
            Divider()

            if gameVM.isSavingProgress {
                HStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                    Text("保存中...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                VStack(spacing: 8) {
                    if let lvl = nextLevel {
                        Button(action: {
                            onContinueToNext?(book, lvl)
                            dismiss()
                        }) {
                            HStack {
                                Text("下一关")
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.successGreen)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: restartGame) {
                        Text(isReviewMode
                             ? (gameVM.gameResult?.isPassed == true ? "再复习一次" : "重新挑战")
                             : (gameVM.gameResult?.isPassed == true ? "再玩一次" : "重新挑战"))
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.primaryBlue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if !gameVM.isSavingProgress {
                            dismiss()
                        }
                    }) {
                        Text("返回")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.cardBackground)
    }

    // MARK: - Stat Cell Component
    private struct StatCell: View {
        let icon: String
        let iconColor: Color
        let value: String
        let label: String
        let valueColor: Color

        var body: some View {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)
                    Text(label)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(valueColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(iconColor.opacity(0.08))
            .cornerRadius(12)
        }
    }

    private func restartGame() {
        visibleStars = 0
        studiedWordIds = []
        lastAutoPlayedQuestionID = nil
        Task {
            if isReviewMode {
                gamePhase = .playing
                await gameVM.startReviewGame(for: book, level: level!, reviewWords: reviewWords)
            } else {
                await gameVM.startGame(for: book, level: level)
            }
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
