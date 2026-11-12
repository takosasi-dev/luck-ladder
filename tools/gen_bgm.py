"""BGM 3 曲を assets/bgm/*.ogg に書き出す(仕様書 §9.13・D-31)。
84 BPM。和音は Dm7 → G7 → Cmaj7 → A7。音の尾を曲の頭へ回し込むので、頭と終わりが切れ目なくつながる。
標準ライブラリで wav を作り、ffmpeg で Ogg Vorbis にする。wav は OS の一時フォルダに置く
(プロジェクトの中に置くと、Godot が取り込んで書き出しに入れてしまう)。
使い方: python tools/gen_bgm.py   (ffmpeg は PATH か、環境変数 FFMPEG で場所を渡す)
"""
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import wave

RATE = 44100
BEAT = RATE * 60 // 84  # 31500 サンプル(割り切れる)
BAR = BEAT * 4
TAU = 2 * math.pi
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT_DIR = os.path.join(ROOT, "assets", "bgm")
QUALITY = "1"  # libvorbis の -q:a。1 曲 600 KB 以下に収める

NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
NOTE = {f"{p}{o}": 440.0 * 2 ** ((12 * (o - 4) + i - 9) / 12) for o in range(1, 7) for i, p in enumerate(NAMES)}

# 1 小節ずつ: (和音の音, 4 分音符で歩くベース, 8 分音符のベース, 半音ぶつける音)
BARS = [
    (["A3", "C4", "D4", "F4"], ["D2", "F2", "A2", "C3"], ["D2", "D2", "A2", "D2", "D3", "D2", "A2", "C3"], "D#4"),
    (["G3", "B3", "D4", "F4"], ["G2", "A2", "B2", "D3"], ["G2", "G2", "D3", "G2", "G2", "G2", "D3", "F2"], "G#3"),
    (["G3", "B3", "C4", "E4"], ["C3", "B2", "A2", "G2"], ["C2", "C2", "G2", "C2", "C3", "C2", "G2", "B2"], "C#4"),
    (["G3", "A3", "C#4", "E4"], ["A2", "C#3", "E3", "C#3"], ["A2", "A2", "E3", "A2", "A2", "A2", "E3", "C#3"], "A#3"),
]


class Lcg:
    def __init__(self, seed):
        self.x = seed & 0xFFFFFFFF

    def next(self):
        self.x = (1664525 * self.x + 1013904223) & 0xFFFFFFFF
        return self.x / 0xFFFFFFFF * 2.0 - 1.0


class Track:
    """ステレオのバッファ。長さを超えた分は頭へ足し込む(ループの継ぎ目を消す)。"""

    def __init__(self, bars):
        self.n = BAR * bars
        self.l = [0.0] * self.n
        self.r = [0.0] * self.n

    def tone(self, freq, start, dur, amp, pan=0.0, partials=((1, 1.0), (2, 0.3), (3, 0.08)), decay=1.6, trem=0.0):
        gl = amp * (1.0 - max(0.0, pan))
        gr = amp * (1.0 + min(0.0, pan))
        n = int(dur)
        w = [(TAU * freq * m / RATE, a) for m, a in partials]
        tail = int(0.02 * RATE)
        for i in range(n):
            t = i / RATE
            e = min(1.0, i / 260.0) * math.exp(-decay * t) * min(1.0, (n - i) / tail)
            if trem:
                e *= 1.0 - 0.25 * (0.5 + 0.5 * math.sin(TAU * trem * t))
            s = 0.0
            for k, a in w:
                s += a * math.sin(k * i)
            j = (start + i) % self.n
            self.l[j] += gl * e * s
            self.r[j] += gr * e * s

    def brush(self, start, amp, seed, pan=0.3, dur=0.09):
        rnd = Lcg(seed)
        n = int(dur * RATE)
        y = 0.0
        prev = 0.0
        for i in range(n):
            x = rnd.next()
            y += 0.55 * (x - y)
            hp = y - prev  # 低い成分を落として、ブラシらしい軽さにする
            prev = y
            e = min(1.0, i / 90.0) * math.exp(-38.0 * i / RATE)
            j = (start + i) % self.n
            self.l[j] += amp * (1.0 - pan) * e * hp
            self.r[j] += amp * (1.0 + pan) * e * hp

    def tile(self, times):
        out = Track(1)
        out.n = self.n * times
        out.l = self.l * times
        out.r = self.r * times
        return out


