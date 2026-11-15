#!/usr/bin/env python3
"""Sintesis musik latar orisinal (tanpa sampel luar): menu, Indonesia (gamelan slendro), umum.
Pakai: python3 tools/gen_music.py  -> assets/audio/musik_*.wav (mono 24 kHz, 32 detik, loop mulus)."""
import os
import numpy as np
import scipy.signal as sg
import scipy.io.wavfile as wf

SR = 24000
LEN = 32.0
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(2026)


class Mix:
    def __init__(self, secs=LEN):
        self.n = int(SR * secs)
        self.b = np.zeros(self.n)

    def add(self, x, t, g=1.0):
        i = int(round(t * SR)) % self.n
        m = len(x)
        e = min(m, self.n - i)
        self.b[i:i + e] += g * x[:e]
        if e < m:  # ekor melewati akhir -> melingkar ke awal supaya loop mulus
            self.b[:m - e] += g * x[e:m]


def tt(dur):
    return np.arange(int(dur * SR)) / SR


def bar(f, dur, tau, parts=((1, 1.0), (2.76, 0.40), (5.40, 0.16), (8.93, 0.06))):
    t = tt(dur)
    y = np.zeros_like(t)
    for k, (r, a) in enumerate(parts):
        if f * r < SR / 2.2:
            y += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / (tau / (1 + 0.7 * k)))
    y *= np.minimum(1.0, t / 0.002)
    return y


def gong(f, dur=5.0):
    t = tt(dur)
    y = (np.sin(2 * np.pi * f * t) + 0.8 * np.sin(2 * np.pi * f * 1.006 * t)) * np.exp(-t / 2.6)
    y += 0.35 * np.sin(2 * np.pi * f * 2.02 * t) * np.exp(-t / 1.6) + 0.18 * np.sin(2 * np.pi * f * 3.1 * t) * np.exp(-t / 0.9)
    return y * np.minimum(1.0, t / 0.02)


def pot(f, dur, tau):
    t = tt(dur)
    y = np.sin(2 * np.pi * f * t) * np.exp(-t / tau) + 0.4 * np.sin(2 * np.pi * f * 2.1 * t) * np.exp(-t / (tau * 0.5))
    return y * np.minimum(1.0, t / 0.004)


def dung(dur=0.35):
    t = tt(dur)
    f = 85 + 70 * np.exp(-t / 0.05)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.11)


def tak(dur=0.12, hard=1.0):
    t = tt(dur)
    b, a = sg.butter(2, [1300 / (SR / 2), 4500 / (SR / 2)], "band")
    n = sg.lfilter(b, a, rng.standard_normal(len(t))) * np.exp(-t / 0.03)
    return hard * (0.9 * n + 0.5 * np.sin(2 * np.pi * 360 * t) * np.exp(-t / 0.025))


def flute(f, dur, vib=0.004):
    t = tt(dur + 0.2)
    ph = 2 * np.pi * f * t + 2 * np.pi * f * vib * np.sin(2 * np.pi * 5.2 * t) / 5.2
    y = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.06 * np.sin(3 * ph)
    b, a = sg.butter(2, [2000 / (SR / 2), 6000 / (SR / 2)], "band")
    y += 0.05 * sg.lfilter(b, a, rng.standard_normal(len(t)))
    env = np.minimum(1.0, t / 0.07) * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.06))
    return y * env


def pluck(f, dur, decay=0.997):
    n = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, n)
    out = np.zeros(int(dur * SR))
    prev = 0.0
    for i in range(len(out)):
        j = i % n
        cur = buf[j]
        out[i] = cur
        buf[j] = decay * 0.5 * (cur + prev)
        prev = cur
    return out


def pad(f, dur):
    t = tt(dur)
    y = sum(np.sin(2 * np.pi * f * d * t + p) for d, p in ((1, 0), (1.004, 1.3), (0.997, 2.1))) / 3
    y += 0.3 * np.sin(2 * np.pi * f * 2 * t)
    env = np.minimum(1.0, t / 0.5) * np.minimum(1.0, (dur - t) / 0.6)
    return y * env


def marimba(f, dur=0.5):
    t = tt(dur)
    y = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.22) + 0.35 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t / 0.05)
    return y * np.minimum(1.0, t / 0.002)


def kalimba(f, dur=0.9):
    t = tt(dur)
    y = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.45) + 0.25 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t / 0.06)
    return y * np.minimum(1.0, t / 0.002)


def bass(f, dur):
    t = tt(dur)
    y = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2 * t)
    return y * np.exp(-t / 0.35) * np.minimum(1.0, t / 0.008)


