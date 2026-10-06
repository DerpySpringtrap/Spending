#!/usr/bin/env python3
"""Synthesizes Duskbound's placeholder audio: SFX, music loops and ambience.

Everything is generated from scratch (no samples), so there are no licensing
questions. Re-run after tweaking to regenerate:

    python3 tools/audio/synth_audio.py            # writes assets/audio/**.ogg

Requires numpy, scipy and ffmpeg (with libvorbis).
"""
import math
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")
AMB_DIR = os.path.join(ROOT, "assets", "audio", "ambience")
SR = 44100
MSR = 32000  # music / ambience sample rate
RNG = np.random.default_rng(7)


# --- primitives ------------------------------------------------------------------

def tt(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def note(name):
    names = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
             "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + names[pitch]


def env_exp(n, decay, sr=SR, attack=0.002):
    t = np.arange(n) / sr
    e = np.exp(-t / max(decay, 1e-4))
    a = max(int(attack * sr), 1)
    e[:a] *= np.linspace(0, 1, a)
    return e


def env_ar(n, attack, release, sr=SR):
    e = np.ones(n)
    a = min(max(int(attack * sr), 1), n)
    r = min(max(int(release * sr), 1), n)
    e[:a] = np.linspace(0, 1, a)
    e[n - r:] *= np.linspace(1, 0, r)
    return e


def noise(n):
    return RNG.uniform(-1, 1, n)


def lp(x, cutoff, sr=SR, order=2):
    b, a = signal.butter(order, min(cutoff / (sr / 2), 0.99), "low")
    return signal.lfilter(b, a, x)


def hp(x, cutoff, sr=SR, order=2):
    b, a = signal.butter(order, min(cutoff / (sr / 2), 0.99), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, sr=SR, order=2):
    b, a = signal.butter(order, [lo / (sr / 2), min(hi / (sr / 2), 0.99)], "band")
    return signal.lfilter(b, a, x)


def sweep(f0, f1, dur, sr=SR, curve="exp"):
    n = int(dur * sr)
    if curve == "exp":
        f = f0 * (f1 / f0) ** np.linspace(0, 1, n)
    else:
        f = np.linspace(f0, f1, n)
    return np.sin(2 * np.pi * np.cumsum(f) / sr)


def sine(f, dur, sr=SR):
    return np.sin(2 * np.pi * f * tt(dur, sr))


def saw(f, dur, sr=SR, harmonics=24):
    t = tt(dur, sr)
    out = np.zeros_like(t)
    for k in range(1, harmonics + 1):
        if f * k > sr / 2.2:
            break
        out += np.sin(2 * np.pi * f * k * t) / k
    return out * 0.6


def pluck(f, dur, sr=SR, bright=1.0, decay=0.9):
    """Plucked string: harmonics that fade faster the higher they are."""
    t = tt(dur, sr)
    out = np.zeros_like(t)
    for k in range(1, 12):
        if f * k > sr / 2.2:
            break
        out += np.sin(2 * np.pi * f * k * t + k) * np.exp(-t * (1.2 / decay + k * 1.8 / bright)) / k ** 1.1
    a = int(0.003 * sr)
    out[:a] *= np.linspace(0, 1, a)
    return out


def bell(f, dur, sr=SR, decay=1.2):
    t = tt(dur, sr)
    partials = [(1.0, 1.0, 1.0), (2.76, 0.5, 0.6), (5.4, 0.3, 0.35), (8.93, 0.15, 0.2), (0.5, 0.25, 1.4)]
    out = np.zeros_like(t)
    for ratio, amp, d in partials:
        if f * ratio < sr / 2.2:
            out += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / (decay * d))
    a = int(0.002 * sr)
    out[:a] *= np.linspace(0, 1, a)
    return out


def marimba(f, dur, sr=SR):
    t = tt(dur, sr)
    return (np.sin(2 * np.pi * f * t) * np.exp(-t * 6) + 0.3 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 22))


