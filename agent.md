# LumaLex

## 1. Product

LumaLex is a native iOS English listening and vocabulary-learning application.

Core loop:

Listen → Understand → Capture → Review → Learn

The app should allow users to import English audio, generate or import transcripts, display synchronized subtitles, tap unknown words, save them, and review them using spaced repetition.

The product should feel like a first-party Apple application.

Avoid unnecessary UI elements, excessive cards, gradients, complex navigation, gamification, and verbose onboarding.

Primary visual language:

* Native iOS
* SwiftUI
* White background
* Apple-style blue accent
* SF Symbols
* Large whitespace
* System typography
* Subtle materials where appropriate
* Dark Mode support
* Accessibility support

---

# 2. Technology Stack

Client:

* Swift
* SwiftUI
* AVFoundation
* ActivityKit
* WidgetKit
* MediaPlayer
* NaturalLanguage
* Speech framework where appropriate

Architecture:

* MVVM
* async/await
* SwiftData for local persistence
* Repository layer for remote services

Backend/API integrations:

* Gemini API for vocabulary explanations
* Speech-to-text provider abstraction
* Translation provider abstraction

Do NOT hard-code API keys in the iOS application.

Use environment/configuration abstraction during development and a backend proxy for production.

---

# 3. Navigation

Main application tabs:

1. Today
2. Library
3. Vocabulary
4. Profile

The audio player should NOT be a tab.

When audio is playing, show a native-style mini player above the tab bar.

Tapping the mini player opens the full player.

---

# 4. First Launch

On first launch:

Welcome
↓
Vocabulary Assessment
↓
Estimated Vocabulary Size
↓
Home

Do not create a long onboarding flow.

The vocabulary assessment should present only an approximate vocabulary size.
Do not show an assessment score or CEFR level as the result.
CEFR may be inferred internally from the estimate for personalization and AI prompts.

CEFR:

A1
A2
B1
B2
C1
C2

Store:

UserProfile {
estimatedVocabulary
assessmentDate
}

The assessment engine should be isolated behind a protocol so the algorithm can be replaced later.

---

# 5. Today

This is the default home screen.

Primary content:

Good morning

18 words today

[ Start Review ]

## Continue Listening

Current audio
32:14 remaining

The page should immediately answer:

1. What should I learn today?
2. What was I listening to?
3. How much work remains?

Do not show unnecessary statistics.

---

# 6. Audio Import

Users can import:

* MP3
* M4A
* WAV
* compatible audio files
* transcript files

When audio is imported:

if transcript exists:
parse transcript
else:
run speech-to-text

Processing pipeline:

Audio
↓
Transcription
↓
Timestamp alignment
↓
Sentence segmentation
↓
Translation
↓
Vocabulary difficulty analysis
↓
Save locally

Every subtitle segment must contain timestamps.

SubtitleSegment {
id
startTime
endTime
english
chinese
tokens[]
}

---

# 7. Player

Use AVFoundation.

Required controls:

* Play/Pause
* ±15 seconds
* progress bar
* playback speed
* subtitle mode
* AirPlay
* audio route controls

Playback speeds:

0.75×
1×
1.25×
1.5×
2×

The active subtitle sentence should follow audio playback automatically.

The user must be able to scroll backward through subtitles.

After manual scrolling, provide a button to return to the currently playing sentence.

---

# 8. Subtitle Modes

Exactly four primary modes:

### Bilingual

English subtitle
Chinese translation

Example:

The market has already priced in the cut.

市场已经消化了降息预期。

### English

The market has already priced in the cut.

### Difficult Words

Only emphasize vocabulary judged difficult relative to the user's level.

Example:

The market has already **priced in** the cut.

### Focus

No subtitles.

Audio only.

Switching modes must not interrupt playback.

---

# 9. Interactive Words

Words and supported phrases inside subtitles must be tappable.

Tap:

word
↓
bottom sheet

Show:

word
pronunciation
Chinese meaning
short English definition
meaning in current context

Actions:

[ Add to Vocabulary ]

Do not interrupt playback unless the user explicitly pauses it.

Long-press may provide additional actions later.

---

# 10. Vocabulary Model

VocabularyItem {
id: UUID
word: String
lemma: String
pronunciation: String?
partOfSpeech: String?
chineseMeaning: String
englishDefinition: String
originalSentence: String
sourceAudioID: UUID?
createdAt: Date
reviewStage: Int
nextReviewDate: Date
status: VocabularyStatus
}

VocabularyStatus:

learning
learned

---

# 11. Spaced Repetition

Initial schedule:

Stage 0 → Day 0
Stage 1 → Day 2
Stage 2 → Day 5
Stage 3 → Day 10
Stage 4 → Learned

These offsets are measured from the successful review that advances the stage.

Review flow:

Display:

price in

The user attempts to remember the meaning.

Tap:

[ Reveal ]

Then show:

