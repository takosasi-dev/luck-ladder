"""効果音 12 種を assets/sfx/*.wav に書き出す(仕様書 §9.13・D-20)。
標準ライブラリだけを使い、同じ入力なら同じバイト列になる(雑音も自前の線形合同法)。
使い方: python tools/gen_sfx.py
"""
import math
import os
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")
TAU = 2 * math.pi

# 音名 → 周波数(A4 = 440)
NOTE = {f"{p}{o}": 440.0 * 2 ** ((12 * (o - 4) + i - 9) / 12)
        for o in range(1, 8) for i, p in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


class Lcg:
    def __init__(self, seed):
        self.x = seed & 0xFFFFFFFF

    def next(self):
        self.x = (1664525 * self.x + 1013904223) & 0xFFFFFFFF
        return self.x / 0xFFFFFFFF * 2.0 - 1.0


def buf(sec):
    return [0.0] * int(RATE * sec)


def bell(out, freq, start, dur, amp, partials=((1, 1.0), (2, 0.35), (3, 0.12)), decay=5.0, attack=0.004):
    """減衰する倍音の重ね。鐘やエレピのような音。"""
    i0 = int(start * RATE)
    n = min(int(dur * RATE), len(out) - i0)
    for i in range(n):
        t = i / RATE
        e = min(1.0, t / attack) * math.exp(-decay * t) * min(1.0, (n - i) / (0.01 * RATE))
        s = 0.0
        for mult, w in partials:
            s += w * math.sin(TAU * freq * mult * t)
        out[i0 + i] += amp * e * s


def noise(out, start, dur, amp, seed, lp_from, lp_to, decay=8.0):
    """1 次のローパスを通した雑音。係数を lp_from → lp_to に動かす。"""
    r = Lcg(seed)
    i0 = int(start * RATE)
    n = min(int(dur * RATE), len(out) - i0)
    y = 0.0
    for i in range(n):
        k = i / n
        a = lp_from + (lp_to - lp_from) * k
        y += a * (r.next() - y)
        e = min(1.0, i / (0.003 * RATE)) * math.exp(-decay * i / RATE) * min(1.0, (n - i) / (0.01 * RATE))
        out[i0 + i] += amp * e * y


def sweep(out, f0, f1, start, dur, amp, decay=6.0):
    i0 = int(start * RATE)
    n = min(int(dur * RATE), len(out) - i0)
    ph = 0.0
    for i in range(n):
        k = i / n
        ph += TAU * (f0 + (f1 - f0) * k) / RATE
        e = min(1.0, i / (0.004 * RATE)) * math.exp(-decay * i / RATE) * min(1.0, (n - i) / (0.01 * RATE))
        out[i0 + i] += amp * e * math.sin(ph)


def tap():
    o = buf(0.07)
    bell(o, 1500, 0, 0.07, 0.6, ((1, 1.0), (2.7, 0.3)), decay=70)
    noise(o, 0, 0.02, 0.25, 3, 0.9, 0.5, decay=200)
    return o


def flip():
    o = buf(0.16)
    noise(o, 0, 0.16, 0.9, 5, 0.08, 0.6, decay=22)
    bell(o, 320, 0.09, 0.07, 0.25, ((1, 1.0),), decay=60)
    return o


def hit(notes):
    o = buf(0.55)
    for i, n in enumerate(notes):
        bell(o, NOTE[n], 0.07 * i, 0.55 - 0.07 * i, 0.42, decay=7)
    return o


def miss():
    o = buf(0.42)
    sweep(o, 210, 70, 0, 0.42, 0.7, decay=7)
    noise(o, 0, 0.12, 0.5, 9, 0.25, 0.05, decay=30)
    bell(o, NOTE["D#3"], 0.02, 0.3, 0.25, ((1, 1.0), (1.06, 0.8)), decay=9)
    return o


def same():
    o = buf(0.9)
    for i, n in enumerate(["E5", "G#5", "B5", "E6"]):
        bell(o, NOTE[n], 0.06 * i, 0.9 - 0.06 * i, 0.32, ((1, 1.0), (2, 0.4), (4.2, 0.15)), decay=4.5)
    return o


def bank():
    o = buf(0.7)
    for i, f in enumerate([2093.0, 2637.0, 3136.0]):
        bell(o, f, 0.055 * i, 0.6, 0.3, ((1, 1.0), (2.76, 0.45), (5.4, 0.2)), decay=9)
    noise(o, 0, 0.05, 0.3, 13, 0.9, 0.7, decay=90)
    bell(o, NOTE["C4"], 0.0, 0.3, 0.3, ((1, 1.0),), decay=14)
    return o


def life_up():
    o = buf(0.5)
    bell(o, NOTE["G4"], 0, 0.5, 0.4, decay=7)
    bell(o, NOTE["D5"], 0.11, 0.39, 0.42, decay=6)
    return o


def toast():
    o = buf(0.6)
    bell(o, NOTE["A5"], 0, 0.6, 0.3, ((1, 1.0), (3, 0.2)), decay=6)
    bell(o, NOTE["E6"], 0.13, 0.47, 0.28, ((1, 1.0), (3, 0.2)), decay=6)
    return o


def clear():
    o = buf(2.6)
    seq = ["C5", "E5", "G5", "C6", "E6", "G6"]
    for i, n in enumerate(seq):
        bell(o, NOTE[n], 0.11 * i, 1.4, 0.26, decay=3.2)
    for n in ["C4", "G4", "C5", "E5", "G5", "C6"]:
        bell(o, NOTE[n], 0.78, 1.8, 0.16, ((1, 1.0), (2, 0.5), (3, 0.2)), decay=2.0)
    return o


def gameover():
    o = buf(1.3)
    for i, n in enumerate(["A4", "F4", "D4"]):
        bell(o, NOTE[n], 0.22 * i, 0.9, 0.36, ((1, 1.0), (2, 0.3)), decay=4.0)
    bell(o, NOTE["D3"], 0.44, 0.86, 0.3, ((1, 1.0),), decay=3.0)
    return o


SOUNDS = {
    "tap": tap, "flip": flip,
    "hit_1": lambda: hit(["C5", "E5"]),
    "hit_2": lambda: hit(["E5", "G5", "B5"]),
    "hit_3": lambda: hit(["G5", "B5", "D6", "G6"]),
    "miss": miss, "same": same, "bank": bank, "life_up": life_up,
    "toast": toast, "clear": clear, "gameover": gameover,
}


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.8 / peak
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))
    print(f"{name}.wav  {len(samples) / RATE:.2f} s")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        write(name, fn())
