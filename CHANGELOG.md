# Changelog

All notable changes to LiveVoice Box are documented in this file.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0.0] - 2026-06-27

Initial public release (build 3).

### Added
- Comment text-to-speech with Japanese voice selection and per-voice settings
- Gift sound effects with four tiers (bronze / silver / gold / heart me)
- Optional gift haptic vibration (disabled by default)
- Session statistics: comment count, gift ranking, social highlights
- UGC moderation: fixed blocked terms, user-added blocked words, per-user blocking, comment reporting via email
- Connection loading animation with 20-second informational guidance and 45-second failure timeout
- Exponential-backoff automatic reconnection (up to 6 attempts: 1–16 s)
- Background audio foreground service with persistent notification (Android)
- Engagement analytics: like-rush detection, follow sound cooldown
- Sound asset fallback: synthesised WAV when bundled asset is unavailable
- Comment deduplication (5-second window, 200-entry cap)
- GitHub Pages documentation (privacy policy, terms of use, support page)
- Store release kit and review notes in `docs/`

### Fixed
- Session statistics reset correctly when a new session starts
- TTS background audio continuity on iOS (AudioService keep-alive)
- Release signing configuration guard in `android/app/build.gradle.kts`
- Comment queue no longer grows without bound during high-traffic sessions

### Changed
- App renamed from TikBox to LiveVoice Box
- README revised for store-review positioning and release clarity

---
