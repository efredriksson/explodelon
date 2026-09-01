# Asset generators

Zero-dependency Python scripts that produce committed assets in `assets/`.
Only assets defined by a formula belong here; hand-drawn art and recorded
sound do not.

Run one directly with a bare `python3` (no venv, no packages):

    python3 tools/asset_gen/arrow_shade.py

Each script keeps its tunable numbers as constants at the top. Edit those,
re-run, and commit the regenerated PNG.

| script           | output                   | what it is                                 |
| ---------------- | ------------------------ | ------------------------------------------ |
| `arrow_shade.py` | `assets/arrow_shade.png` | fade strip behind the map-selection arrows |
| `wrong_input.py` | `assets/wrong_input.wav` | descending buzz for a wrong button press   |

`png.py` is a shared minimal PNG writer (8-bit RGBA, no filtering), not a
generator itself. WAV output uses the standard-library `wave` module
directly.
