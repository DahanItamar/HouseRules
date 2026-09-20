"""Cut the Match Point court troughs out of their generation renders.

    python tools/art/prepare_match_point.py

The thirteen courts along the bottom of the board were flat rectangles filled
with one of three colours, which is the last screen in the game still drawing
its own furniture. They are painted plates now: a brass-rimmed trough with a
dark open slot along the top where the ball drops in, in three faces --
polished brass for the paying edges, ivory for the middle band, and deep
racing green for the centre where the ball usually lands.

The face of each plate is deliberately plain. The multiplier is drawn over it
in code, because the number changes with the risk setting and cannot be baked.

Raw outputs under assets/source/layered_v2/match_point/ are never modified.
They arrive opaque -- the generator paints a checkerboard where it is asked for
transparency -- so they are segmented here with rembg's `isnet-general-use`,
then trimmed to the paint so the board can place them by rectangle without
carrying a margin it has to guess at.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/match_point"
OUT = ROOT / "assets/production/match_point"

## Raw render -> production plate. The names are the payout band each one
## stands for, which is how `MatchPointStyle.court_plate` reads them.
PLATES: list[tuple[str, str]] = [
    ("court_hot_86f429db.png", "court_hot.png"),
    ("court_mid_1a064189.png", "court_mid.png"),
    ("court_cold_f6fb3803.png", "court_cold.png"),
    # The hatch the ball waits in before a serve. Same treatment, same reason.
    ("hatch_282df2a5.png", "hatch.png"),
]


def trim(image: Image.Image, floor: int = 16) -> Image.Image:
    """Crops to the paint, so the plate's rectangle is the plate."""
    alpha = np.asarray(image.getchannel("A")) > floor
    ys, xs = np.nonzero(alpha)
    if xs.size == 0:
        return image
    return image.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def main() -> int:
    from rembg import new_session, remove

    OUT.mkdir(parents=True, exist_ok=True)
    session = new_session("isnet-general-use")
    for source, name in PLATES:
        raw = Image.open(SOURCE / source).convert("RGBA")
        cut = remove(
            raw,
            session=session,
            alpha_matting=True,
            alpha_matting_foreground_threshold=250,
            alpha_matting_background_threshold=15,
            alpha_matting_erode_size=4,
        )
        plate = trim(cut)
        plate.save(OUT / name, optimize=True)
        alpha = np.asarray(plate.getchannel("A"))
        print("%-16s %s painted=%5.1f%%" % (name, plate.size, 100.0 * (alpha > 200).mean()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