def pad(freqs, dur, sr=MSR, cutoff=1400, attack=0.5, release=0.8, detune=0.004):
    n = int(dur * sr)
    out = np.zeros(n)
    for f in freqs:
        for d in (-detune, 0, detune):
            out += saw(f * (1 + d), dur, sr, harmonics=10)
    out = lp(out, cutoff, sr)
    return out * env_ar(n, attack, release, sr) / max(len(freqs) * 3, 1)


def brass(f, dur, sr=MSR, cutoff=1100):
    n = int(dur * sr)
    x = saw(f, dur, sr, 16) + 0.5 * saw(f * 1.003, dur, sr, 16)
    x = lp(x, cutoff, sr) * env_ar(n, 0.04, min(0.15, dur / 2), sr)
    return np.tanh(x * 1.5)


def bass(f, dur, sr=MSR, drive=1.4):
    n = int(dur * sr)
    t = tt(dur, sr)
    x = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t) + 0.15 * np.sin(6 * np.pi * f * t)
    return np.tanh(x * drive) * env_ar(n, 0.008, min(0.08, dur / 3), sr)


def kick(sr=MSR, low=45):
    x = sweep(150, low, 0.35, sr) * env_exp(int(0.35 * sr), 0.12, sr)
    x[:int(0.004 * sr)] += noise(int(0.004 * sr)) * 0.4
    return np.tanh(x * 1.6)


def snare(sr=MSR):
    n = int(0.25 * sr)
    tone = sine(190, 0.25, sr) * env_exp(n, 0.05, sr)
    body = hp(noise(n), 1500, sr) * env_exp(n, 0.08, sr)
    return tone * 0.5 + body * 0.8


def hat(sr=MSR, decay=0.03):
    n = int(0.12 * sr)
    return hp(noise(n), 7000, sr) * env_exp(n, decay, sr) * 0.5


def tom(f=90, sr=MSR):
    return sweep(f * 1.6, f, 0.45, sr) * env_exp(int(0.45 * sr), 0.16, sr)


def shaker(sr=MSR):
    n = int(0.08 * sr)
    return bp(noise(n), 4000, 9000, sr) * env_ar(n, 0.02, 0.05, sr) * 0.35


def reverb(x, sr, seconds=1.4, wet=0.25):
    n = int(seconds * sr)
    ir = noise(n) * np.exp(-np.arange(n) / sr / (seconds / 4))
    ir = lp(ir, 5000, sr)
    ir /= np.sqrt(np.sum(ir ** 2))
    tail = signal.fftconvolve(x, ir)
    return x, tail * wet


def place(buf, x, start, wrap=True):
    """Adds x into buf at sample start; wraps around for seamless loops."""
    n = len(buf)
    end = start + len(x)
    if end <= n:
        buf[start:end] += x
    elif wrap:
        first = n - start
        buf[start:] += x[:first]
        rest = x[first:]
        while len(rest) > 0:
            k = min(len(rest), n)
            buf[:k] += rest[:k]
            rest = rest[k:]
    else:
        buf[start:] += x[:n - start]


