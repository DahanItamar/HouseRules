"""Cut the two Forno d'Oro hosts out of their opaque generation renders.

    python tools/art/cut_forno_hosts.py

The two characters were generated as poses standing in a studio or in a kitchen
set, so unlike the rest of the art they arrive fully opaque and have to be
segmented before anything else can use them. Raw outputs under
assets/source/layered_v2/forno/ are never modified; the transparent versions are
written beside them under `cutouts/` and are what `prepare_forno.py` reads.

Segmentation is `rembg`'s `isnet-general-use` with alpha matting, which keeps
loose hair and the handle of a peel instead of chewing through them. Install it
with `pip install rembg onnxruntime`; the model downloads once on first run.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/forno"
OUT = SOURCE / "cutouts"

## Every pose of both hosts. The two sets are matched per game state in
## `prepare_forno.HOST_STATES`; this script only has to make them transparent.
POSES: list[str] = [
    "left_ready_8e26e5f4",
    "left_launch_51807f94",
    "left_tense_4f6a42b2",
    "left_cheer_f4080c1d",
    "left_burnt_v2_c4f739ea",
    "right_ready_b3eda408",
    "right_launch_15ab7320",
    "right_baking_ec7dfd6b",
    "right_serve_4f6209ad",
    "right_burnt_v2_79a04071",
]


def main() -> int:
    from rembg import new_session, remove

    OUT.mkdir(parents=True, exist_ok=True)
    session = new_session("isnet-general-use")
    for name in POSES:
        source = Image.open(SOURCE / (name + ".png")).convert("RGBA")
        cut = remove(
            source,
            session=session,
            alpha_matting=True,
            alpha_matting_foreground_threshold=250,
            alpha_matting_background_threshold=15,
            alpha_matting_erode_size=8,
        )
        cut.save(OUT / (name + ".png"))
        alpha = np.asarray(cut.getchannel("A"))
        print("%-28s transparent=%5.1f%%" % (name, 100.0 * (alpha < 16).mean()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
