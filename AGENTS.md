# AGENTS.md - LiveVoice Box Development Rules

## Project

LiveVoice Box is a Flutter application for TikTok LIVE stream support.

Former name:

* TikBox

Current name:

* LiveVoice Box

The project is currently in the Release Candidate phase.

The goal is NOT feature expansion.

The goal is:

* stable release
* bug-free operation
* safe streaming experience
* simple UX
* reliable TTS playback

---

# Core Product Goal

LiveVoice Box exists to do one thing well:

1. Connect to TikTok LIVE
2. Read comments aloud
3. Play gift reactions
4. Continue working safely during streaming

Everything else is secondary.

---

# Release Lock

The project is feature-frozen.

By default:

Allowed:

* bug fixes
* wording fixes
* crash prevention
* UX improvements
* settings fixes
* stability improvements
* logging improvements

Not Allowed:

* large new features
* architecture rewrites
* provider rewrites
* connection rewrites
* TTS rewrites
* queue rewrites
* analytics systems
* subscription systems
* AI features
* cloud sync
* database redesign

Do not suggest feature additions unless explicitly requested.

---

# Absolute Rules

1. Understand existing code before changing it.
2. Make the smallest possible change.
3. Never rewrite large sections.
4. Never modify unrelated files.
5. Never guess.
6. If uncertain, write:

未確認

7. Existing behavior must not break.
8. Stability is more important than elegance.
9. MVP completion is more important than new features.
10. Real-world behavior is more important than theoretical improvements.

---

# Audit Rule

When the user requests:

* audit
* review
* investigation
* analysis
* release review
* UX review

Do NOT modify code.

Do NOT propose code changes immediately.

First:

1. identify files
2. explain findings
3. classify risk
4. determine whether a fix is required

Only propose implementation if explicitly requested.

---

# File Priority

Trust files in this order:

1. lib/
2. test/
3. pubspec.yaml
4. android/
5. ios/
6. docs/
7. README.md

If documentation and code disagree:

Trust current implementation.

---

# Critical Areas

## LIVE Connection

Primary file:

lib/features/live/live_provider.dart

Do not change:

* connection flow
* reconnect logic
* timeout values
* stale client protection
* username normalization
* stopLive behavior

unless explicitly requested.

---

## TTS

Primary files:

lib/services/tts_service.dart
lib/services/background_tts_handler.dart
lib/features/main/tts_provider.dart
lib/models/tts_settings.dart

Do not rewrite:

* queue system
* retry system
* skip system
* stopAll
* AudioService integration

without strong justification.

---

## Gift Sound

Primary file:

lib/services/effect_sound_service.dart

Current behaviors:

* Bronze
* Silver
* Gold
* Heart Me
* connection success
* connection failure

Do not alter sound balance without request.

---

## Gift Vibration

Primary files:

lib/features/live/live_provider.dart
android/app/src/main/kotlin/com/taichi963/tikbox/MainActivity.kt
ios/Runner/AppDelegate.swift

Rules:

giftVibrationEnabled=false

must never vibrate.

Native vibration changes require:

* Android verification
* iOS verification

before approval.

---

## UI

Primary file:

lib/features/main/main_screen.dart

Rules:

* keep UI simple
* keep UI streamer-friendly
* avoid accidental taps
* avoid information overload
* avoid AI-looking design
* avoid excessive animations
* avoid flashy effects

Main action must remain obvious.

---

# UX Rules

Connecting state must never look like failure.

Examples:

GOOD

* 接続中
* 接続確認中
* 配信ルームを探しています

BAD

* 接続できませんでした
* エラー
* 失敗

while connection is still active.

20-second guidance:

informational

45-second timeout:

failure

These must remain separated.

---

# Layout Rule

Do not introduce:

* fixed heights
* hardcoded vertical layouts

without checking:

* iPhone SE
* iPhone mini
* Android small screens

If a layout change affects screen height:

prefer minimal fixes.

Examples:

* Expanded
* Flexible
* SingleChildScrollView

Avoid large UI rewrites.

---

# Reality Rule

Code review is not evidence.

The following can NEVER be considered fixed without real-device testing:

* iPhone screen off
* Android screen off
* Bluetooth
* AirPods
* Siri
* phone calls
* route changes
* background audio
* foreground services
* vibration
* gift reactions
* TikTok LIVE behavior

Always write:

実機確認が必要

when appropriate.

---

# Cookie Rule

Do not implement:

* Cookie extraction
* automatic Cookie retrieval
* WebView Cookie login
* browser Cookie reading
* TikTok login bypass
* password collection

Preferred:

username-only connection

---

# Store Review Rule

Never present the app as official.

Required direction:

* unofficial tool
* not affiliated with TikTok
* not affiliated with ByteDance
* no password collection
* no Cookie collection
* connection not guaranteed

Avoid:

* official integration claims
* guaranteed connection claims
* misleading automation claims

---

# Git Rule

Before any approval:

check

git status --short

git diff --stat

git diff --check

Verify:

* no build artifacts
* no secrets
* no keystores
* no node_modules

Never commit:

* .jks
* .keystore
* key.properties
* .apk
* .aab
* .ipa
* build/
* node_modules/

unless explicitly requested.

---

# Verification Rule

After code changes:

Required:

flutter analyze --no-pub

flutter test --no-pub

For Android release-impacting changes:

flutter build appbundle --release --no-tree-shake-icons

For iOS native changes:

flutter build ipa

or

Xcode Archive

---

# Verification Classification

Always separate:

Code Verified

and

実機確認が必要

Example:

Code Verified:

* flutter analyze passed
* flutter test passed

実機確認が必要:

* iPhone background audio
* Bluetooth
* AirPods
* vibration
* real gifts

Never mix these categories.

---

# Review Classification Rule

Every review must classify findings:

A = confirmed by code

B = inferred from code

C = requires real-device verification

Never mix categories.

---

# Release Candidate Rule

Before suggesting any change:

Ask:

1. Can this break existing behavior?
2. Is this required for release?
3. Can this wait until after release?

If #2 is NO:

recommend postponing the change.

---

# Release Gate

The following are NOT sufficient for release:

* flutter analyze pass
* flutter test pass
* Android build success

Release approval additionally requires:

* TestFlight verification
* Android release verification
* screen-off verification
* real gift verification
* vibration verification

Without these:

公開判定不可

---

# Release Decision Rule

Do not mark the app ready for release unless:

* flutter analyze passes
* flutter test passes
* Android release build succeeds
* iPhone TestFlight verified
* screen-off test verified
* gift test verified
* vibration verified
* no critical UX issue remains

Otherwise write:

公開判定不可

---

# Output Format

Always respond in:

1. 対象ファイル
2. 問題の原因
3. 修正方針
4. 変更コード
5. 確認手順

If no code change is needed:

変更不要

If behavior cannot be verified:

実機確認が必要

---

# Most Important Principle

Ask one question before every change:

この変更で配信中の事故が減るか？

If the answer is unclear:

do not change it.

Stability beats features.

Release beats perfection.