def normalize(x, peak=0.9):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def write_ogg(path, x, sr=SR, peak=0.9, quality=4):
    x = normalize(np.asarray(x, dtype=np.float64), peak)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_path = tmp.name
    with wave.open(tmp_path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp_path, "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    os.remove(tmp_path)


def cat(*parts, gap=0.0, sr=SR):
    out = []
    for p in parts:
        out.append(p)
        if gap:
            out.append(np.zeros(int(gap * sr)))
    return np.concatenate(out)


def mix(length, items, sr=SR):
    """items: (start_seconds, array, gain)."""
    buf = np.zeros(int(length * sr))
    for start, x, gain in items:
        place(buf, x * gain, int(start * sr), wrap=False)
    return buf


# --- SFX ---------------------------------------------------------------------------

def sfx():
    s = {}
    s["ui_hover"] = sine(1500, 0.03) * env_exp(int(0.03 * SR), 0.008) * 0.3
    click = sine(900, 0.07) * env_exp(int(0.07 * SR), 0.015) + 0.6 * sine(1350, 0.07) * env_exp(int(0.07 * SR), 0.01)
    click[:80] += noise(80) * 0.5
    s["ui_click"] = click
    s["ui_back"] = sweep(900, 500, 0.09) * env_exp(int(0.09 * SR), 0.03)
    for i in range(3):
        n = int(0.09 * SR)
        lo = 1800 + i * 500
        s[f"card_draw_{i + 1}"] = bp(noise(n), lo, lo * 3) * env_exp(n, 0.02, attack=0.004)
    s["card_hover"] = bp(noise(int(0.03 * SR)), 3000, 8000) * env_exp(int(0.03 * SR), 0.006) * 0.4
    n = int(0.22 * SR)
    whoosh = np.zeros(n)
    nz = noise(n)
    for k, (lo, hi) in enumerate([(400, 900), (800, 1800), (1500, 3500)]):
        seg = bp(nz, lo, hi)
        w = np.zeros(n)
        c = int(n * (0.25 + 0.25 * k))
        w[:] = np.exp(-((np.arange(n) - c) / (n * 0.18)) ** 2)
        whoosh += seg * w
    s["card_play"] = whoosh
    s["card_discard"] = lp(whoosh[::-1], 2500)[: int(0.15 * SR)] * 0.6
    n = int(0.5 * SR)
    crackle = np.zeros(n)
    for _ in range(45):
        p = RNG.integers(0, n - 400)
        crackle[p:p + 300] += hp(noise(300), 2000) * env_exp(300, 0.002)
    s["card_exhaust"] = crackle * np.linspace(1, 0, n) + lp(noise(n), 900) * env_exp(n, 0.15) * 0.5
    s["shuffle"] = mix(0.45, [(i * 0.045, s["card_draw_%d" % (i % 3 + 1)], 0.8) for i in range(8)])
    s["card_create"] = mix(0.6, [(i * 0.06, bell(midi(84 + [0, 4, 7, 12][i]), 0.5), 0.5) for i in range(4)])
    for i, (f0, f1) in enumerate([(170, 55), (150, 48), (190, 60)]):
        n = int(0.22 * SR)
        thud = sweep(f0, f1, 0.22) * env_exp(n, 0.07)
        crack = lp(noise(n), 2400) * env_exp(n, 0.025)
        s[f"hit_{i + 1}"] = np.tanh((thud + crack * 0.7) * 1.8)
    n = int(0.6 * SR)
    s["hit_heavy"] = np.tanh((sweep(130, 32, 0.6) * env_exp(n, 0.2) + lp(noise(n), 1500) * env_exp(n, 0.06)) * 2.5)
    n = int(0.45 * SR)
    t = tt(0.45)
    clank = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t / d) for f, a, d in [(520, 1, 0.25), (1180, 0.6, 0.18), (1870, 0.4, 0.12), (2650, 0.3, 0.08)])
    clank[:100] += noise(100) * 0.8
    s["block_gain"] = clank
    n = int(0.6 * SR)
    shatter = hp(noise(n), 3000) * env_exp(n, 0.12)
    for _ in range(14):
        f = RNG.uniform(2500, 7000)
        st = RNG.uniform(0, 0.15)
        ping = sine(f, 0.6 - st)
        place(shatter, ping * env_exp(len(ping), 0.08) * 0.3, int(st * SR), wrap=False)
    s["block_break"] = shatter
    n = int(0.3 * SR)
    s["enemy_windup"] = bp(noise(n), 200, 900) * np.sin(np.linspace(0, np.pi, n)) ** 2
    bubbles = np.zeros(int(0.35 * SR))
    for st in (0.0, 0.09, 0.2):
        b = sweep(RNG.uniform(250, 350), RNG.uniform(600, 800), 0.07) * env_exp(int(0.07 * SR), 0.03)
        place(bubbles, b, int(st * SR), wrap=False)
    s["poison_tick"] = bubbles
    n = int(0.4 * SR)
    s["burn_tick"] = s["card_exhaust"][:n] * 0.7 + lp(noise(n), 700) * env_exp(n, 0.12) * 1.2
    s["status_buff"] = mix(0.5, [(i * 0.05, pluck(midi(67 + [0, 4, 7, 12][i]), 0.4), 0.6) for i in range(4)])
    s["status_debuff"] = lp(mix(0.55, [(i * 0.06, pluck(midi(64 - [0, 3, 7, 12][i]), 0.45), 0.6) for i in range(4)]), 2500)
    s["heal"] = mix(1.0, [(i * 0.08, bell(midi(76 + [0, 4, 7][i]), 0.8), 0.5) for i in range(3)])
    n = int(0.8 * SR)
    death = np.zeros(n)
    nz = noise(n)
    for k in range(8):
        lo = 1800 * (0.7 ** k)
        seg = bp(nz, max(lo, 120), max(lo * 1.8, 250))
        c = int(n * k / 9)
        death += seg * np.exp(-((np.arange(n) - c) / (n * 0.09)) ** 2)
    s["death"] = death + sweep(90, 40, 0.8) * env_exp(n, 0.25) * 0.6
    s["energy"] = mix(0.5, [(i * 0.03, pluck(midi(88 + [0, 7, 12, 19][i]), 0.4, bright=2), 0.4) for i in range(4)])
    n = int(0.55 * SR)
    hiss = hp(noise(n), 3500) * np.linspace(0.1, 1, n) ** 2
    s["overheat"] = cat(hiss, s["hit_heavy"] * 1.2)
    n = int(0.25 * SR)
    s["stoke"] = s["card_exhaust"][:n] * 0.6 + bp(noise(n), 300, 1200) * env_ar(n, 0.05, 0.15) * 0.8
    pent = [0, 3, 5, 7, 10, 12]
    s["stance_wax"] = mix(0.7, [(i * 0.045, pluck(midi(62 + pent[i]), 0.5, bright=1.6), 0.5) for i in range(6)])
    s["stance_wane"] = mix(0.7, [(i * 0.045, pluck(midi(74 - pent[i]), 0.5, bright=1.6), 0.5) for i in range(6)])
    n = int(0.9 * SR)
    rev_cymbal = hp(noise(n), 4000) * np.linspace(0, 1, n) ** 3
    eclipse_pad = pad([midi(50), midi(57), midi(62), midi(65)], 1.5, SR, cutoff=2000, attack=0.05, release=1.0)
    s["eclipse"] = cat(rev_cymbal * 0.7, eclipse_pad * 2.5)
    s["summon"] = mix(0.8, [(i * 0.05, marimba(midi(60 + [0, 2, 4, 7, 9, 12][i]), 0.5), 0.5) for i in range(6)] + [(0.35, sweep(300, 900, 0.08) * env_exp(int(0.08 * SR), 0.03), 0.7)])
    s["gold"] = mix(0.5, [(0, bell(midi(95), 0.4, decay=0.4), 0.6), (0.06, bell(midi(100), 0.4, decay=0.4), 0.6)])
    s["relic"] = mix(1.8, [(i * 0.09, bell(midi(84 + [0, 4, 7, 12, 16][i]), 1.4), 0.5) for i in range(5)] + [(0.3, pad([midi(72), midi(76), midi(79)], 1.4, SR, cutoff=3000, attack=0.2, release=1.0), 0.5)])
    glug = np.zeros(int(0.5 * SR))
    for st in (0.0, 0.13, 0.27):
        g = lp(sweep(140, 320, 0.11) * env_exp(int(0.11 * SR), 0.05), 900)
        place(glug, g, int(st * SR), wrap=False)
    s["potion"] = glug
    s["map_select"] = mix(0.9, [(0, bell(midi(57), 0.9, decay=0.5), 0.6), (0, lp(noise(2000), 1200) * env_exp(2000, 0.01), 0.8)])
    s["rest"] = pad([midi(57), midi(64), midi(69), midi(72)], 1.6, SR, cutoff=1800, attack=0.4, release=1.0) * 3
    coins = np.zeros(int(0.6 * SR))
    for _ in range(6):
        place(coins, bell(RNG.uniform(2500, 4200), 0.3, decay=0.2), int(RNG.uniform(0, 0.25) * SR), wrap=False)
    s["shop_buy"] = coins
    s["turn_player"] = bell(midi(48), 1.6, decay=1.2) * 0.8
    s["turn_enemy"] = tom(75, SR) * 1.2
    n = int(2.2 * SR)
    swell = sum(brass(midi(m), 2.2, SR, cutoff=700) for m in (38, 45, 50)) * np.linspace(0, 1, n) ** 1.5
    place(swell, tom(55, SR) * 1.5, int(1.6 * SR), wrap=False)
    s["boss_intro"] = swell
    s["victory"] = mix(2.6, [(i * 0.13, brass(midi(60 + [0, 4, 7][i]), 0.3, SR, 2200), 0.6) for i in range(3)] + [(0.42, sum(brass(midi(m), 1.8, SR, 2000) for m in (60, 64, 67, 72)), 0.45)])
    s["defeat"] = lp(mix(3.0, [(i * 0.35, pluck(midi(57 - [0, 2, 3, 7][i]), 1.2, decay=1.5), 0.7) for i in range(4)] + [(0, pad([midi(45), midi(52)], 3.0, SR, 900, 0.3, 1.5), 1.6)]), 3000)
    s["motif_warden"] = mix(1.3, [(0, brass(midi(43), 0.45, SR, 900), 0.8), (0.32, brass(midi(50), 0.9, SR, 900), 0.8), (0, tom(60, SR), 1.0)])
    s["motif_moonblade"] = mix(1.3, [(i * 0.07, bell(midi(81 + [0, 3, 7, 10, 12, 15][i]), 0.8, decay=0.6), 0.45) for i in range(6)])
    return s


