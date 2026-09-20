"""Build the Tidewater Gold production art from the raw Higgsfield outputs.

    python tools/art/prepare_tidewater.py

Raw outputs under assets/source/layered_v2/tidewater/ are never modified.

Every piece is de-fringed against the dark generation backdrop, given an alpha
floor and a colour bleed under the transparent texels, so nothing shows a halo
when the cabinet scales it. The sprite sheets are re-cut: each cell is trimmed
to its own art and centred in an exact square cell, so the cabinet can address
them with a plain grid. The script also measures and prints the geometry the
cabinet needs - the gauge's blank dial and the teak frame's nine-slice margin -
so those numbers in src/ui/core_overclock/core_overclock_theme.gd stay checkable.

The host is an original character rendered on a flat studio grey; the cabinet
clips to her figure at runtime.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/tidewater"
OUT = ROOT / "assets/production/tidewater"
HOSTS = ROOT / "assets/production/characters/hosts"
HOST_CANVAS = (1360, 2048)
HOST_BORDER = 16

# (production name, grey-background pose render). The first is the master the
# others are head-registered against, and the pose the cabinet rests on.
HOST_POSES = [
    ("tidewater_hostess.png", "pose2_idle_54310637.png"),
    ("tidewater_hostess_watch.png", "pose2_watch_7c6235f3.png"),
    ("tidewater_hostess_cheer.png", "pose2_cheer_ce8a09ba.png"),
    # The restyled wince could not be generated, so the first set's still stands.
    ("tidewater_hostess_wince.png", "pose_wince_d046d4ce.png"),
]


def _pipeline():
    spec = importlib.util.spec_from_file_location(
        "prepare_characters", ROOT / "tools/art/prepare_characters.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _trim(image: Image.Image) -> Image.Image:
    alpha = np.asarray(image.getchannel("A")) > 16
    ys, xs = np.nonzero(alpha)
    return image.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def _square(image: Image.Image, side: int, margin: int = 6) -> Image.Image:
    piece = _trim(image)
    scale = (side - margin * 2) / max(piece.size)
    piece = piece.resize(
        (max(1, round(piece.width * scale)), max(1, round(piece.height * scale))), Image.LANCZOS
    )
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(piece, ((side - piece.width) // 2, (side - piece.height) // 2))
    return square


def _clean(image: Image.Image, erode: int = 1) -> Image.Image:
    pipeline = _pipeline()
    if erode <= 0:
        # A nine-slice plate keeps every edge texel: only the alpha floor and the
        # colour bleed are applied, never an erosion that would eat its border.
        return pipeline.clean_alpha(image)
    return pipeline.clean_alpha(pipeline.defringe(image, erode))


def _navy_bounds(image: Image.Image) -> tuple[float, float, float, float]:
    """Normalised bounds of the flat navy field inside a piece of art."""
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    red, green, blue, alpha = rgba[..., 0], rgba[..., 1], rgba[..., 2], rgba[..., 3]
    navy = (alpha > 200) & (blue > 48) & (blue > red * 1.6) & (blue > green * 1.25) & (red < 110)
    ys, xs = np.nonzero(navy)
    return (
        xs.min() / image.width,
        ys.min() / image.height,
        (xs.max() + 1) / image.width,
        (ys.max() + 1) / image.height,
    )


def build_backdrop() -> None:
    backdrop = Image.open(SOURCE / "backdrop_7464aece.png").convert("RGB")
    assert backdrop.size == (3840, 2160), backdrop.size
    backdrop.save(OUT / "tidewater_backdrop.png", optimize=True)
    print("tidewater_backdrop.png", backdrop.size)


def build_gauge() -> None:
    gauge = _square(_clean(Image.open(SOURCE / "depth_gauge_6d9d33d8.png")), 1024, 8)
    gauge.save(OUT / "tidewater_depth_gauge.png", optimize=True)
    left, top, right, bottom = _navy_bounds(gauge)
    print(
        "tidewater_depth_gauge.png 1024 dial centre=(%.4f, %.4f) radius=%.4f"
        % ((left + right) / 2, (top + bottom) / 2, (right - left) / 2)
    )


def build_props() -> None:
    for name, source, side in [
        ("tidewater_chest.png", "treasure_chest_bd478a91.png", 768),
        ("tidewater_compass.png", "compass_d33b45c7.png", 512),
    ]:
        piece = _square(_clean(Image.open(SOURCE / source)), side)
        piece.save(OUT / name, optimize=True)
        print(name, piece.size)


def build_frame() -> None:
    frame = _clean(Image.open(SOURCE / "frame_teak_8bb751e0.png"), 0)
    frame.save(OUT / "tidewater_frame.png", optimize=True)
    left, top, right, bottom = _navy_bounds(frame)
    margin = min(left, top, 1.0 - right, 1.0 - bottom) * frame.width
    print(
        "tidewater_frame.png %s navy=(%.3f, %.3f)-(%.3f, %.3f) patch_margin=%d"
        % (frame.size, left, top, right, bottom, round(margin))
    )


def build_sheet(source: str, name: str, columns: int, rows: int, cell: int) -> None:
    """Re-cuts a generated sheet so every cell is trimmed and exactly `cell` wide."""
    sheet = _clean(Image.open(SOURCE / source))
    out = Image.new("RGBA", (columns * cell, rows * cell), (0, 0, 0, 0))
    step_x = sheet.width / columns
    step_y = sheet.height / rows
    for row in range(rows):
        for column in range(columns):
            box = (
                round(column * step_x),
                round(row * step_y),
                round((column + 1) * step_x),
                round((row + 1) * step_y),
            )
            piece = sheet.crop(box)
            if np.asarray(piece.getchannel("A")).max() <= 16:
                continue
            out.paste(_square(piece, cell, 4), (column * cell, row * cell))
    out.save(OUT / name, optimize=True)
    print(name, out.size, "%dx%d cells of %d" % (columns, rows, cell))


def key_grey(image: Image.Image) -> Image.Image:
    """Cuts a pose out of the flat grey render background.

    The poses arrive fully opaque on a plain studio grey. Anything that could be
    that backdrop - unsaturated and in its luminance band, which includes the
    soft contact shadow - is flood filled inward from the frame edge, so grey
    folds inside the linen shirt are never touched. The transparent texels keep
    their grey, which is what the shared de-fringe then measures and un-mixes
    out of the soft rim.
    """
    from PIL import ImageDraw

    rgb = np.asarray(image.convert("RGB"), dtype=np.int16)
    luminance = rgb.mean(axis=-1)
    saturation = rgb.max(axis=-1) - rgb.min(axis=-1)
    candidate = (saturation < 14) & (luminance > 45) & (luminance < 195)
    # .copy() detaches the image from the numpy buffer: a flood fill on a
    # buffer-backed image is not visible when the array is read back.
    canvas = Image.fromarray((candidate * 255).astype(np.uint8), "L").copy()
    width, height = image.size
    seeds = [
        (1, 1),
        (width - 2, 1),
        (1, height - 2),
        (width - 2, height - 2),
        (width // 2, 1),
        (1, height // 2),
        (width - 2, height // 2),
        (width // 2, height - 2),
    ]
    for seed in seeds:
        if canvas.getpixel(seed) == 255:
            ImageDraw.floodfill(canvas, seed, 128, thresh=0)
    background = np.array(canvas) == 128
    # A prop can fence a pocket of backdrop off from the frame edge (the water
    # seen through the rail). The studio grey is flat to within a couple of
    # levels, so an exact-colour key clears those pockets without touching the
    # shirt, whose lightest folds are a hundred levels brighter.
    backdrop = np.median(rgb[background], axis=0) if background.any() else np.full(3, 129.0)
    background |= (np.abs(rgb - backdrop).max(axis=-1) <= 5) & (saturation <= 5)
    rgba = np.dstack(
        [np.asarray(image.convert("RGB")), np.where(background, 0, 255).astype(np.uint8)]
    )
    return Image.fromarray(rgba, "RGBA")


def head_band(image: Image.Image) -> tuple[float, float, float]:
    """Centroid and width of the topmost opaque mass: the head and its hair."""
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8) > 128
    rows = np.nonzero(alpha.any(axis=1))[0]
    top = int(rows.min())
    band = alpha[top : top + max(1, int(image.height * 0.08))]
    ys, xs = np.nonzero(band)
    return float(xs.mean()), float(top + ys.mean()), float(xs.max() - xs.min() + 1)


def torso_centre(image: Image.Image) -> float:
    """Horizontal centre of the figure's torso band.

    The poses are generated in one framing, so they are not rescaled here: a
    raised arm or a spin would fool any head measurement. What the cabinet needs
    is where her body is across the frame, which the torso band gives for every
    pose, and which src/ui/core_overclock/core_overclock_hostess.gd uses as each
    pose's anchor.
    """
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8) > 128
    band = alpha[int(image.height * 0.14) : int(image.height * 0.38)]
    _ys, xs = np.nonzero(band)
    return float(xs.mean())


def to_host_canvas(image: Image.Image) -> Image.Image:
    width = round(image.width * HOST_CANVAS[1] / image.height)
    scaled = image.resize((width, HOST_CANVAS[1]), Image.LANCZOS)
    left = (width - HOST_CANVAS[0]) // 2
    return scaled.crop((left, 0, left + HOST_CANVAS[0], HOST_CANVAS[1]))


def build_hostess() -> None:
    pipeline = _pipeline()
    base: Image.Image | None = None
    for output, source in HOST_POSES:
        image = to_host_canvas(pipeline.defringe(key_grey(Image.open(SOURCE / source)), 1))
        image = pipeline.clean_alpha(image)
        if base is None:
            base = image
        padded = Image.new(
            "RGBA", (image.width + HOST_BORDER * 2, image.height + HOST_BORDER * 2), (0, 0, 0, 0)
        )
        padded.paste(image, (HOST_BORDER, HOST_BORDER))
        padded = pipeline._bleed(padded, np.zeros(1))
        padded.save(HOSTS / output, optimize=True)
        alpha = np.asarray(padded.getchannel("A"))
        ys, xs = np.nonzero(alpha > 128)
        print(
            "%s %s used=Rect2(%d, %d, %d, %d) torso_x=%.0f"
            % (
                output,
                padded.size,
                xs.min(),
                ys.min(),
                xs.max() - xs.min() + 1,
                ys.max() - ys.min() + 1,
                torso_centre(padded),
            )
        )


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    HOSTS.mkdir(parents=True, exist_ok=True)
    build_backdrop()
    build_gauge()
    build_props()
    build_frame()
    build_sheet("coins_2d99f183.png", "tidewater_coins.png", 4, 4, 256)
    build_sheet("splash_92db0387.png", "tidewater_splash.png", 3, 3, 384)
    build_hostess()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
