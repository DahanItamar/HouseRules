"""Build the Velvet Baccarat production art from the raw Higgsfield outputs.

    python tools/art/prepare_baccarat.py

Raw outputs under assets/source/layered_v2/baccarat/ are never modified.

Hostess: the four nano_banana_pro pose edits (cut out with remove_background)
are un-matted (the grey studio colour is un-mixed from the edge texels and
the rim pulled in by three pixels), normalised onto one 1360x2048 canvas, so every pose has the same stature
(head-top to sole) and the same head-centre column, then run through the shared
character pipeline (alpha floor, colour bleed, 16 px clear border) from
prepare_characters.py. The result is four 1392x2080 head-registered masters
that cross-fade without the face jumping.

Also builds the 3840x2160 salon backdrop, four 320 px chips sliced from the
chip sheet, and the trimmed card shoe.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from prepare_characters import _bleed, clean_alpha, foot_pivot, head_anchor  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/baccarat"
OUT = ROOT / "assets/production/baccarat"
HOSTS = ROOT / "assets/production/characters/hosts"

CANVAS = (1360, 2048)
# Every pose is scaled so head-top to sole spans this many canvas pixels.
FIGURE_HEIGHT = 1990
TOP_MARGIN = 24
HEAD_COLUMN = 680
POSES = {
    "baccarat_hostess.png": "hostess_idle_cutout_1da6b775.png",
    "baccarat_hostess_deal.png": "hostess_deal_cutout_88a6aff8.png",
    "baccarat_hostess_squeeze.png": "hostess_squeeze_cutout_1b01554e.png",
    "baccarat_hostess_announce.png": "hostess_announce_cutout_69f02fd1.png",
}
CHIP_VALUES = [20, 40, 100, 200]


# remove_background keeps the studio grey (137,137,137) under the cut, so edge
# texels are a mix of figure and grey; this many pixels of rim are pulled in.
MATTE_ERODE = 3


def unmatte(image: Image.Image, erode: int = MATTE_ERODE) -> Image.Image:
    """Un-mix the studio grey from partly transparent edge texels, then pull the
    alpha in by ``erode`` pixels with a soft rim so no light outline remains."""
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    alpha = rgba[..., 3] / 255.0
    clear = alpha <= 0.0
    matte = np.median(rgba[..., :3][clear], axis=0) if clear.any() else np.zeros(3)
    edge = (alpha > 0.02) & (alpha < 0.98)
    colour = rgba[..., :3]
    unmixed = (colour - (1.0 - alpha[..., None]) * matte) / np.maximum(alpha[..., None], 0.02)
    colour[edge] = np.clip(unmixed[edge], 0.0, 255.0)
    mask = Image.fromarray((alpha * 255.0).astype(np.uint8))
    eroded = mask.filter(ImageFilter.MinFilter(erode * 2 + 1)).filter(ImageFilter.GaussianBlur(0.8))
    rgba[..., 3] = np.minimum(rgba[..., 3], np.asarray(eroded, dtype=np.float32))
    rgba[..., :3] = colour
    return Image.fromarray(rgba.clip(0, 255).astype(np.uint8), "RGBA")


def normalise(image: Image.Image) -> Image.Image:
    alpha = np.asarray(image.getchannel("A")) > 128
    rows = np.where(alpha.any(axis=1))[0]
    top, bottom = int(rows.min()), int(rows.max())
    scale = FIGURE_HEIGHT / float(bottom - top + 1)
    size = (round(image.width * scale), round(image.height * scale))
    scaled = image.resize(size, Image.LANCZOS)
    head = head_anchor(scaled)
    scaled_alpha = np.asarray(scaled.getchannel("A")) > 128
    scaled_top = int(np.where(scaled_alpha.any(axis=1))[0].min())
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    canvas.paste(scaled, (round(HEAD_COLUMN - head[0]), TOP_MARGIN - scaled_top), scaled)
    return canvas


def build_hostess() -> None:
    HOSTS.mkdir(parents=True, exist_ok=True)
    for output, source in POSES.items():
        image = normalise(unmatte(Image.open(SOURCE / source).convert("RGBA")))
        image = clean_alpha(image)
        padded = Image.new("RGBA", (image.width + 32, image.height + 32), (0, 0, 0, 0))
        padded.paste(image, (16, 16))
        image = _bleed(padded, np.zeros(1))
        image.save(HOSTS / output, optimize=True)
        alpha = np.asarray(image.getchannel("A")) > 128
        ys, xs = np.nonzero(alpha)
        corners = [image.getpixel(p)[3] for p in
                   ((0, 0), (image.width - 1, 0), (0, image.height - 1),
                    (image.width - 1, image.height - 1))]
        print(f"{output}: {image.size} used=({xs.min()},{ys.min()},{xs.max() - xs.min() + 1},"
              f"{ys.max() - ys.min() + 1}) head={head_anchor(image).round(1)} "
              f"pivot={foot_pivot(image)} corners={corners}")


def build_chips() -> None:
    sheet = Image.open(SOURCE / "chips_726a4b95.png").convert("RGBA")
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
        chip = sheet.crop((left, rows.min(), right + 1, rows.max() + 1))
        side = max(chip.size)
        square = Image.new("RGBA", (side + 16, side + 16), (0, 0, 0, 0))
        square.paste(chip, ((side + 16 - chip.width) // 2, (side + 16 - chip.height) // 2))
        square.resize((320, 320), Image.LANCZOS).save(
            OUT / f"baccarat_chip_{value}.png", optimize=True
        )
        print("chip", value, (left, rows.min(), right + 1, rows.max() + 1))


def build_shoe() -> None:
    shoe = Image.open(SOURCE / "shoe_94872ed0.png").convert("RGBA")
    shoe = clean_alpha(shoe)
    box = shoe.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    shoe = shoe.crop((box[0] - 8, box[1] - 8, box[2] + 8, box[3] + 8))
    shoe.save(OUT / "baccarat_shoe.png", optimize=True)
    print("shoe", shoe.size)


def build_backdrop() -> None:
    backdrop = Image.open(SOURCE / "backdrop_8443d56d.png").convert("RGB")
    assert backdrop.size == (3840, 2160)
    backdrop.save(OUT / "baccarat_salon_backdrop.png", optimize=True)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    build_backdrop()
    build_chips()
    build_shoe()
    build_hostess()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