# --- Music -------------------------------------------------------------------------

class Track:
    def __init__(self, bpm, bars, sr=MSR):
        self.sr = sr
        self.beat = 60.0 / bpm
        self.length = bars * 4 * self.beat
        self.buf = np.zeros(int(round(self.length * sr)))
        self.verb = np.zeros_like(self.buf)

    def at(self, beat):
        return int(round(beat * self.beat * self.sr))

    def add(self, beat, x, gain=1.0, verb=0.0):
        place(self.buf, x * gain, self.at(beat))
        if verb:
            place(self.verb, x * gain * verb, self.at(beat))

    def render(self, wet=0.25):
        _, tail = reverb(self.verb, self.sr, 1.6, wet)
        out = self.buf.copy()
        place(out, tail, 0)
        return out


def chord_notes(root, quality):
    third = 3 if quality == "m" else 4
    return [root, root + third, root + 7]


def music_menu():
    tr = Track(66, 8)
    prog = [(note("D3"), "m"), (note("A#2"), ""), (note("F3"), ""), (note("C3"), ""), (note("D3"), "m"), (note("A#2"), ""), (note("G2"), "m"), (note("A2"), "")]
    melody = ["A4", "F4", "G4", "E4", "A4", "C5", "D5", "C#5"]
    for bar, (root, q) in enumerate(prog):
        b = bar * 4
        notes = chord_notes(root, q)
        tr.add(b, pad([midi(n) for n in notes + [root + 12]], 4 * tr.beat + 0.6, cutoff=1100), 0.9, verb=0.6)
        tr.add(b, bass(midi(root - 12), 4 * tr.beat, drive=1.0), 0.35)
        arp = notes + [root + 12, notes[1] + 12, root + 12, notes[2], notes[1]]
        for i in range(8):
            tr.add(b + i * 0.5, pluck(midi(arp[i] + 12), 1.2, bright=0.8), 0.18, verb=0.5)
        tr.add(b + 1, bell(midi(note(melody[bar])), 2.5, decay=1.4), 0.22, verb=0.8)
    return tr.render(0.35)


