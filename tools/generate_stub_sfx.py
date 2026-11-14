#!/usr/bin/env python3
"""Генерирует короткие заглушки SFX для интерфейса MVP.

Звуки короткие (меньше секунды), тихие и мягкие. Это заглушки: финальные
звуки подбираются отдельно. Запуск:
    python3 tools/generate_stub_sfx.py
"""
import math
import os
import struct
import wave

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")


def write_wav(path, samples):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
        )
        w.writeframes(frames)


def tone(freq, dur, amp=0.28, decay=True):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-6.0 * t / dur) if decay else 1.0
        out.append(amp * env * math.sin(2.0 * math.pi * freq * t))
    return out


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    sounds = {
        "click": tone(880, 0.08),
        "correct": tone(660, 0.15) + tone(990, 0.20),
        "error": tone(300, 0.22),
        "complete": tone(523, 0.15) + tone(659, 0.15) + tone(784, 0.25),
    }
    for name, samples in sounds.items():
        path = os.path.join(OUT_DIR, name + ".wav")
        write_wav(path, samples)
        print("wrote", path, "%.2fs" % (len(samples) / SR))


if __name__ == "__main__":
    main()
