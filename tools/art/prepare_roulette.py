"""Build the European Roulette production art from the raw Higgsfield outputs.

    python tools/art/prepare_roulette.py
    python tools/art/prepare_characters.py tools/art/characters_roulette.json

Raw outputs under assets/source/layered_v2/roulette/ are never modified. The
wheel master is re-centred on its bowl, then split into a static bowl and a
rotating rotor disc; the numbered pocket ring is drawn in code so the ball can
land in the exact pocket the math decided.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/roulette"
OUT = ROOT / "assets/production/roulette"

WHEEL_CENTRE = (1010, 997)
WHEEL_RADIUS = 1000
# Rotor (wooden cone, brass turret and its brass ring) radius in source pixels.
ROTOR_RADIUS = 472
CHIP_VALUES = [1, 5, 10, 25, 50]
GUESTS = {
    "guest_system.png": "guest_system_56593fc6.png",
    "guest_dreamer.png": "guest_dreamer_dfc293d7.png",
    "guest_regular.png": "guest_regular_3b660a0d.png",
}


def circle_mask(size: int, radius: float, feather: float = 1.5) -> Image.Image:
    scale = 4
    mask = Image.new("L", (size * scale, size * scale), 0)
    centre = size * scale / 2.0
    r = radius * scale
    ImageDraw.Draw(mask).ellipse((centre - r, centre - r, centre + r, centre + r), fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    return mask.filter(ImageFilter.GaussianBlur(feather * 0.5))


def build_wheel() -> None:
    wheel = Image.open(SOURCE / "wheel_b4bfdba9.png").convert("RGBA")
    cx, cy = WHEEL_CENTRE
    side = WHEEL_RADIUS * 2
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(wheel, (WHEEL_RADIUS - cx, WHEEL_RADIUS - cy))
    alpha = np.asarray(square.getchannel("A"), dtype=np.float32)
    rim = np.asarray(circle_mask(side, 986.0), dtype=np.float32)
    square.putalpha(Image.fromarray(np.minimum(alpha, rim).astype(np.uint8)))
    square.save(OUT / "roulette_wheel_bowl.png", optimize=True)
    rotor_side = ROTOR_RADIUS * 2 + 8
    offset = WHEEL_RADIUS - rotor_side // 2
    rotor = square.crop((offset, offset, offset + rotor_side, offset + rotor_side))
    rotor.putalpha(circle_mask(rotor_side, ROTOR_RADIUS))
    rotor.save(OUT / "roulette_wheel_rotor.png", optimize=True)
    print("wheel", square.size, "rotor", rotor.size)


def build_chips() -> None:
    sheet = Image.open(SOURCE / "chips_c4a5265b.png").convert("RGBA")
    alpha = np.asarray(sheet.getchannel("A")) > 96
    columns = np.where(alpha.any(axis=0))[0]
    runs: list[tuple[int, int]] = []
    start = columns[0]
    for previous, current in zip(columns, columns[1:]):
        if current - previous > 8:
            runs.append((start, previous))
            start = current
    runs.append((start, columns[-1]))
    assert len(runs) == len(CHIP_VALUES), runs
    for value, (left, right) in zip(CHIP_VALUES, runs):
        rows = np.where(alpha[:, left:right + 1].any(axis=1))[0]
        box = (left, rows.min(), right + 1, rows.max() + 1)
        chip = sheet.crop(box)
        side = max(chip.size)
        square = Image.new("RGBA", (side + 16, side + 16), (0, 0, 0, 0))
        square.paste(chip, ((side + 16 - chip.width) // 2, (side + 16 - chip.height) // 2))
        square = square.resize((320, 320), Image.LANCZOS)
        square.save(OUT / f"roulette_chip_{value}.png", optimize=True)
        print("chip", value, box)


def build_backdrop() -> None:
    backdrop = Image.open(SOURCE / "backdrop_5a29c98f.png").convert("RGB")
    assert backdrop.size == (3840, 2160)
    backdrop.save(OUT / "roulette_salon_backdrop.png", optimize=True)


def build_guests() -> None:
    for output, source in GUESTS.items():
        portrait = Image.open(SOURCE / source).convert("RGB").resize((512, 512), Image.LANCZOS)
        portrait.save(OUT / output, optimize=True)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    build_backdrop()
    build_wheel()
    build_chips()
    build_guests()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