def music_map(act=1):
    if act == 1:
        tr = Track(80, 8)
        prog = [(note("A2"), "m"), (note("F2"), ""), (note("C3"), ""), (note("G2"), ""), (note("A2"), "m"), (note("F2"), ""), (note("D3"), "m"), (note("E3"), "")]
        lead = ["E5", "C5", "E5", "D5", "C5", "A4", "F5", "E5"]
    else:
        tr = Track(76, 8)
        prog = [(note("E2"), "m"), (note("F2"), ""), (note("E2"), "m"), (note("D3"), "m"), (note("E2"), "m"), (note("F2"), ""), (note("G2"), ""), (note("F2"), "")]
        lead = ["B4", "C5", "G4", "A4", "B4", "C5", "D5", "C5"]
    for bar, (root, q) in enumerate(prog):
        b = bar * 4
        notes = chord_notes(root, q)
        tr.add(b, pad([midi(n + 12) for n in notes], 4 * tr.beat + 0.4, cutoff=900 if act == 1 else 700, attack=0.8), 0.7, verb=0.5)
        tr.add(b, bass(midi(root), 2 * tr.beat, drive=1.0), 0.4)
        tr.add(b + 2, bass(midi(root), 2 * tr.beat, drive=1.0), 0.3)
        pattern = [0, 1, 2, 1, 2, 1, 0, 2] if act == 1 else [0, 2, 1, 2, 0, 2, 1, 2]
        for i, idx in enumerate(pattern):
            n = notes[idx] + 12
            inst = pluck(midi(n), 0.9, bright=1.0) if act == 1 else bell(midi(n + 12), 1.0, decay=0.5) * 0.6
            tr.add(b + i * 0.5, inst, 0.22, verb=0.4)
            tr.add(b + i * 0.5, shaker(), 0.25 if act == 1 else 0.12)
        if bar % 2 == 1:
            tr.add(b + 0.5, bell(midi(note(lead[bar])), 2.0, decay=1.0), 0.2, verb=0.7)
        else:
            tr.add(b + 2, pluck(midi(note(lead[bar])), 1.5, decay=1.4), 0.25, verb=0.6)
    if act == 2:
        drone = pad([midi(28), midi(35)], tr.length + 1, cutoff=300, attack=2, release=2)
        tr.add(0, drone, 0.6)
    return tr.render(0.3)


