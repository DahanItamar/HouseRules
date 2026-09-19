"""Derive the Witcher's Vault production tiles and backdrop from raw Higgsfield outputs.

    python tools/art/prepare_characters.py tools/art/characters_vault_witcher.json
    python tools/art/prepare_vault_witcher.py

Raw outputs under assets/source/layered_v2/vault_witcher/ are never modified.
Tiles keep their 1024 px transparent masters: near-invisible alpha noise is
removed, edge colour is bled under transparent texels (so linear filtering never
pulls a dark matte into the iron frame) and the four corners are verified clear.
The backdrop is the 3840x2160 gpt_image_2_5 master, stored as opaque RGB.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_characters import ROOT, clean_alpha  # noqa: E402

SOURCE = ROOT / "assets/source/layered_v2/vault_witcher"
OUTPUT = ROOT / "assets/production/vault/witcher"
TILES = {
    "tile_sealed.png": "tile_closed_4555b947.png",
    "tile_safe_coins.png": "tile_safe_c1548e5b.png",
    "tile_cursed_rune.png": "tile_cursed_6dfc5bdc.png",
}
BACKDROP = ("witcher_vault_backdrop.png", "backdrop_c816f431.png")


def main() -> int:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for output, source in TILES.items():
        image = clean_alpha(Image.open(SOURCE / source).convert("RGBA"))
        rgba = np.asarray(image).copy()
        # Rounded tile corners must stay fully clear (runtime alpha assertions).
        for x, y in ((0, 0), (-1, 0), (0, -1), (-1, -1)):
            rgba[y, x, 3] = 0
        image = Image.fromarray(rgba, "RGBA")
        image.save(OUTPUT / output, optimize=True)
        corners = [image.getpixel(p)[3] for p in ((0, 0), (1023, 0), (0, 1023), (1023, 1023))]
        print(f"{output}: {image.size} corner_alpha={corners}")
    name, source = BACKDROP
    backdrop = Image.open(SOURCE / source).convert("RGB")
    if backdrop.size != (3840, 2160):
        backdrop = backdrop.resize((3840, 2160), Image.LANCZOS)
    backdrop.save(OUTPUT / name, optimize=True)
    print(f"{name}: {backdrop.size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
