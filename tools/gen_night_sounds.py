"""Synthesises night sounds into assets/sounds/: python3 tools/gen_night_sounds.py
(needs numpy and ffmpeg)

rain.ogg        a seamless 20 s loop of heavy rain on the roof and windows, heard from inside
thunder_0..3    distant and near thunder: a crack (for the near ones) and a long rolling rumble
pipe_knock_0..2 the heating pipes knocking as they cool, heard through a wall
"""
import os, subprocess, tempfile, wave
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'sounds')
RATE = 44100
rng = np.random.default_rng(11)


def fast_lowpass(x, cutoff):
    """The same filter via FFT (zero phase), for long sounds."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / RATE)
    spec /= (1 + (f / cutoff) ** 2)
    return np.fft.irfft(spec, len(x))


def highpass(x, cutoff):
    return x - fast_lowpass(x, cutoff)


def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.89
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        path = tmp.name
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', path, '-c:a', 'libvorbis', '-q:a', '4',
            os.path.join(OUT, name + '.ogg')], check=True)
    os.remove(path)
    print(name)


def rain(seconds=20.0):
    n = int(seconds * RATE)
    # The steady hiss of a downpour on a flat roof, muffled by the ceiling.
    hiss = fast_lowpass(highpass(rng.standard_normal(n), 300), 2600) * 0.5
    rumble = fast_lowpass(rng.standard_normal(n), 180) * 0.8
    # Drops on the windows and gutters: thousands of tiny clicks, a few heavier ones.
    drops = np.zeros(n)
    for count, size, tone in [(9000, 0.25, 5000), (900, 0.8, 1800), (120, 1.6, 700)]:
        at = rng.integers(0, n - 2000, count)
        length = int(RATE * 0.012)
        t = np.arange(length) / RATE
        for i, start in enumerate(at):
            amp = size * rng.uniform(0.3, 1.0)
            f = tone * rng.uniform(0.7, 1.4)
            drops[start:start + length] += amp * np.sin(2 * np.pi * f * t) * np.exp(-t * rng.uniform(250, 600))
    drops = fast_lowpass(drops, 4000) * 0.35
    # Gusts: the loudness swells and settles every few seconds.
    swell = 1.0 + 0.25 * np.sin(2 * np.pi * np.arange(n) / RATE / 6.7) + 0.15 * np.sin(2 * np.pi * np.arange(n) / RATE / 2.9 + 1.0)
    # Heard through the roof: the top end is muffled.
    x = fast_lowpass(fast_lowpass((hiss + rumble + drops) * swell, 3000), 5000)
    # Seamless: cross-fade the last second into the first.
    fade = int(RATE * 1.0)
    ramp = np.linspace(0, 1, fade)
    x[:fade] = x[:fade] * ramp + x[-fade:] * (1 - ramp)
    return x[:-fade]


def thunder(near, seconds):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    noise = rng.standard_normal(n)
    # The rumble: low noise that rolls (lumpy, slow swells) and dies away.
    rolls = np.zeros(n)
    for _ in range(9):
        centre = rng.uniform(0.1, 0.65) * seconds
        width = rng.uniform(0.3, 1.2)
        rolls += rng.uniform(0.4, 1.0) * np.exp(-((t - centre) / width) ** 2)
    body = fast_lowpass(noise, 120 if not near else 220) * rolls * np.exp(-t / (seconds * 0.45))
    x = body
    if near:
        # The crack overhead first: a bright burst, then the boom.
        crack = highpass(noise, 600) * np.exp(-t / 0.08) * (t < 0.6)
        boom = fast_lowpass(noise, 90) * np.exp(-t / 1.2) * 2.5
        x = x + crack * 0.9 + boom
    attack = np.minimum(1.0, t / (0.01 if near else 0.4))
    return x * attack


save('rain', rain())
save('thunder_0', thunder(False, 9.0))
save('thunder_1', thunder(False, 11.0))
save('thunder_2', thunder(True, 8.0))
save('thunder_3', thunder(True, 10.0))


def knock(hits):
    """Old heating pipes ticking and knocking as they cool: a few metallic taps."""
    seconds = 0.4 + 0.28 * hits
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    x = np.zeros(n)
    at = 0.02
    for i in range(hits):
        start = int(at * RATE)
        tt = t[:n - start]
        tone = np.zeros_like(tt)
        base = rng.uniform(380, 620)
        for ratio, amp in [(1.0, 1.0), (2.76, 0.5), (5.4, 0.25), (8.9, 0.12)]:
            tone += amp * np.sin(2 * np.pi * base * ratio * tt) * np.exp(-tt * rng.uniform(18, 40) * ratio ** 0.5)
        thump = fast_lowpass(rng.standard_normal(len(tt)), 300) * np.exp(-tt * 60) * 2.0
        x[start:] += (tone + thump) * rng.uniform(0.5, 1.0)
        at += rng.uniform(0.12, 0.35)
    # Heard through the walls.
    return fast_lowpass(x, 2500)


for i, hits in enumerate([2, 4, 6]):
    save('pipe_knock_%d' % i, knock(hits))
