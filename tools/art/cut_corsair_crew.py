"""Cut the two Corsair's Reach crew out of their opaque generation renders.

    python tools/art/cut_corsair_crew.py

The crew arrive as one frame per game state holding *both* women, which is the
property the cabinet depends on: their reaction is shared by construction, so
the pair can never be caught feeling different things about the same result.
`prepare_corsair.py` splits each frame down the middle afterwards and stands
each woman in her own lane.

They arrive opaque. The generator paints a checkerboard where it was asked for
transparency, so the alpha has to be made here before anything else can use
them. Raw outputs under assets/source/layered_v2/corsair/ are never modified;
the transparent versions are written beside them under `cutouts/`.

Segmentation is `rembg`'s `isnet-general-use` with alpha matting, which keeps
loose hair, the ostrich plume on the captain's tricorn and the fringe of the
sash instead of chewing through them. Install it with
`pip install rembg onnxruntime`; the model downloads once on first run.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/corsair"
OUT = SOURCE / "cutouts"

## One frame per state, each holding both women. Named for the state the
## cabinet is in, which is how `prepare_corsair.CREW_STATES` reads them.
FRAMES: list[str] = [
    "crew_v5_ready_48889ddd",
    "crew_v5_tense_cb3e8b4b",
    "crew_v5_cheer_c9a7055d",
    "crew_v5_wince_12f28921",
]


## Other opaque Corsair renders that arrive on the same painted checkerboard.
## They are not crew, but they need the same cut, and giving them a second
## script would mean two places to keep the matting settings in step.
SHEETS: list[str] = [
    "feather_burst_66da3f61",
]


def main() -> int:
    from rembg import new_session, remove

    OUT.mkdir(parents=True, exist_ok=True)
    session = new_session("isnet-general-use")
    for name in FRAMES + SHEETS:
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
        # Both women should survive the cut, so the frame keeps two separate
        # islands of paint. A frame that comes back nearly empty means the
        # matting ate them and the state has to be regenerated, not shipped.
        print(
            "%-28s transparent=%5.1f%%  painted=%6.1f%%"
            % (name, 100.0 * (alpha < 16).mean(), 100.0 * (alpha > 200).mean())
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
