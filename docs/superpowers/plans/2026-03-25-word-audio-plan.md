# Word Audio Auto-Play Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add auto-play audio to choice and spelling question types, with replay button and option-disabling during playback.

**Architecture:** Hybrid audio strategy: try online `audioUrl` first, fall back to local TTS. Questions auto-play on appear, options stay disabled until audio finishes.

**Tech Stack:** Swift, AVFoundation, AVSpeechSynthesizer, SwiftUI

---

## File Map

| File | Responsibility |
|------|----------------|
| `WordGame/Services/AudioService.swift` | Add `playWordAudio(word:)` method |
| `WordGame/Views/GameView.swift` | Add audio button, auto-play trigger, option disabling |

---

## Task 1: Add `playWordAudio` to AudioService

**Files:**
- Modify: `WordGame/Services/AudioService.swift`

- [ ] **Step 1: Add `playWordAudio(word: Word)` method to AudioService**

Read the current AudioService body first, then add this method after the existing `speakWithSay` method (around line 65):

```swift
/// Play word audio: try online URL first, fallback to local TTS
func playWordAudio(word: Word, onFinish: (() -> Void)? = nil) {
    // Stop any currently playing audio first
    stop()

    // Try online audio URL first
    if let urlString = word.audioUrl, let url = URL(string: urlString) {
        playFromURL(url) { [weak self] success in
            if !success {
                // Fallback to local TTS on failure
                self?.speakWithSay(word.word)
            }
            onFinish?()
        }
    } else {
        // No URL, use local TTS directly
        speakWithSay(word.word)
        onFinish?()
    }
}

private func playFromURL(_ url: URL, onComplete: @escaping (Bool) -> Void) {
    isPlaying = true
    DispatchQueue.global().async { [weak self] in
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            self?.audioPlayer = player
            player.prepareToPlay()
            player.play()

            // Poll for playback completion
            DispatchQueue.global().async {
                while player.isPlaying {
                    Thread.sleep(forTimeInterval: 0.1)
                }
                DispatchQueue.main.async {
                    self?.isPlaying = false
                    onComplete(true)
                }
            }
        } catch {
            DispatchQueue.main.async {
                self?.isPlaying = false
                onComplete(false)
            }
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `xcodebuild -project WordGame.xcodeproj -scheme WordGame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|warning:|BUILD"`

Expected: BUILD SUCCEEDED (or same warnings as before)

- [ ] **Step 3: Commit**

```bash
git add WordGame/Services/AudioService.swift
git commit -m "feat: add playWordAudio with URL-first TTS fallback"
```

---

## Task 2: Add Audio Button and Auto-Play to GameView

**Files:**
- Modify: `WordGame/Views/GameView.swift`

First, read the full GameView structure to understand where to insert code:

- [ ] **Step 1: Read GameView structure**

```bash
# Read lines 1-30 to see @State properties
# Read choiceQuestionView (lines 108-145)
# Read spellingQuestionView (lines 155-230)
```

- [ ] **Step 2: Add @State properties for audio tracking**

Add after the existing `@State private var showResult = false` line (find exact location by reading file):

```swift
@State private var isAudioPlaying = false
@State private var autoPlayTrigger = false
```

- [ ] **Step 3: Modify `questionArea(for:)` to trigger auto-play for choice/spelling**

Read the `questionArea(for:)` method (around lines 85-100). Find where it switches on question type. For choice and spelling types, set `autoPlayTrigger.toggle()` to fire the `.onChange`.

Add `.onChange(of: autoPlayTrigger) { _ in ... }` modifier to the question container VStack in `questionArea(for:)`, or add it directly inside `choiceQuestionView` and `spellingQuestionView` as `.onAppear`.

**Simplest approach**: Add `onAppear` to `choiceQuestionView` and `spellingQuestionView` that calls audio:

```swift
.onAppear {
    if question.questionType != .listening {
        AudioService.shared.playWordAudio(word: question.word) { [weak self] in
            self?.isAudioPlaying = false
        }
        isAudioPlaying = true
    }
}
```

Note: The `onAppear` fires every time the view appears. Since SwiftUI recreates the question view on each new question, this works.

- [ ] **Step 4: Add replay button to choiceQuestionView**

In `choiceQuestionView` (after the word display block, before the "请选择正确的中文释义" Text), add:

```swift
// Audio replay button
Button(action: {
    if !isAudioPlaying {
        isAudioPlaying = true
        AudioService.shared.playWordAudio(word: question.word) { [weak self] in
            self?.isAudioPlaying = false
        }
    }
}) {
    HStack(spacing: 6) {
        Image(systemName: isAudioPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
            .font(.system(size: 16))
        Text(isAudioPlaying ? "正在播放..." : "再次播放")
            .font(DesignFont.caption)
    }
    .foregroundColor(isAudioPlaying ? .secondary : .primaryBlue)
}
.buttonStyle(.plain)
```

- [ ] **Step 5: Add replay button to spellingQuestionView**

In `spellingQuestionView`, find the same spot (after meaning display, before the input field) and add the same button code.

- [ ] **Step 6: Disable options while audio is playing in choiceQuestionView**

Find the `ForEach` options block in `choiceQuestionView`. Wrap the `OptionButton` in a disabled state or add `.disabled(isAudioPlaying)`:

```swift
ForEach(Array((question.options ?? []).enumerated()), id: \.element) { index, option in
    OptionButton(
        text: option,
        state: optionButtonState(for: option, correct: question.correctAnswer),
        action: { selectOption(option) }
    )
    .disabled(isAudioPlaying)  // ADD THIS
    .opacity(isAudioPlaying ? 0.5 : 1.0)  // ADD THIS for visual feedback
    .transitionEffect(index: index)
}
```

- [ ] **Step 7: Disable submit button while audio is playing in spellingQuestionView**

Find the submit Button in `spellingQuestionView`. Add:

```swift
.disabled(isAudioPlaying || userAnswer.isEmpty || showResult)
.opacity(isAudioPlaying ? 0.5 : 1.0)
```

Also disable the TextField:

```swift
TextField("输入单词...", text: $userAnswer)
    .disabled(isAudioPlaying || showResult)
```

- [ ] **Step 8: Verify build**

Run: `xcodebuild -project WordGame.xcodeproj -scheme WordGame -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"`

Expected: BUILD SUCCEEDED

- [ ] **Step 9: Commit**

```bash
git add WordGame/Views/GameView.swift
git commit -m "feat: add audio auto-play and replay button to choice/spelling questions"
```

---

## Task 3: Verify End-to-End Flow

- [ ] **Step 1: Open Xcode and run on simulator**

```bash
open WordGame.xcodeproj
```

Then in Xcode: select iPhone simulator, press Cmd+R.

- [ ] **Step 2: Test manually**

1. Start a game at Chapter 1, Stage 1
2. Verify audio plays automatically when question appears
3. Verify options are disabled (grayed out) while audio plays
4. Verify options become enabled after audio finishes
5. Tap "再次播放" button to replay audio
6. Complete stage 3 and verify boss level unlocks
7. Verify boss level also has audio auto-play

Expected: All behaviors match design spec.
