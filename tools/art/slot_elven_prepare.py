"""Build the Elven Court slot production art from its Higgsfield sources.

    python tools/art/slot_elven_prepare.py

* The cabinet bezel is re-fitted so its painted reel opening lands exactly on the
  runtime reel window (virtual Rect2(166, 151, 628, 234) on the 960x540 canvas).
  The whole painting is scaled uniformly to match the opening height; only the
  column that holds the opening (and the plaque/ledge above and below it) is
  widened, by about 13%, so carved ornaments stay in proportion. The aperture is
  then cut to true transparency so the runtime reels show through.
* The painted lever arm is trimmed for the animated runtime SlotLever.
* Reel symbols are trimmed to their painted subject and re-centred on a square
  1024 px transparent master with a consistent margin, so every icon reads at
  the same size inside a reel cell.

Source generations are never modified; outputs go to assets/production/slot/elven.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/slot_elven"
OUT = ROOT / "assets/production/slot/elven"

VIRTUAL = (960, 540)
OUT_SCALE = 4  # 3840x2160 master
REEL_WINDOW = (166, 151, 628, 234)  # x, y, w, h in virtual pixels

BEZEL_SOURCE = "bezel_a_036539be.png"
SYMBOLS = {
    "berries": "symbol_berries_1dcb34b8.png",
    "pear": "symbol_pear_a79c2b6c.png",
    "bell": "symbol_bell_f3217314.png",
    "leaf_bar": "symbol_bar_31566f6a.png",
    "ruby_seven": "symbol_seven_ab5b6afd.png",
    "moon_crystal": "symbol_moon_crystal_5357601e.png",
}


def _longest_run(mask: np.ndarray) -> tuple[int, int]:
    best = (0, 0)
    start = None
    for index, value in enumerate(list(mask) + [False]):
        if value and start is None:
            start = index
        elif not value and start is not None:
            if index - start > best[1] - best[0]:
                best = (start, index)
            start = None
    return best


def find_opening(rgb: np.ndarray) -> tuple[int, int, int, int]:
    dark = rgb.astype(np.int32).sum(axis=2) < 40
    height, width = dark.shape
    x0, x1 = _longest_run(dark[height // 2])
    y0, y1 = _longest_run(dark[:, (x0 + x1) // 2])
    return x0, y0, x1, y1


def _remove_painted_lever_arm(bezel: Image.Image) -> Image.Image:
    """The painting carries a static lever arm; the runtime SlotLever animates.

    Keep the carved mount and replace only the arm/knob above it with the forest
    wall painted directly above, blended through a soft mask, so the animated
    runtime lever is the only arm on screen.
    """
    s = OUT_SCALE
    left, top, right, bottom = 844 * s, 248 * s, 894 * s, 301 * s
    shift = 54 * s
    patch = bezel.crop((left, top - shift, right, bottom - shift))
    mask = Image.new("L", patch.size, 0)
    from PIL import ImageDraw, ImageFilter

    ImageDraw.Draw(mask).rounded_rectangle(
        (3 * s, 2 * s, patch.width - 3 * s, patch.height), radius=6 * s, fill=255
    )
    mask = mask.filter(ImageFilter.GaussianBlur(2 * s))
    out = bezel.copy()
    out.paste(patch, (left, top), mask)
    return out


def build_bezel() -> None:
    source = Image.open(SOURCE / BEZEL_SOURCE).convert("RGB")
    x0, y0, x1, y1 = find_opening(np.asarray(source))
    wx, wy, ww, wh = (v * OUT_SCALE for v in REEL_WINDOW)
    uniform = wh / float(y1 - y0)  # output px per source px
    inner = ww / float(x1 - x0)
    height = round(source.height * uniform)
    bands = [
        (0, x0, uniform),
        (x0, x1, inner),
        (x1, source.width, uniform),
    ]
    pieces = []
    for left, right, scale in bands:
        crop = source.crop((left, 0, right, source.height))
        pieces.append(crop.resize((round((right - left) * scale), height), Image.LANCZOS))
    strip = Image.new("RGB", (sum(p.width for p in pieces), height))
    cursor = 0
    for piece in pieces:
        strip.paste(piece, (cursor, 0))
        cursor += piece.width
    # Place the widened opening on the runtime reel window.
    offset_x = round(x0 * uniform) - wx
    offset_y = round(y0 * uniform) - wy
    canvas_w, canvas_h = VIRTUAL[0] * OUT_SCALE, VIRTUAL[1] * OUT_SCALE
    bezel = strip.crop((offset_x, offset_y, offset_x + canvas_w, offset_y + canvas_h))
    bezel = _remove_painted_lever_arm(bezel)
    rgba = np.asarray(bezel.convert("RGBA")).copy()
    # True-transparent aperture: the exact reel window, plus any painted black
    # that is still inside the gold inner bevel.
    rgba[wy:wy + wh, wx:wx + ww, 3] = 0
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(OUT / "elven_court_bezel.png", optimize=True)
    print(
        f"bezel: source opening=({x0},{y0})-({x1},{y1}) uniform={uniform:.4f} "
        f"inner={inner:.4f} crop_offset=({offset_x},{offset_y}) -> {bezel.size}"
    )


def build_symbol(name: str, filename: str, size: int = 1024, margin: float = 0.07) -> None:
    image = Image.open(SOURCE / filename).convert("RGBA")
    rgba = np.asarray(image).astype(np.float32)
    rgba[rgba[..., 3] < 10, 3] = 0.0
    image = Image.fromarray(rgba.astype(np.uint8), "RGBA")
    box = image.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
    subject = image.crop(box)
    limit = size * (1.0 - margin * 2.0)
    scale = min(limit / subject.width, limit / subject.height)
    subject = subject.resize(
        (round(subject.width * scale), round(subject.height * scale)), Image.LANCZOS
    )
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(
        subject, ((size - subject.width) // 2, (size - subject.height) // 2)
    )
    arr = np.asarray(canvas)
    Image.fromarray(arr, "RGBA").save(OUT / f"symbol_{name}.png", optimize=True)
    print(f"symbol_{name}: subject={subject.size} corner_alpha={arr[0, 0, 3]}")


def build_lever(filename: str = "lever_arm_87efa7ba.png") -> None:
    """Trim the painted lever arm to its subject with a clear transparent border."""
    image = Image.open(SOURCE / filename).convert("RGBA")
    rgba = np.asarray(image).astype(np.float32)
    rgba[rgba[..., 3] < 10, 3] = 0.0
    image = Image.fromarray(rgba.astype(np.uint8), "RGBA")
    left, top, right, bottom = image.getchannel("A").point(lambda a: 255 if a > 0 else 0).getbbox()
    pad = 16
    lever = image.crop((left - pad, top - pad, right + pad, bottom + pad))
    lever.save(OUT / "lever_arm.png", optimize=True)
    alpha = np.asarray(lever.getchannel("A")) > 128
    rows = np.where(alpha.any(axis=1))[0]
    # Pivot: centre of the rounded cap at the bottom of the shaft.
    cap = alpha[rows.max() - 40:rows.max() + 1]
    xs = np.where(cap.any(axis=0))[0]
    print(f"lever_arm: {lever.size} top={rows.min()} pivot=({(xs.min() + xs.max()) / 2:.1f}, "
          f"{rows.max() - 20})")


def main() -> int:
    build_bezel()
    build_lever()
    for name, filename in SYMBOLS.items():
        build_symbol(name, filename)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
