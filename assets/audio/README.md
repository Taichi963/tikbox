Place production sound files in this folder with these exact names:

- `comment_pop.mp3`
- `gift_flash.mp3`

`comment_pop.mp3`:
- short UI pop / pon sound
- recommended length: 80ms to 180ms

`gift_flash.mp3`:
- richer gift stinger
- recommended length: 300ms to 900ms

The Flutter app preloads these files on startup through `EffectSoundService`.
