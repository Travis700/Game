"""Synthesises the restroom and music room sounds with ffmpeg: a running tap (loops), a toilet
flushing, and the band room piano's notes (piano_<note>.ogg, a few that sound wrong together).

    python3 tools/gen_fixture_sounds.py
"""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sounds"
RATE = 44100

# A struck string: a stack of slightly sharp harmonics, the high ones dying fastest, a thump of
# hammer at the start, and a slow beat between two strings a hair out of tune (an old school piano).
PIANO_NOTES = {"a3": 220.0, "c4": 261.63, "d4": 293.66, "ds4": 311.13, "e4": 329.63, "a4": 440.0}


def piano(freq: float) -> str:
    parts = []
    for n, level in [(1, 0.5), (2, 0.32), (3, 0.16), (4, 0.1), (5, 0.06), (6, 0.04)]:
        f = freq * n * (1 + 0.0004 * n * n)
        decay = 1.1 + 0.9 * n
        parts.append(f"{level}*sin(2*PI*{f:.3f}*t)*exp(-{decay:.2f}*t)")
        # The second string, 0.7 Hz off: a slow wobble.
        parts.append(f"{level * 0.6}*sin(2*PI*{f + 0.7:.3f}*t)*exp(-{decay:.2f}*t)")
    hammer = "0.25*(random(0)-0.5)*exp(-t*90)"
    return "+".join(parts) + "+" + hammer


# name: (seconds, ffmpeg aevalsrc expression of t, extra filters, gain in dB)
SOUNDS = {
    # Water running into a steel basin: hiss with a gurgle wandering through it.
    "tap_water": (3.0, "(random(0)-0.5)*(0.8+0.2*sin(2*PI*7*t)*sin(2*PI*1.3*t))",
                  "highpass=f=500,lowpass=f=6000,bandpass=f=1800:width_type=o:w=2.5", 2.0),
    # The handle's clunk, a roar of water swelling then draining away, a gurgle at the end.
    "toilet_flush": (4.5, "if(lt(t,0.06),0.8*sin(2*PI*140*t)*exp(-t*60),0)"
                     "+(random(0)-0.5)*min(1,t*2.5)*exp(-max(0,t-1.2)*0.9)"
                     "+0.3*sin(2*PI*(90+40*sin(2*PI*5*t))*t)*exp(-pow(t-3.4,2)*6)",
                     "highpass=f=80,lowpass=f=3500", -1.0),
}
SOUNDS.update({"piano_" + name: (3.5, piano(freq), "lowpass=f=5000,afade=t=out:st=2.8:d=0.7", -9.0)
               for name, freq in PIANO_NOTES.items()})


def make(name: str, seconds: float, expression: str, filters: str, peak: float) -> None:
    path = OUT / f"{name}.ogg"
    chain = f"{filters},volume={peak}dB" if filters else f"volume={peak}dB"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi",
                    "-i", f"aevalsrc='{expression}':s={RATE}:d={seconds}",
                    "-af", f"{chain},alimiter=limit=0.9", "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", str(path)],
                   check=True)
    print("wrote", path)


def main() -> None:
    for name, (seconds, expression, filters, peak) in SOUNDS.items():
        make(name, seconds, expression, filters, peak)


if __name__ == "__main__":
    main()
