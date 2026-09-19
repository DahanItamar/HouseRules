"""Build the Hold'em production derivatives from the raw Higgsfield outputs.

    python assets/source/layered_v2/poker/prepare_poker.py

Raw files in this folder are never modified. Outputs:
  assets/production/poker/poker_table_v1.png      3840x2160 table backdrop
  assets/production/poker/npc/<id>.png            512x512 portrait busts
  assets/production/poker/npc/<id>_react.png      512x512 reaction faces
  assets/production/poker/props/chips_{pot,black}.png trimmed chip art
The dealer poses go through tools/art/prepare_characters.py with
tools/art/characters_poker_dealer.json.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OUT = ROOT / "assets" / "production" / "poker"

PORTRAITS = {
    "shark": ("npc_shark_f6722d87.png", "npc_shark_react_7ac4ceed.png"),
    "rock": ("npc_rock_e8c2b761.png", "npc_rock_react_0d60be3d.png"),
    "maniac": ("npc_maniac_483fc85f.png", "npc_maniac_react_c1abdadf.png"),
    "calling_station": (
        "npc_calling_station_9e4ca8bd.png",
        "npc_calling_station_react_f9c885c3.png",
    ),
    "tourist": ("npc_tourist_885a9b33.png", "npc_tourist_react_cb5d4b56.png"),
}


def table() -> None:
    image = Image.open(HERE / "table_c4d00003.png").convert("RGB")
    assert image.size == (3840, 2160), image.size
    image.save(OUT / "poker_table_v1.png", optimize=True)


def portraits() -> None:
    target = OUT / "npc"
    target.mkdir(parents=True, exist_ok=True)
    for npc_id, (base, react) in PORTRAITS.items():
        for source, suffix in ((base, ""), (react, "_react")):
            path = HERE / source
            if not path.exists():
                print(f"missing {source}; skipped")
                continue
            image = Image.open(path).convert("RGB")
            side = min(image.size)
            left = (image.width - side) // 2
            image = image.crop((left, 0, left + side, side)).resize((512, 512), Image.LANCZOS)
            image.save(target / f"{npc_id}{suffix}.png", optimize=True)


def chips() -> None:
    target = OUT / "props"
    target.mkdir(parents=True, exist_ok=True)
    image = Image.open(HERE / "chip_stack_50a6a76a.png").convert("RGBA")
    rgba = np.asarray(image).copy()
    alpha = rgba[..., 3]
    alpha[alpha < 24] = 0
    rgba[..., 3] = alpha
    image = Image.fromarray(rgba, "RGBA")
    # The blue stack sits behind the white one, so only the free-standing black
    # stack is cut out singly (seat bets); the full trio is the pot pile.
    boxes = {"pot": (0, 0, image.width, image.height), "black": (654, 0, 1024, 1024)}
    for name, box in boxes.items():
        crop = image.crop(box)
        bbox = crop.getchannel("A").point(lambda value: 255 if value > 24 else 0).getbbox()
        crop = crop.crop(bbox)
        crop.save(target / f"chips_{name}.png", optimize=True)
        print(name, crop.size)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    table()
    portraits()
    chips()