def music_combat(kind="normal"):
    if kind == "normal":
        tr = Track(128, 16)
        prog = [(note("E2"), "m"), (note("C2"), ""), (note("D2"), ""), (note("B1"), ""), (note("E2"), "m"), (note("C2"), ""), (note("A1"), "m"), (note("B1"), "")]
    elif kind == "elite":
        tr = Track(136, 16)
        prog = [(note("C2"), "m"), (note("G#1"), ""), (note("A#1"), ""), (note("G1"), ""), (note("C2"), "m"), (note("G#1"), ""), (note("F1"), "m"), (note("G1"), "")]
    else:
        tr = Track(144, 16)
        prog = [(note("D2"), "m"), (note("A#1"), ""), (note("C2"), ""), (note("A1"), ""), (note("D2"), "m"), (note("G1"), "m"), (note("A#1"), ""), (note("A1"), "")]
    k = kick()
    sn = snare()
    for bar in range(16):
        root, q = prog[bar % 8]
        b = bar * 4
        notes = chord_notes(root, q)
        intense = bar >= 8
        # drums
        kicks = [0, 1.5, 2, 3.5] if kind == "normal" else ([0, 0.5, 1.5, 2, 2.5, 3.5] if kind == "boss" else [0, 1.5, 2, 2.75, 3.5])
        for kb in kicks:
            tr.add(b + kb, k, 0.9)
        for sb in (1, 3):
            tr.add(b + sb, sn, 0.55, verb=0.2)
        for i in range(8 if not intense else 16):
            step = 0.5 if not intense else 0.25
            tr.add(b + i * step, hat(), 0.35 if i % 2 == 0 else 0.22)
        if kind != "normal" and bar % 4 == 3:
            for i, f in enumerate((140, 110, 90, 75)):
                tr.add(b + 3 + i * 0.25, tom(f), 0.6)
        # bass ostinato
        pattern = [0, 0, 12, 0, 0, 12, 0, 7]
        for i, off in enumerate(pattern):
            tr.add(b + i * 0.5, bass(midi(root + off), 0.45 * tr.beat, drive=1.6 if kind == "normal" else 2.4), 0.5)
        # harmony
        if kind == "boss":
            tr.add(b, pad([midi(n + 24) for n in notes] + [midi(root + 36)], 4 * tr.beat, cutoff=2200, attack=0.1, release=0.3), 0.6, verb=0.4)
        else:
            tr.add(b, pad([midi(n + 24) for n in notes], 4 * tr.beat, cutoff=1500, attack=0.05, release=0.3), 0.45, verb=0.3)
        arp = [notes[0], notes[1], notes[2], notes[1] + 12 if False else notes[0] + 12]
        for i in range(8):
            tr.add(b + i * 0.5, pluck(midi(arp[i % 4] + 24), 0.4, bright=1.4), 0.17, verb=0.25)
        # brass stabs
        if kind != "normal" or intense:
            for sb in ((0, 1.5, 3) if kind != "normal" else (0, 2.5)):
                tr.add(b + sb, brass(midi(notes[0] + 24), 0.35 * tr.beat * 2, cutoff=1500 if kind == "boss" else 1200), 0.35, verb=0.3)
    return tr.render(0.2)


