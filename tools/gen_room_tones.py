"""Synthesises the quiet machine sounds RoomTones loops around the school, with ffmpeg:
the kitchen fridge, the vending machine, a fluorescent tube's buzz and a wall clock's tick.
Each loops seamlessly (whole cycles of every tone in the file).

    python3 tools/gen_room_tones.py
"""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sounds"
RATE = 44100

# name: (seconds, ffmpeg aevalsrc expression of t, extra filters)
TONES = {
    # A compressor's low drone that swells a little every two seconds.
    "room_fridge": (2.0, "(0.5*sin(2*PI*50*t)+0.3*sin(2*PI*100*t)+0.12*sin(2*PI*150*t)+0.05*sin(2*PI*200*t))"
                    "*(0.85+0.15*sin(2*PI*0.5*t))", "lowpass=f=600"),
    # A buzzier mains hum with a faint rattle in it.
    "room_vending": (2.0, "(0.45*sin(2*PI*120*t)+0.3*sin(2*PI*240*t)+0.2*sin(2*PI*360*t)+0.1*sin(2*PI*600*t))"
                     "*(0.9+0.1*sin(2*PI*30*t))", "lowpass=f=1800"),
    # A tube's thin, edgy 120 Hz buzz, clipped so it has teeth, with the odd crackle of hiss.
    "room_fluorescent": (1.0, "0.6*clip(3*sin(2*PI*120*t)+sin(2*PI*240*t),-1,1)*0.4+0.1*sin(2*PI*1080*t)"
                         "+0.04*(random(0)-0.5)", "highpass=f=90,lowpass=f=5000"),
    # One soft tick per second: a few milliseconds of bright click.
    "clock_tick": (1.0, "if(lt(t,0.012),(random(0)-0.5)*exp(-t*450)+0.6*sin(2*PI*2900*t)*exp(-t*600),0)",
                   "highpass=f=1200"),
}
# Peak level of each file (dB): RoomTones sets how loud each plays on top of this.
PEAK_DB = {"room_fridge": -6.0, "room_vending": -6.0, "room_fluorescent": -8.0, "clock_tick": -12.0}


def make(name: str, seconds: float, expression: str, filters: str) -> None:
    path = OUT / f"{name}.ogg"
    peak = PEAK_DB[name]
    chain = f"{filters},volume={peak}dB" if filters else f"volume={peak}dB"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi",
                    "-i", f"aevalsrc='{expression}':s={RATE}:d={seconds}",
                    "-af", f"{chain},alimiter=limit=0.9", "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", str(path)],
                   check=True)
    print("wrote", path)


def main() -> None:
    for name, (seconds, expression, filters) in TONES.items():
        make(name, seconds, expression, filters)


if __name__ == "__main__":
    main()
