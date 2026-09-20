"""Build the Harlequin Masquerade production art from the raw Higgsfield outputs.

    python tools/art/prepare_harlequin.py
    python tools/art/prepare_characters.py tools/art/characters_harlequin.json

Raw outputs under ``assets/source/layered_v2/harlequin/`` are never modified.

This tool does three jobs:

1. **Stage dressing.** The backdrop is copied at its 3840x2160 master size; the
   grid frame, the multiplier bar and the celebration crest are trimmed to their
   painted bounds so a NinePatchRect can stretch them without hunting for the
   art inside an empty canvas. Each one prints the patch margin the runtime
   should use.
2. **Tiles.** Every symbol is trimmed to its paint, centred on a square cell and
   rendered at one size, so a narrow harlequin gem and a wide pair of bells read
   as the same weight on the board without either touching a cell edge.
3. **Host cut-outs.** The four pose variants come back on a flat studio grey.
   The grey is keyed out from the border inward (so grey *inside* the figure,
   like the shadow under the blouse, survives), the alpha is cleaned and the
   cut-outs are written to ``harlequin/cutouts/`` for
   ``prepare_characters.py``, which de-fringes them, aligns them to the base
   master and pads every pose onto the shared 1392x2080 canvas.

The presenting pose came back with a chess board in her hand, which has nothing
to do with this machine; it is erased by polygon in characters_harlequin.json.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/harlequin"
CUTOUTS = SOURCE / "cutouts"
OUT = ROOT / "assets/production/harlequin"

## Board cell master size. Tiles are drawn at 36 virtual px, so 256 keeps them
## crisp to 4K (a 36 px cell is 144 px at UHD).
TILE_MASTER = 256
## Fraction of the cell the longest side of a symbol fills.
TILE_FILL = 0.88
## Symbol order must match UpgradeClusterMath.Symbol.
TILES = [
    ("harlequin_tile_gem_green.png", "tile_gem_green_bcf3e691.png"),
    ("harlequin_tile_gem_pink.png", "tile_gem_pink_aea5de95.png"),
    ("harlequin_tile_gem_violet.png", "tile_gem_violet_cea0179e.png"),
    ("harlequin_tile_gem_ivory.png", "tile_gem_ivory_b40952f0.png"),
    ("harlequin_tile_mask.png", "tile_mask_48067704.png"),
    ("harlequin_tile_jester_hat.png", "tile_jester_hat_080010b9.png"),
    ("harlequin_tile_bells.png", "tile_bells_ab29c0c8.png"),
    ("harlequin_tile_ticket.png", "tile_ticket_cac2cc55.png"),
]
SIDEKICKS = [
    ("harlequin_sidekick_pink.png", "sidekick_pink_f098eadd.png"),
    ("harlequin_sidekick_green.png", "sidekick_green_f93b2e9d.png"),
]
POSES = [
    ("harlequin_present.png", "pose_present_75558280.png"),
    ("harlequin_cheer.png", "pose_cheer_7362e4c2.png"),
    ("harlequin_pout.png", "pose_pout_fdb0da89.png"),
    ("harlequin_mask.png", "pose_mask_fc5e136e.png"),
]
## Props the generator invented that have nothing to do with this machine, as
## normalised polygons on the *raw* pose canvas. The presenting pose came back
## with an inlaid chess board balanced on her palm; erasing it leaves the open
## presenting hand, which is the gesture the beat actually needs. It is done here,
## before any rescaling, so the coordinates match what was measured on the art.
ERASE = {
    "harlequin_present.png": [
        [
            (0.598, 0.138),
            (0.988, 0.138),
            (0.988, 0.296),
            (0.866, 0.296),
            (0.866, 0.271),
            (0.598, 0.271),
        ]
    ]
}
ALPHA_FLOOR = 10


def opaque_box(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8) > ALPHA_FLOOR
    rows = np.where(alpha.any(axis=1))[0]
    columns = np.where(alpha.any(axis=0))[0]
    return int(columns.min()), int(rows.min()), int(columns.max()) + 1, int(rows.max()) + 1


def trim(name: str, source: str) -> Image.Image:
    image = Image.open(SOURCE / source).convert("RGBA")
    box = opaque_box(image)
    trimmed = image.crop(box)
    trimmed.save(OUT / name, optimize=True)
    print(f"{name}: {trimmed.size} from {image.size} box={box}")
    return trimmed


def build_stage() -> None:
    backdrop = Image.open(SOURCE / "backdrop_17738331.png").convert("RGB")
    assert backdrop.size == (3840, 2160), backdrop.size
    backdrop.save(OUT / "harlequin_stage_backdrop.png", optimize=True)
    print(f"harlequin_stage_backdrop.png: {backdrop.size}")
    trim("harlequin_grid_frame.png", "grid_frame_7225de82.png")
    trim("harlequin_multiplier_bar.png", "multiplier_bar_65c9ff3f.png")
    crest = trim("harlequin_crest.png", "crest_a3842cf0.png")
    print(f"  crest ribbon band: {ribbon_band(crest)}")
    # The shard sheet is a clean 4x4 of 256 px cells; it ships as the master so
    # the runtime can pick cells with an AtlasTexture.
    shards = Image.open(SOURCE / "shards_d4408a2c.png").convert("RGBA")
    assert shards.size == (1024, 1024), shards.size
    shards.save(OUT / "harlequin_shards.png", optimize=True)
    print(f"harlequin_shards.png: {shards.size} (4x4 cells of 256)")


def ribbon_band(crest: Image.Image) -> tuple[float, float]:
    """Normalised top and bottom of the crest's blank ribbon.

    The ribbon is the widest painted run in the lower third of the crest; the
    runtime draws the tier word inside it, so the band is measured rather than
    guessed.
    """
    alpha = np.asarray(crest.getchannel("A"), dtype=np.uint8) > 128
    widths = alpha.sum(axis=1)
    lower = range(int(crest.height * 0.62), crest.height)
    peak = max(lower, key=lambda row: widths[row])
    threshold = widths[peak] * 0.55
    top = peak
    while top > int(crest.height * 0.55) and widths[top - 1] > threshold:
        top -= 1
    bottom = peak
    while bottom < crest.height - 1 and widths[bottom + 1] > threshold:
        bottom += 1
    return (round(top / crest.height, 4), round((bottom + 1) / crest.height, 4))


def build_tiles() -> None:
    for name, source in TILES:
        image = Image.open(SOURCE / source).convert("RGBA")
        art = image.crop(opaque_box(image))
        span = max(art.size)
        scale = TILE_MASTER * TILE_FILL / span
        scaled = art.resize(
            (max(1, round(art.width * scale)), max(1, round(art.height * scale))), Image.LANCZOS
        )
        cell = Image.new("RGBA", (TILE_MASTER, TILE_MASTER), (0, 0, 0, 0))
        cell.paste(
            scaled,
            ((TILE_MASTER - scaled.width) // 2, (TILE_MASTER - scaled.height) // 2),
        )
        cell.save(OUT / name, optimize=True)
        print(f"{name}: art {art.size} -> {scaled.size} in {TILE_MASTER}px cell")


def build_sidekicks() -> None:
    for name, source in SIDEKICKS:
        image = Image.open(SOURCE / source).convert("RGBA")
        art = image.crop(opaque_box(image))
        height = 512
        width = max(1, round(art.width * height / art.height))
        art.resize((width, height), Image.LANCZOS).save(OUT / name, optimize=True)
        print(f"{name}: {art.size} -> {(width, height)}")


## Studio grey, the painted floor and the cast shadow are all neutral and
## mid-toned. The figure is not: her skin, jacket, hair and the harlequin stripe
## are warm or saturated, and her trousers and boots are far darker than any
## backdrop texel. Keying on "neutral and mid-toned" therefore separates the two
## where a distance-from-one-grey threshold cannot, because the poses carry a
## vignette *and* a wall-to-floor step.
GREY_SATURATION = 26.0
GREY_LUMA = (58.0, 214.0)


def key_studio_grey(image: Image.Image) -> Image.Image:
    """Key the studio backdrop, floor and cast shadow out of an opaque render.

    A texel is backdrop when it is near-neutral, mid-toned, *and* a corner of the
    frame can reach it without crossing the figure. The connectivity test is what
    keeps grey that belongs to the person: a fold in the ivory blouse or the
    shadow under the jacket is neutral and mid-toned too, but it is walled in.

    The cleared edge is softened by one blur pass so ``defringe`` in
    prepare_characters.py has a ramp to un-mix the grey from.
    """
    rgb = np.asarray(image.convert("RGB"), dtype=np.float32)
    saturation = rgb.max(axis=-1) - rgb.min(axis=-1)
    luma = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    neutral = (
        (saturation < GREY_SATURATION) & (luma > GREY_LUMA[0]) & (luma < GREY_LUMA[1])
    )
    alpha = np.ones(neutral.shape, dtype=np.float32)
    alpha[_border_region(neutral)] = 0.0
    faded = Image.fromarray((alpha * 255.0).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.0))
    out = image.convert("RGBA")
    out.putalpha(faded)
    return out


def _border_region(candidate: np.ndarray) -> np.ndarray:
    """Texels in ``candidate`` reachable from an image corner, 4-way.

    The figure stands clear of the frame in every pose, so the studio grey is one
    connected region touching all four corners. Anything grey that is *not*
    reachable from there (a fold in the blouse, the shadow under the jacket) is
    part of the person and is kept.
    """
    height, width = candidate.shape
    # `.copy()` detaches the image from the numpy buffer: Pillow marks a
    # `fromarray` image read-only, and floodfill would silently write elsewhere.
    mask = Image.fromarray(np.where(candidate, 255, 0).astype(np.uint8), "L").copy()
    for seed in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        if mask.getpixel(seed) == 255:
            ImageDraw.floodfill(mask, seed, 128)
    return np.asarray(mask) == 128


def _erase(image: Image.Image, polygons: list | None) -> Image.Image:
    """Clears `polygons` (normalised) from the alpha with a soft edge."""
    if not polygons:
        return image
    mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask)
    for polygon in polygons:
        draw.polygon([(x * image.width, y * image.height) for x, y in polygon], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(1.5))
    alpha = np.asarray(image.getchannel("A"), dtype=np.float32)
    alpha *= 1.0 - np.asarray(mask, dtype=np.float32) / 255.0
    out = image.copy()
    out.putalpha(Image.fromarray(alpha.clip(0, 255).astype(np.uint8)))
    return out


def build_pose_cutouts() -> None:
    CUTOUTS.mkdir(parents=True, exist_ok=True)
    for name, source in POSES:
        image = Image.open(SOURCE / source).convert("RGBA")
        cut = _erase(key_studio_grey(image), ERASE.get(name))
        cut.save(CUTOUTS / name, optimize=True)
        coverage = (np.asarray(cut.getchannel("A")) > 128).mean()
        print(f"cutouts/{name}: {cut.size} opaque={coverage:.3f}")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    build_stage()
    build_tiles()
    build_sidekicks()
    build_pose_cutouts()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