def bed(tense):
    """4 小節ぶんの和音とベース。tense が真ならライフ残り 1 用(8 分音符のベースと、半音ぶつけた和音)。"""
    t = Track(4)
    for b, (chord, walk, eighths, clash) in enumerate(BARS):
        at = b * BAR
        notes = chord + ([clash] if tense else [])
        for k, name in enumerate(notes):
            pan = (-0.35, 0.2, -0.1, 0.35, 0.0)[k]
            if tense:
                for beat in range(4):
                    t.tone(NOTE[name], at + beat * BEAT, BEAT * 0.9, 0.13, pan, decay=4.0, trem=7.0)
            else:
                t.tone(NOTE[name], at, BEAT * 2.6, 0.16, pan, trem=4.5)
                t.tone(NOTE[name], at + int(BEAT * 2.5), BEAT * 0.8, 0.09, pan, decay=5.0)
        if tense:
            for k, name in enumerate(eighths):
                t.tone(NOTE[name], at + k * BEAT // 2, BEAT * 0.48, 0.36, 0.0, ((1, 1.0), (2, 0.45)), decay=5.0)
        else:
            for k, name in enumerate(walk):
                t.tone(NOTE[name], at + k * BEAT, BEAT * 0.95, 0.38, 0.0, ((1, 1.0), (2, 0.4)), decay=2.6)
    return t


def add_brush(t, bars, strong):
    """ブラシ風の刻み。裏拍を 3 連の 3 つ目に寄せ、2 拍目と 4 拍目を強くする。"""
    seed = 1
    for bar in range(bars):
        for beat in range(4):
            at = bar * BAR + beat * BEAT
            t.brush(at, (0.5 if beat in (1, 3) else 0.26) * strong, seed)
            t.brush(at + BEAT * 2 // 3, 0.17 * strong, seed + 1, dur=0.05)
            seed += 2
        if bar % 8 == 7:  # 8 小節ごとの小さな合図
            for k in range(3):
                t.brush(bar * BAR + 3 * BEAT + k * BEAT // 3, 0.3 * strong, seed + k, dur=0.05)


def build():
    calm = bed(False)
    title = calm.tile(2)
    play = calm.tile(4)
    add_brush(play, 16, 1.0)
    last = bed(True).tile(4)
    add_brush(last, 16, 1.25)
    return {"bgm_title": title, "bgm_play": play, "bgm_last": last}


def write_wav(path, t):
    peak = max(1e-9, max(max(abs(x) for x in t.l), max(abs(x) for x in t.r)))
    g = 0.7 / peak * 32767
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<hh", int(a * g), int(b * g)) for a, b in zip(t.l, t.r)))


def main():
    ffmpeg = os.environ.get("FFMPEG") or shutil.which("ffmpeg")
    if not ffmpeg:
        sys.exit("ffmpeg が見つかりません。PATH に入れるか、環境変数 FFMPEG で場所を渡してください。")
    os.makedirs(OUT_DIR, exist_ok=True)
    with tempfile.TemporaryDirectory() as wav_dir:
        for name, track in build().items():
            wav = os.path.join(wav_dir, name + ".wav")
            ogg = os.path.join(OUT_DIR, name + ".ogg")
            write_wav(wav, track)
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav, "-map_metadata", "-1", "-fflags", "+bitexact",
                            "-flags:a", "+bitexact", "-c:a", "libvorbis", "-q:a", QUALITY, ogg], check=True)
            print(f"{name}.ogg  {track.n / RATE:.2f} s  {os.path.getsize(ogg) / 1024:.0f} KB")


if __name__ == "__main__":
    main()
