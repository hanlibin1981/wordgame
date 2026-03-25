# Word Audio Auto-Play Design

## Overview

Add audio playback to choice and spelling question types in the game. Listening questions already have audio and remain unchanged.

## Audio Source Strategy (Hybrid)

1. **Primary**: `word.audioUrl` — online audio URL stored in database
2. **Fallback**: Local TTS via `speakWithSay()` — always available, no network needed

When a question appears, the system tries `audioUrl` first. If missing or load fails, falls back to local TTS.

## Interaction Flow

- Question appears → auto-play audio immediately
- Options/buttons remain disabled while audio is playing
- After audio finishes → options enabled, replay button available
- User can tap replay button to re-play audio at any time

## Question Types

| Type | Before | After |
|------|--------|-------|
| Choice | No audio | Auto-play + replay button |
| Spelling | No audio | Auto-play + replay button |
| Listening | Has replay button (manual) | Unchanged |

## Implementation

### AudioService.swift

Add `playWordAudio(word: Word)` method:

```swift
func playWordAudio(word: Word) {
    // 1. Try audioUrl first
    if let urlString = word.audioUrl, let url = URL(string: urlString) {
        playFromURL(url) { [weak self] in
            // on finish
        }
    } else {
        // 2. Fallback to local TTS
        speakWithSay(word.word)
    }
}
```

### GameView.swift

- Add `@State private var isAudioPlaying = false` to track playback state
- On `questionArea(for:)` call, trigger auto-play
- Pass `isAudioPlaying` to `choiceQuestionView` and `spellingQuestionView`
- Wrap option buttons in `disabled(isAudioPlaying)` or use overlay blocking

### Auto-play Trigger

The game already has `currentQuestionStartTime` which resets when a new question begins. Use this or a simple `@State private var autoPlayTrigger = false` that flips on each new question to trigger the `.onChange` listener.

## UI Design

```
┌─────────────────────────┐
│        apple            │
│       /ˈæpəl/           │
│                         │
│  🔊 正在播放...          │  ← button disabled, text "playing"
│                         │
│  [  苹果  ] [  香蕉  ]  │  ← buttons disabled (grayed)
│  [  橙子  ] [  葡萄  ]  │
└─────────────────────────┘
```

After audio finishes:

```
│  🔊 再次播放             │  ← button enabled
```

## Edge Cases

- **Audio load fails**: silently fall back to TTS, no error shown to user
- **User taps replay during auto-play**: restart audio (stop current first)
- **Question changes while audio playing**: stop current audio, play new question's audio
- **Multiple rapid question advances**: only play audio for most recent question

## Files to Modify

- `WordGame/Services/AudioService.swift` — add `playWordAudio`
- `WordGame/Views/GameView.swift` — add audio button, auto-play, button disabling
