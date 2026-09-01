#!/usr/bin/env python3
"""Generate assets/wrong_input.wav: the "wrong button" blip.

A pad with no cursor pressing anything other than left/right gets a short,
low descending buzz, kept deliberately unlike menu_good.wav so a wrong
press can never be mistaken for a confirm. Every sample is synthesised
from a sine plus a little square-wave edge to read as a buzz rather than
a clean tone.

Re-run after tweaking the constants below:

    python3 tools/asset_gen/wrong_input.py
"""

import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 22050
DURATION = 0.14  # seconds
FREQ_START, FREQ_END = 220.0, 130.0  # descending pitch, in Hz
ATTACK, RELEASE = 0.01, 0.03  # fade in / out, in seconds
SINE_LEVEL = 0.5  # body of the tone
SQUARE_LEVEL = 0.15  # buzz edge on top of the sine

OUTPUT = Path(__file__).resolve().parents[2] / "assets" / "wrong_input.wav"


def envelope(t: float) -> float:
    if t < ATTACK:
        return t / ATTACK
    if t > DURATION - RELEASE:
        return max(0.0, (DURATION - t) / RELEASE)
    return 1.0


def generate_samples() -> list[int]:
    sample_count = int(SAMPLE_RATE * DURATION)
    samples = []
    for i in range(sample_count):
        t = i / SAMPLE_RATE
        progress = i / sample_count
        freq = FREQ_START + (FREQ_END - FREQ_START) * progress
        phase = 2 * math.pi * freq * t

        sine = math.sin(phase)
        square = 1 if sine >= 0 else -1
        value = sine * SINE_LEVEL + square * SQUARE_LEVEL

        clamped = max(-1.0, min(1.0, value * envelope(t)))
        samples.append(int(clamped * 32767))
    return samples


def main() -> None:
    samples = generate_samples()
    with wave.open(str(OUTPUT), "w") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        wav_file.writeframes(b"".join(struct.pack("<h", s) for s in samples))
    print(f"wrote {OUTPUT} ({len(samples)} samples)")


if __name__ == "__main__":
    main()
