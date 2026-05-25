# AGENTS.md - TikBox Development Rules

## Project Goal

TikBox is a Flutter app for TikTok LIVE stream support.

The main goal is:
- connect to a LIVE stream
- read comments aloud
- react to gifts with sound/vibration
- keep working as safely as possible during streaming

The highest priority is to complete a stable MVP.

Do not prioritize new features over stability.

---

## Absolute Rules

1. Understand the current code before changing it.
2. Do not rewrite large parts of the app.
3. Do not change architecture unless explicitly requested.
4. Do not add dependencies unless absolutely necessary.
5. Do not modify unrelated files.
6. Do not guess. If uncertain, say "未確認".
7. Keep changes minimal.
8. Existing working behavior must not be broken.

---

## File Priority

When checking behavior, prioritize files in this order:

1. lib/
2. test/
3. pubspec.yaml
4. android/
5. ios/
6. README.md / docs/
7. node_server/

If docs and code conflict, trust the current lib/ implementation.

---

## Main Areas

### LIVE connection
Primary file:
- lib/features/live/live_provider.dart

Do not change the connection method unless explicitly requested.

### TTS
Primary files:
- lib/services/tts_service.dart
- lib/services/background_tts_handler.dart
- lib/features/main/tts_provider.dart
- lib/models/tts_settings.dart

Do not rewrite the TTS queue system.

### Effects / gift sounds
Primary file:
- lib/services/effect_sound_service.dart

Do not make sounds longer or louder without a clear reason.

### UI
Primary file:
- lib/features/main/main_screen.dart

Keep the UI simple and safe for use during streaming.

---

## Release Phase Rules

This project is currently near release.

Allowed:
- bug fixes
- wording fixes
- small UX improvements
- settings persistence fixes
- crash prevention
- logging for debugging
- minimal performance fixes

Not allowed:
- major refactoring
- new large features
- new screens unless explicitly requested
- connection method rewrite
- Swift full migration
- Web support rewrite
- Cookie auto acquisition
- TikTok login implementation

---

## Background Audio Rule

iOS / Android background behavior must be treated carefully.

Code review alone cannot prove background stability.

If the issue depends on:
- iPhone screen off
- app switching
- Bluetooth
- speaker route
- OS background suspension
- TikTok behavior

then mark it as:
"実機確認が必要"

Do not invent a guaranteed fix.

---

## Cookie / Login Rule

Do not implement:
- automatic Cookie acquisition
- WebView login to extract Cookie
- TikTok login workaround
- reading browser/app cookies

Username-only connection is preferred.

---

## Output Format

Always answer in this format:

1. 対象ファイル
2. 問題の原因
3. 修正方針
4. 変更コード
5. 確認手順

If no change is needed, write:

変更不要

---

## Verification

After any code change, confirm:

- flutter analyze
- existing connection still works
- TTS still works
- gift sound still works
- settings are saved/restored
- Stop does not trigger reconnect
- no unrelated files were changed

---

## Most Important Principle

When unsure, choose the safer option.

Do not make TikBox more complex unless it clearly improves release stability.