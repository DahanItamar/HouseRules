"""Build the Forno d'Oro production art from the raw Higgsfield outputs.

    python tools/art/prepare_forno.py

Raw outputs under assets/source/layered_v2/forno/ are never modified.

Every piece is de-fringed against the dark generation backdrop, given an alpha
floor and a colour bleed under the transparent texels, so nothing shows a halo
when the cabinet scales it. The sprite sheets are re-cut: each cell is trimmed
to its own art and centred in an exact square cell, so the cabinet can address
them with a plain grid. The script also measures and prints the geometry the
cabinet needs - the oven gauge's blank cream dial - so that number in
src/ui/core_overclock/core_overclock_theme.gd stays checkable.

The pizzaiola is an original character.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/forno"
OUT = ROOT / "assets/production/forno"
CUTOUTS = ROOT / "assets/source/layered_v2/forno/cutouts"
HOSTS = ROOT / "assets/production/characters/hosts"
HOST_CANVAS = (1360, 2048)
HOST_BORDER = 16


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
        return pipeline.clean_alpha(image)
    return pipeline.clean_alpha(pipeline.defringe(image, erode))


def dial_bounds(image: Image.Image) -> tuple[float, float, float, float]:
    """Normalised bounds of the blank cream dial inside the gauge art."""
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32)
    red, green, blue, alpha = rgba[..., 0], rgba[..., 1], rgba[..., 2], rgba[..., 3]
    spread = np.maximum(np.abs(red - green), np.abs(green - blue))
    cream = (alpha > 200) & (red > 200) & (green > 190) & (blue > 150) & (spread < 42)
    ys, xs = np.nonzero(cream)
    return (
        xs.min() / image.width,
        ys.min() / image.height,
        (xs.max() + 1) / image.width,
        (ys.max() + 1) / image.height,
    )


## The bake, in order. The pizza is the cabinet's multiplier readout: it is made
## on the counter and then browns in the oven, so the player reads how far the
## bake has gone from the food itself and not only from the dial.
BAKE_STAGES = [
    "bake0_doughball_129dd089.png",
    "bake1_stretched_2df8e78d.png",
    "bake2_sauced_cb8c5df2.png",
    "bake3_topped_raw_fd0356a5.png",
    "bake4_early_f93adda1.png",
    "bake5_melting_cec2e859.png",
    "bake6_golden_009638a4.png",
    "bake7_deep_e0098e96.png",
    "bake8_burnt_bdc071a8.png",
]


## Where the marble counter top caps the walnut front, as a fraction of the
## backdrop's height. Everything below this is cut out again as a foreground so
## the pizzaiola can stand BEHIND the counter instead of in front of it.
COUNTER_TOP: float = 232.0 / 540.0


def build_backdrop() -> None:
    """The v4 room: oven centred against the back wall, open floor either side.

    v1 stood the oven off to the right, which left the dial and the pizza
    hanging over the counter attached to nothing. v2 centred it. v3 lifted it
    and gave the lower half to a full-width counter -- but that counter cut the
    hosts off at the waist. v4 shrinks the counter to the middle third and
    leaves open terracotta floor on both sides, so both hosts stand in the room
    head to foot with the game itself on the centre line between them.
    """
    backdrop = Image.open(SOURCE / "backdrop_v4_4k.png").convert("RGB")
    if backdrop.size != (3840, 2160):
        backdrop = backdrop.resize((3840, 2160), Image.LANCZOS)
    backdrop.save(OUT / "forno_backdrop_v4.png", optimize=True)
    print("forno_backdrop_v4.png", backdrop.size)


def build_bake_stages(side: int = 512, margin: int = 4) -> None:
    """Nine stages on one shared square cell so they cross-fade in place.

    Every stage is scaled by the SAME factor, taken from the widest piece in the
    set, so the dough ball stays small and the finished pizza stays large. Sizing
    each stage to fill its own cell would make the dough read as big as the pizza
    and throw the growth away.
    """
    pieces = [_trim(_clean(Image.open(SOURCE / source))) for source in BAKE_STAGES]
    scale = (side - margin * 2) / max(max(piece.size) for piece in pieces)
    for index, piece in enumerate(pieces):
        scaled = piece.resize(
            (max(1, round(piece.width * scale)), max(1, round(piece.height * scale))),
            Image.LANCZOS,
        )
        cell = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        cell.paste(scaled, ((side - scaled.width) // 2, (side - scaled.height) // 2))
        name = "forno_bake_%d.png" % index
        cell.save(OUT / name, optimize=True)
        print(name, cell.size, "art", scaled.size)


def build_gauge() -> None:
    gauge = _square(_clean(Image.open(SOURCE / "oven_gauge_f77b65e1.png")), 1024, 8)
    gauge.save(OUT / "forno_oven_gauge.png", optimize=True)
    left, top, right, bottom = dial_bounds(gauge)
    print(
        "forno_oven_gauge.png 1024 dial centre=(%.4f, %.4f) radius=%.4f"
        % ((left + right) / 2, (top + bottom) / 2, (right - left) / 2)
    )


def build_props() -> None:
    for name, source, side in [
        ("forno_pizza.png", "pizza_3347bf9b.png", 768),
        ("forno_burnt_pizza.png", "burnt_pizza_cefb5d37.png", 768),
    ]:
        piece = _square(_clean(Image.open(SOURCE / source)), side)
        piece.save(OUT / name, optimize=True)
        print(name, piece.size)


def build_frame() -> None:
    frame = _clean(Image.open(SOURCE / "frame_terracotta_206e16d2.png"), 0)
    frame.save(OUT / "forno_frame.png", optimize=True)
    rgb = np.asarray(frame.convert("RGB"), dtype=np.int16)
    row = rgb[frame.height // 2]
    dark = np.nonzero(row.max(axis=1) < 60)[0]
    print(
        "forno_frame.png %s inner=(%d..%d) patch_margin=%d"
        % (frame.size, dark.min(), dark.max(), dark.min() + 6)
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


## The two hosts the user approved, and which pose each of them holds in each
## state of the bake. Generating them as one pair was rejected: these are the
## two characters that already exist, and the point is only to stand them in one
## room and have them react to the same thing at the same time.
##
## Every row is one game state, so a state can never show one of them
## celebrating while the other winces.
HOST_STATES: list[tuple[str, str, str]] = [
    ("ready", "left_ready_8e26e5f4", "right_ready_b3eda408"),
    ("launch", "left_launch_51807f94", "right_launch_15ab7320"),
    ("baking", "left_tense_4f6a42b2", "right_baking_ec7dfd6b"),
    ("served", "left_cheer_f4080c1d", "right_serve_4f6209ad"),
    ("burnt", "left_burnt_v2_c4f739ea", "right_burnt_v2_79a04071"),
]
## Every pose of one host is cut to this canvas, foot-aligned and centred on the
## body, so changing pose never makes her jump sideways or hop off the floor.
HOST_CELL = (1024, 1536)


def build_host_poses() -> None:
    """Cuts both hosts' poses to one shared, foot-aligned cell each.

    The raw poses are opaque studio and kitchen renders; the transparent
    versions under `cutouts/` come from `tools/art/cut_forno_hosts.py`.
    """
    pipeline = _pipeline()
    for side, index in (("left", 1), ("right", 2)):
        poses = [(row[0], row[index]) for row in HOST_STATES]
        trimmed = []
        for _, source in poses:
            image = _clean(Image.open(CUTOUTS / (source + ".png")), 1)
            trimmed.append(_trim(image))
        # One scale for the whole set, from the tallest pose, so they share a
        # height and the floor line stays put.
        scale = (HOST_CELL[1] - 24) / max(piece.height for piece in trimmed)
        for (name, _), piece in zip(poses, trimmed):
            sized = piece.resize(
                (max(1, round(piece.width * scale)), max(1, round(piece.height * scale))),
                Image.LANCZOS,
            )
            cell = Image.new("RGBA", HOST_CELL, (0, 0, 0, 0))
            cell.paste(sized, ((HOST_CELL[0] - sized.width) // 2, HOST_CELL[1] - 12 - sized.height))
            cell = pipeline._bleed(cell, np.zeros(1))
            out = OUT / ("forno_host_%s_%s.png" % (side, name))
            cell.save(out, optimize=True)
            alpha = np.asarray(cell.getchannel("A")) > 128
            ys, xs = np.nonzero(alpha)
            print(
                "forno_host_%s_%s.png %s used=Rect2(%d, %d, %d, %d)"
                % (side, name, cell.size, xs.min(), ys.min(),
                   xs.max() - xs.min() + 1, ys.max() - ys.min() + 1)
            )


def build_hostess() -> None:
    pipeline = _pipeline()
    image = _clean(Image.open(SOURCE / "hostess_d5a64ecb.png"), 1)
    width = round(image.width * HOST_CANVAS[1] / image.height)
    image = image.resize((width, HOST_CANVAS[1]), Image.LANCZOS)
    left = (width - HOST_CANVAS[0]) // 2
    image = image.crop((left, 0, left + HOST_CANVAS[0], HOST_CANVAS[1]))
    padded = Image.new(
        "RGBA", (image.width + HOST_BORDER * 2, image.height + HOST_BORDER * 2), (0, 0, 0, 0)
    )
    padded.paste(image, (HOST_BORDER, HOST_BORDER))
    padded = pipeline._bleed(padded, np.zeros(1))
    padded.save(HOSTS / "forno_hostess.png", optimize=True)
    alpha = np.asarray(padded.getchannel("A")) > 128
    ys, xs = np.nonzero(alpha)
    # Her own column, without the peel she holds out to one side: the columns
    # covered over most of her height.
    coverage = alpha.mean(axis=0)
    body = np.nonzero(coverage > 0.30)[0]
    print(
        "forno_hostess.png %s used=Rect2(%d, %d, %d, %d) body_columns=%d-%d"
        % (
            padded.size,
            xs.min(),
            ys.min(),
            xs.max() - xs.min() + 1,
            ys.max() - ys.min() + 1,
            body.min(),
            body.max(),
        )
    )


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    HOSTS.mkdir(parents=True, exist_ok=True)
    build_backdrop()
    build_bake_stages()
    build_gauge()
    build_props()
    build_frame()
    build_sheet("icons_a534fda5.png", "forno_icons.png", 3, 2, 256)
    build_sheet("embers_dbebbbf9.png", "forno_embers.png", 4, 4, 256)
    build_hostess()
    build_host_poses()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