将……计入价格 / 市场已经消化……

The market has already priced in the cut.

User chooses:

[ Forgot ]
[ Remember ]

If Remember:

stage += 1

If stage == 4:

status = learned

Otherwise calculate the next review date.

If Forgot:

stage = 0

Schedule the item according to the Stage 0 policy.

The scheduling engine must be implemented independently from UI code.

Create:

ReviewScheduler

with testable pure functions.

---

# 12. Review Screen

Keep the review UI extremely simple.

Before reveal:

price in

/ˌpraɪs ˈɪn/

[ Reveal ]

After reveal:

price in

将……计入价格

"to already reflect something expected in the current price"

The market has already priced in the cut.

[ Forgot ]        [ Remember ]

Show progress at the top:

7 / 18

No distracting animations.

Use subtle haptic feedback.

---

# 13. Learned Vocabulary

Words that successfully complete all four review stages move to:

Learned

Keep history.

Do NOT delete the original learning information.

Users should be able to search:

* Learning
* Learned
* All

---

# 14. Gemini Vocabulary Engine

Create:

GeminiVocabularyService

Input:

* word
* sentence
* user CEFR level

The service should request structured JSON.

Prompt template:

You are the vocabulary explanation engine for an English-learning application.

USER LEVEL:
{{CEFR_LEVEL}}

TARGET WORD OR PHRASE:
{{WORD}}

ORIGINAL CONTEXT:
{{CONTEXT}}

Your task is to explain the target expression specifically according to its meaning in this context.

Requirements:

1. Give the most contextually appropriate Simplified Chinese meaning.
2. Give a concise English definition appropriate for the user's CEFR level.
3. Provide IPA pronunciation when applicable.
4. Identify the part of speech or phrase type.
5. Briefly explain why this meaning applies in the sentence.
6. Provide one natural example sentence using the same meaning.
7. Provide up to three useful collocations.
8. Mention if the expression is technical, idiomatic, informal, formal, uncommon, or domain-specific.
9. Do not list irrelevant dictionary meanings.
10. Keep the response concise.
11. Never include Markdown.
12. Return valid JSON only.

JSON schema:

{
"word": "",
"lemma": "",
"ipa": "",
"part_of_speech": "",
"chinese": "",
"definition": "",
"context_explanation": "",
"example": "",
"collocations": [],
"difficulty_cefr": "",
"note": ""
}

The decoder must fail gracefully if Gemini returns malformed data.

Never directly render arbitrary model output as application UI.

Decode it into a strongly typed Swift model first.

---

# 15. Difficulty Detection

Difficulty should be personalized.

A word should not simply be classified as "difficult" globally.

Consider:

* user's CEFR level
* estimated vocabulary size
* frequency
* phrase frequency
* context
* technical terminology
* whether the user previously marked the word as known
* whether the word is already in Learned

Create:

VocabularyDifficultyService

Return:

known
normal
difficult
specialized

This architecture must allow the algorithm to be replaced later.

---

# 16. Lock Screen

Use Apple's supported system surfaces.

Required:

* Now Playing integration
* Live Activities
* Lock Screen controls

When technically permitted, show the current subtitle segment in the Live Activity.

Preferred layout:

English sentence

Chinese translation

────────────

Podcast Name        14:32

Keep Lock Screen UI extremely minimal.

Do not attempt to create unsupported always-on overlays above the iOS system UI.

Respect ActivityKit update limits and system behavior.

---

# 17. Dynamic Island

Support devices with Dynamic Island.

Compact:

audio indicator + short playback state

Expanded:

current English subtitle

optional Chinese subtitle

playback information

Do not attempt to continuously redraw every word.

Update primarily when the active subtitle segment changes, subject to iOS ActivityKit limitations.

---

# 18. Background Audio

Audio must continue when:

* screen locks
* application enters background
* user switches applications

Integrate with system Now Playing information.

Support:

play
pause
seek

from supported system controls.

---

# 19. Data Architecture

SwiftData models:

UserProfile

AudioDocument

Transcript

SubtitleSegment

VocabularyItem

ReviewRecord

ReviewRecord:

ReviewRecord {
id
vocabularyID
date
result
previousStage
newStage
}

Never discard review history.

---

# 20. Suggested Project Structure

LumaLex/

App/
LumaLexApp.swift
AppRouter.swift

Models/
UserProfile.swift
AudioDocument.swift
SubtitleSegment.swift
VocabularyItem.swift
ReviewRecord.swift

Views/

```
Today/
    TodayView.swift

Assessment/
    AssessmentView.swift
    AssessmentResultView.swift

Library/
    LibraryView.swift
    ImportView.swift

Player/
    PlayerView.swift
    MiniPlayerView.swift
    SubtitleView.swift
    SubtitleWordView.swift
    VocabularySheet.swift

Vocabulary/
    VocabularyView.swift
    ReviewView.swift
    LearnedView.swift

Profile/
    ProfileView.swift
```

