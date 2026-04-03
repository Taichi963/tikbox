"""
TikBox 効果音ファイル生成スクリプト
comment_pop.wav と gift_flash.wav を assets/audio/ に生成する
"""
import wave
import struct
import math
import os

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
SAMPLE_RATE = 44100


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def sine(freq, t):
    return math.sin(2 * math.pi * freq * t)


def write_wav(filename, frames_float, sample_rate=SAMPLE_RATE, channels=1):
    """PCM 16-bit WAV として書き出す"""
    path = os.path.join(OUTPUT_DIR, filename)
    with wave.open(path, 'w') as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(sample_rate)
        packed = b''.join(
            struct.pack('<h', int(clamp(s, -1.0, 1.0) * 32767))
            for s in frames_float
        )
        wf.writeframes(packed)
    print(f'  生成完了: {path}')


def envelope(t, total, attack=0.005, decay=0.02, sustain_level=0.7, release_ratio=0.35):
    """ADSR エンベロープ（0.0 〜 1.0）"""
    release_start = total * (1 - release_ratio)
    if t < attack:
        return t / attack
    elif t < attack + decay:
        p = (t - attack) / decay
        return 1.0 - p * (1.0 - sustain_level)
    elif t < release_start:
        return sustain_level
    else:
        p = (t - release_start) / (total - release_start)
        return sustain_level * (1.0 - p)


# ─────────────────────────────────────────────────
# comment_pop.wav  ─ 120ms の明るいポップ音
# ─────────────────────────────────────────────────
def make_comment_pop():
    duration = 0.12          # 120 ms
    base_freq = 880.0        # A5
    n = int(SAMPLE_RATE * duration)

    frames = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, attack=0.003, decay=0.015,
                       sustain_level=0.5, release_ratio=0.55)
        # 基音 + 倍音でキャラクターをつける
        s = (sine(base_freq, t) * 0.6
             + sine(base_freq * 2, t) * 0.25
             + sine(base_freq * 3, t) * 0.10)
        frames.append(s * env * 0.75)

    write_wav('comment_pop.wav', frames)


# ─────────────────────────────────────────────────
# gift_flash.wav  ─ 600ms のリッチなギフト演出音
# ─────────────────────────────────────────────────
def make_gift_flash():
    duration = 0.60          # 600 ms
    n = int(SAMPLE_RATE * duration)

    # ふたつの和音 + 上昇スウィープ
    chord = [523.25, 659.25, 783.99]  # C5, E5, G5（Cメジャー）
    sweep_start = 300.0
    sweep_end   = 1200.0

    frames = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = envelope(t, duration, attack=0.008, decay=0.06,
                       sustain_level=0.45, release_ratio=0.45)

        chord_sig = sum(sine(f, t) for f in chord) / len(chord) * 0.55
        sweep_freq = sweep_start + (sweep_end - sweep_start) * (t / duration) ** 0.5
        sweep_sig = sine(sweep_freq, t) * 0.30

        # 打撃感を出す短いノイズバースト（最初 30ms のみ）
        noise = 0.0
        if t < 0.030:
            noise_amp = (0.030 - t) / 0.030 * 0.20
            # 擬似ノイズ（奇数倍音の加算）
            noise = sum(
                sine(sweep_freq * k, t) / k
                for k in range(3, 12, 2)
            ) * noise_amp * 0.1

        frames.append((chord_sig + sweep_sig + noise) * env * 0.80)

    write_wav('gift_flash.wav', frames)


if __name__ == '__main__':
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print('効果音ファイルを生成中...')
    make_comment_pop()
    make_gift_flash()
    print('完了!')