def shaker(dur=0.08, hard=1.0):
    t = tt(dur)
    b, a = sg.butter(2, 5000 / (SR / 2), "high")
    return hard * sg.lfilter(b, a, rng.standard_normal(len(t))) * np.exp(-t / 0.025)


def clap(dur=0.18):
    t = tt(dur)
    b, a = sg.butter(2, [900 / (SR / 2), 3500 / (SR / 2)], "band")
    return sg.lfilter(b, a, rng.standard_normal(len(t))) * np.exp(-t / 0.05)


def thump(dur=0.25):
    t = tt(dur)
    f = 55 + 70 * np.exp(-t / 0.04)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.10)


def finish(m, wet=0.2, name="x", peak=0.85):
    ir_t = tt(1.1)
    ir = rng.standard_normal(len(ir_t)) * np.exp(-ir_t / 0.32)
    b, a = sg.butter(1, 4500 / (SR / 2), "low")
    ir = sg.lfilter(b, a, ir)
    ir /= np.sqrt(np.sum(ir ** 2))
    y = sg.fftconvolve(m.b, ir)
    tail = y[m.n:]
    y = y[:m.n].copy()
    y[:len(tail)] += tail  # ekor reverb melingkar -> loop mulus
    mix = (1 - wet) * m.b + wet * y * 1.6
    b, a = sg.butter(2, 45 / (SR / 2), "high")
    mix = sg.lfilter(b, a, mix)
    mix *= 10 ** (-17.0 / 20) / np.sqrt(np.mean(mix ** 2))   # keras rata-rata seragam (-17 dBFS RMS) antar lagu
    mix = np.tanh(mix * 1.2) / np.tanh(1.2)                   # pembatas lembut untuk puncak
    mix *= min(1.0, peak / np.max(np.abs(mix)))
    wf.write(os.path.join(OUT, name), SR, (mix * 32767).astype(np.int16))
    rms = 20 * np.log10(np.sqrt(np.mean(mix ** 2)))
    print("%s  %.1f dtk  puncak %.2f  RMS %.1f dBFS" % (name, len(mix) / SR, np.max(np.abs(mix)), rms))


# ---------------- INDONESIA: gamelan slendro, lancaran 120 BPM, 4 gongan x 16 ketukan ----------------
def indonesia():
    m = Mix()
    beat = 0.5
    base = 293.66   # "ji" ~ D4

    def sl(i, octv=0.0):   # tangga slendro 5 nada sama-rata
        return base * 2 ** (i / 5.0 + octv)

    A = [2, 3, 2, 0, 2, 3, 4, 3, 2, 3, 2, 0, 1, 2, 3, 0]
    B = [4, 3, 4, 2, 3, 4, 5, 4, 4, 3, 4, 2, 3, 2, 1, 0]
    A2 = [2, 3, 2, 0, 2, 3, 4, 3, 2, 3, 4, 3, 4, 3, 2, 0]
    C = [5, 4, 3, 4, 3, 2, 3, 2, 1, 2, 3, 2, 3, 2, 1, 0]
    bal = [A, B, A2, C]
    s1 = [(4, 1.5), (3, 0.5), (2, 1), (3, 1), (4, 2), (3, 1), (2, 1), (3, 2), (1, 1), (2, 1), (3, 1), (2, 1), (0, 2)]
    s2 = [(5, 1), (4, 1), (3, 2), (4, 1), (5, 1), (6, 2), (5, 1), (4, 1), (3, 2), (2, 1), (1, 1), (0, 3)]
    suling = [s1, s2, s1, s2]
    for g in range(4):
        t0 = g * 16 * beat
        for k, deg in enumerate(bal[g]):
            tb = t0 + k * beat
            m.add(bar(sl(deg, -0.0), 1.4, 0.7), tb, 0.55)                     # saron
            for h in (0, 1):                                                  # peking: dua kali lebih rapat, oktaf atas
                m.add(bar(sl(deg, 1), 0.7, 0.28), tb + h * beat / 2, 0.30)
            nb = bal[g][k]                                                    # bonang: ketukan genap & ganjil bergantian
            m.add(bar(sl(nb + 2, 1), 0.8, 0.35), tb, 0.22)
            m.add(bar(sl(nb, 1), 0.8, 0.35), tb + beat / 2, 0.22)
            if k % 4 == 3:                                                    # kenong
                m.add(pot(sl(deg, -1), 1.2, 0.5), tb, 0.45)
            if k % 4 == 1:                                                    # kempul
                m.add(pot(sl(deg, -2), 1.6, 0.8), tb, 0.35)
            # kendang
            pat = ["D", None, "T", None] if k % 2 == 0 else ["T", "D", "T", "t"]
            for q, ch in enumerate(pat):
                tq = tb + q * beat / 4
                if ch == "D":
                    m.add(dung(), tq, 0.55)
                elif ch == "T":
                    m.add(tak(), tq, 0.35)
                elif ch == "t":
                    m.add(tak(0.1, 0.6), tq, 0.25)
        m.add(gong(base / 4), t0 + 15 * beat, 0.75)                           # gong ageng penutup gongan
        tpos = t0
        for deg, dur in suling[g]:                                            # suling
            m.add(flute(sl(deg, 1), dur * beat * 0.95), tpos, 0.20)
            tpos += dur * beat
    finish(m, 0.22, "musik_indonesia.wav")