def stinger_free_ambience(kind):
    dur = 32.0
    n = int(dur * MSR)
    out = np.zeros(n)
    if kind == "swamp":
        wind = lp(np.cumsum(noise(n)) * 0.02, 500, MSR)
        wind -= np.mean(wind)
        lfo = 0.6 + 0.4 * np.sin(2 * np.pi * np.arange(n) / MSR / 8.0)
        out += wind / (np.max(np.abs(wind)) + 1e-9) * lfo * 0.5
        for _ in range(16):
            st = RNG.uniform(0, dur - 1)
            f = RNG.uniform(120, 220)
            croak_len = RNG.uniform(0.15, 0.3)
            t = tt(croak_len, MSR)
            croak = np.sin(2 * np.pi * f * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 28 * t))) * env_ar(len(t), 0.02, 0.08, MSR)
            place(out, lp(croak, 900, MSR) * RNG.uniform(0.08, 0.18), int(st * MSR))
        for _ in range(26):
            st = RNG.uniform(0, dur)
            d = sweep(RNG.uniform(1400, 2200), 600, 0.06, MSR) * env_exp(int(0.06 * MSR), 0.02, MSR)
            place(out, d * RNG.uniform(0.05, 0.12), int(st * MSR))
    else:
        drone = sine(55, dur, MSR) * 0.3 + sine(55.4, dur, MSR) * 0.3 + sine(82.5, dur, MSR) * 0.1
        out += drone
        air = lp(noise(n), 400, MSR) * 0.25
        out += air
        for _ in range(60):
            st = RNG.uniform(0, dur)
            c = hp(noise(200), 2500, MSR) * env_exp(200, 0.002, MSR)
            place(out, c * RNG.uniform(0.05, 0.15), int(st * MSR))
        for st in (5.0, 18.0, 27.0):
            place(out, bell(midi(76), 4.0, MSR, decay=1.5) * 0.06, int(st * MSR))
    return out


def main():
    for name, x in sfx().items():
        write_ogg(os.path.join(SFX_DIR, name + ".ogg"), x, SR, peak=0.85)
    tracks = {
        "menu": music_menu(),
        "map_act1": music_map(1),
        "map_act2": music_map(2),
        "combat": music_combat("normal"),
        "elite": music_combat("elite"),
        "boss": music_combat("boss"),
    }
    for name, x in tracks.items():
        write_ogg(os.path.join(MUSIC_DIR, name + ".ogg"), x, MSR, peak=0.8, quality=3)
    for name in ("swamp", "crypt"):
        write_ogg(os.path.join(AMB_DIR, name + ".ogg"), stinger_free_ambience(name), MSR, peak=0.6, quality=2)
    print("Audio written to assets/audio/")


if __name__ == "__main__":
    main()
