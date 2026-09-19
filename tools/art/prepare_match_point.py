"""Build the Match Point production art from the raw Higgsfield outputs.

    python tools/art/prepare_match_point.py

Raw outputs under assets/source/layered_v2/match_point/ are never modified.

Hostess poses were edited on a flat grey backdrop and cut out with Higgsfield's
background remover. The cut-outs keep a thin grey rim in soft hair edges, so
each one is first de-fringed against the measured backdrop grey (the edge colour
is un-mixed from the grey, and near-grey rim texels lose their alpha). The
1696x2528 edits are then scaled to the 1360x2048 house canvas and handed to the
shared character pipeline (tools/art/prepare_characters.py: alpha floor, colour
bleed, head registration of pose variants, 16 px clear border -> 1392x2080).

The prop sheet is sliced into the tennis ball and the brass court-stud peg.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/match_point"
OUT = ROOT / "assets/production/match_point"
HOSTS = ROOT / "assets/production/characters/hosts"
CANVAS = (1360, 2048)

# (production name, cut-out, grey edit it was cut from). The first is the master.
POSES = [
    ("match_point_hostess.png", "idle_cutout_70a9384e.png", "idle_grey_d92433bb.png"),
    ("match_point_hostess_serve.png", "serve_cutout_32598080.png", "serve_grey_619d5f00.png"),
    ("match_point_hostess_watch.png", "watch_cutout_760929b5.png", "watch_grey_1b9932fe.png"),
    (
        "match_point_hostess_celebrate.png",
        "celebrate_cutout_acc757fc.png",
        "celebrate_grey_37bf61b2.png",
    ),
]


def _pipeline():
    spec = importlib.util.spec_from_file_location(
        "prepare_characters", ROOT / "tools/art/prepare_characters.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def backdrop_grey(grey_edit: Path) -> np.ndarray:
    rgb = np.asarray(Image.open(grey_edit).convert("RGB"), dtype=np.float32)
    patches = [rgb[:48, :48], rgb[:48, -48:], rgb[1200:1260, :48], rgb[1200:1260, -48:]]
    return np.median(np.concatenate([p.reshape(-1, 3) for p in patches]), axis=0)


def defringe(cutout: Image.Image, grey: np.ndarray) -> Image.Image:
    rgba = np.asarray(cutout.convert("RGBA"), dtype=np.float32)
    alpha = rgba[..., 3] / 255.0
    colour = rgba[..., :3]
    # The rim: texels within ~4 px of transparency.
    solid = Image.fromarray(((alpha > 0.98) * 255).astype(np.uint8))
    core = np.asarray(solid.filter(ImageFilter.MinFilter(9)), dtype=np.float32) / 255.0
    rim = (alpha > 0.0) & (core < 0.5)
    # Un-mix the grey backdrop from partially transparent rim texels.
    a = np.clip(alpha, 1e-3, 1.0)[..., None]
    unmixed = (colour - (1.0 - a) * grey) / a
    soft = rim & (alpha < 0.98)
    colour[soft] = np.clip(unmixed[soft], 0, 255)
    # Rim texels that are still the backdrop grey are matte, not hair.
    distance = np.linalg.norm(rgba[..., :3] - grey, axis=-1)
    greyness = np.clip((distance - 10.0) / 26.0, 0.0, 1.0)
    alpha = np.where(rim, alpha * greyness, alpha)
    out = np.dstack([colour, np.clip(alpha, 0.0, 1.0) * 255.0])
    return Image.fromarray(out.round().astype(np.uint8), "RGBA")


def to_canvas(image: Image.Image) -> Image.Image:
    width = round(image.width * CANVAS[1] / image.height)
    scaled = image.resize((width, CANVAS[1]), Image.LANCZOS)
    left = (width - CANVAS[0]) // 2
    return scaled.crop((left, 0, left + CANVAS[0], CANVAS[1]))


def build_hostess() -> None:
    pipeline = _pipeline()
    base: Image.Image | None = None
    for output, cutout, grey_edit in POSES:
        grey = backdrop_grey(SOURCE / grey_edit)
        image = to_canvas(defringe(Image.open(SOURCE / cutout), grey))
        if base is not None:
            image = pipeline.align_to(image, base)
        image = pipeline.clean_alpha(image)
        if base is None:
            base = image
        padded = Image.new("RGBA", (image.width + 32, image.height + 32), (0, 0, 0, 0))
        padded.paste(image, (16, 16))
        padded = pipeline._bleed(padded, np.zeros(1))
        padded.save(HOSTS / output, optimize=True)
        alpha = np.asarray(padded.getchannel("A"))
        ys, xs = np.nonzero(alpha > 128)
        print(
            f"{output}: {padded.size} grey={grey.round().tolist()} "
            f"used=({xs.min()},{ys.min()})-({xs.max()},{ys.max()}) "
            f"head={pipeline.head_anchor(padded).round().tolist()}"
        )


def build_backdrop() -> None:
    backdrop = Image.open(SOURCE / "backdrop_f1f01d22.png").convert("RGB")
    assert backdrop.size == (3840, 2160), backdrop.size
    backdrop.save(OUT / "match_point_backdrop.png", optimize=True)


def _slice(sheet: Image.Image, box: tuple[int, int, int, int], side: int, name: str) -> None:
    piece = sheet.crop(box)
    alpha = np.asarray(piece.getchannel("A")) > 24
    ys, xs = np.nonzero(alpha)
    piece = piece.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    scale = (side - 8) / max(piece.size)
    piece = piece.resize(
        (max(1, round(piece.width * scale)), max(1, round(piece.height * scale))), Image.LANCZOS
    )
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(piece, ((side - piece.width) // 2, (side - piece.height) // 2))
    pipeline = _pipeline()
    square = pipeline._bleed(pipeline.clean_alpha(square), np.zeros(1))
    square.save(OUT / name, optimize=True)
    print(name, square.size, "from", box)


def build_props() -> None:
    sheet = Image.open(SOURCE / "props_f41b5c0c.png").convert("RGBA")
    half = sheet.width // 2
    _slice(sheet, (0, 0, half, sheet.height), 256, "match_point_ball.png")
    _slice(sheet, (half, 0, sheet.width, sheet.height), 128, "match_point_peg.png")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    build_backdrop()
    build_props()
    build_hostess()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