# ---------------- MENU: hangat & tenang, 90 BPM, C-Am-F-G ----------------
def menu():
    m = Mix()
    beat = 60 / 90
    chords = [(130.81, 164.81, 196.00), (110.00, 130.81, 164.81), (87.31, 110.00, 130.81), (98.00, 123.47, 146.83)]
    for bar_i in range(12):
        ch = chords[bar_i % 4]
        t0 = bar_i * 4 * beat
        m.add(pad(ch[0] * 2, 4 * beat), t0, 0.16)
        m.add(pad(ch[2] * 2, 4 * beat), t0, 0.10)
        m.add(bass(ch[0], 1.4), t0, 0.5)
        m.add(bass(ch[0], 1.2), t0 + 2 * beat, 0.35)
        tones = [ch[0] * 2, ch[1] * 2, ch[2] * 2, ch[0] * 4]
        for q, idx in enumerate([0, 1, 2, 3, 2, 1, 2, 1]):
            m.add(pluck(tones[idx], 0.9), t0 + q * beat / 2, 0.30)
        for q in range(8):
            m.add(shaker(0.07, 0.7 if q % 2 else 1.0), t0 + q * beat / 2 + (beat / 4 if q % 2 else 0), 0.04)
    phr = {0: [(4, 0, 1), (7, 1, 1), (4, 2, 1), (2, 3, 1)], 1: [(0, 0, 1), (4, 1, 1), (9, 2, 1.5), (7, 3.5, 0.5)],
           2: [(9, 0, 1), (7, 1, 1), (4, 2, 1), (0, 3, 1)], 3: [(2, 0, 1), (4, 1, 0.5), (7, 1.5, 0.5), (2, 2, 2)]}
    for bar_i in range(4, 12):
        t0 = bar_i * 4 * beat
        shift = 12 if bar_i >= 8 else 0
        for semi, pos, d in phr[bar_i % 4]:
            m.add(kalimba(523.25 * 2 ** ((semi + shift) / 12.0)), t0 + pos * beat, 0.30)
    finish(m, 0.25, "musik_menu.wav")


# ---------------- UMUM: riang, 120 BPM, Am-F-C-G ----------------
def umum():
    m = Mix()
    beat = 0.5
    prog = [(220.00, (0, 3, 7)), (174.61, (0, 4, 7)), (261.63, (0, 4, 7)), (196.00, (0, 4, 7))]
    for bar_i in range(16):
        root, iv = prog[bar_i % 4]
        t0 = bar_i * 4 * beat
        for q in range(4):
            if q % 2 == 0:
                m.add(thump(), t0 + q * beat, 0.5)
            else:
                m.add(clap(), t0 + q * beat, 0.22)
        for q in range(8):
            m.add(shaker(0.06, 1.0 if q % 2 else 0.6), t0 + q * beat / 2, 0.05)
        for q, st in enumerate([0, 7, 0, 7]):
            m.add(bass(root / 2 * 2 ** (st / 12.0), 0.4), t0 + q * beat, 0.45)
        notes = [root * 2 ** (i / 12.0) * 2 for i in iv] + [root * 4]
        for q, idx in enumerate([0, 1, 2, 3, 2, 1, 2, 3]):
            m.add(marimba(notes[idx]), t0 + q * beat / 2, 0.28)
        if bar_i >= 4:
            for pos, semi in zip((0, 1, 1.5, 2.5, 3), (9, 12, 9, 7, 4)):
                m.add(marimba(440.0 * 2 ** ((semi - 9) / 12.0) * 2, 0.6), t0 + pos * beat, 0.25)
    finish(m, 0.18, "musik_umum.wav")


if __name__ == "__main__":
    indonesia()
    menu()
    umum()