Services/

```
Audio/
    AudioPlayerService.swift

Transcription/
    TranscriptionService.swift

Translation/
    TranslationService.swift

Vocabulary/
    GeminiVocabularyService.swift
    VocabularyDifficultyService.swift

Review/
    ReviewScheduler.swift
```

Persistence/

```
Database.swift
Repositories/
```

LiveActivity/

```
LumaLexActivityAttributes.swift
```

Widgets/

```
LumaLexWidgetBundle.swift
```

Utilities/

Tests/

---

# 21. Design System

Primary accent:

iOS system blue.

Prefer:

Color.accentColor

rather than manually reproducing Apple's colors.

Background:

systemBackground

Secondary background:

secondarySystemBackground

Typography:

SF Pro via SwiftUI system fonts.

Prefer:

.largeTitle
.title
.title2
.headline
.body
.caption

rather than arbitrary font sizes.

Corner radii should be subtle and consistent.

Avoid:

* excessive gradients
* glass effects everywhere
* oversized cards
* excessive shadows
* custom navigation bars when native ones work
* Android-style UI
* web-style UI
* excessive animations

The interface should feel native to the current iOS design language.

---

# 22. Privacy

Audio and transcripts may contain private information.

Therefore:

* explain when audio leaves the device
* minimize server retention
* never log full transcripts in production
* never expose Gemini/API credentials
* provide deletion controls
* prefer on-device processing where practical

---

# 23. API Architecture

Never call production Gemini APIs using a secret embedded directly in the application bundle.

Production:

iPhone
↓
LumaLex API
↓
Gemini API

The backend owns credentials.

Suggested endpoints:

POST /v1/vocabulary/explain

POST /v1/transcribe

POST /v1/translate

POST /v1/analyze-difficulty

The iOS application should depend on protocols so mock implementations can be used during development.

---

# 24. Offline Behavior

Core playback must work offline after processing.

Store locally:

audio metadata
transcripts
translations
vocabulary
review schedule

If Gemini is unavailable:

show cached explanations when available.

Do not prevent audio playback.

---

# 25. Testing

Write unit tests for:

ReviewScheduler

VocabularyDifficultyService

Gemini JSON decoding

Subtitle timestamp lookup

Transcript parsing

Review scheduling is particularly important.

Test:

new word
successful review
failed review
four successful stages
date boundaries
time-zone changes

---

# 26. Development Environment

The primary developer may work on Windows without a local Mac.

Therefore:

* keep the repository buildable through CI
* avoid workflows that require manually editing Xcode project internals whenever possible
* commit all required configuration except secrets
* use Git for version control
* provide clear setup documentation

Recommended workflow:

Windows
↓
Git
↓
GitHub
↓
macOS CI
↓
iOS build
↓
TestFlight
↓
iPhone

Some iOS capabilities require macOS/Xcode and real-device testing.

Do not replace native iOS functionality with inferior cross-platform workarounds solely because development starts on Windows.

---

# 27. Development Priorities

Implement in this order.

Phase 1:

SwiftUI shell
Navigation
SwiftData models
Today screen
Vocabulary list
ReviewScheduler

Phase 2:

Audio import
Audio playback
Transcript display
Subtitle synchronization

Phase 3:

Interactive subtitle words
Gemini explanations
Vocabulary capture
Difficulty detection

Phase 4:

Automatic transcription
Translation
Vocabulary assessment

Phase 5:

Background audio
Now Playing

Phase 6:

Live Activities
Dynamic Island
Lock Screen experience

Phase 7:

Backend hardening
Authentication
Sync
TestFlight
App Store preparation

Do NOT start with Dynamic Island or Live Activities.

First make the core listening and vocabulary loop reliable.

---

# 28. Engineering Rules

1. Prefer native Apple frameworks.
2. Prefer SwiftUI unless UIKit is necessary.
3. Use async/await for asynchronous operations.
4. Avoid massive view files.
5. Business logic must not live inside SwiftUI Views.
6. Keep external AI providers replaceable.
7. Never commit secrets.
8. Write tests for learning/review algorithms.
9. Preserve user data when models evolve.
10. Do not invent APIs that do not exist.
11. If an Apple API limitation prevents a requested behavior, document the limitation rather than implementing a hack.
12. Keep the application responsive during transcription and AI requests.
13. Cache expensive AI results.
14. Design for offline playback.
15. Follow current Apple Human Interface Guidelines.

---

# 29. MVP Definition

The first usable MVP is complete when a user can:

Import an English audio file
↓
Import/generate transcript
↓
Play audio
↓
See synchronized English/Chinese subtitles
↓
Tap an unknown word
↓
Get its contextual explanation
↓
Add it to Vocabulary
↓
See it on the appropriate review day
↓
Complete four review stages
↓
Move it into Learned

Everything else is secondary to this loop.
