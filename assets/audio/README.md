TikBox no longer requires checked-in effect sound files in this directory.

The comment, gift, and premium gift sound effects are synthesized in
`lib/services/effect_sound_service.dart` as short PCM WAV clips and fed to
`audioplayers` via `BytesSource`.

This folder remains in the repo only because `pubspec.yaml` still includes
`assets/audio/`.
