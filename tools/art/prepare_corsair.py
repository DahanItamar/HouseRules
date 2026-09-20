"""Build the Corsair's Reach production art from the raw Higgsfield outputs.

    python tools/art/prepare_corsair.py

Raw outputs under assets/source/layered_v2/corsair/ are never modified.

Corsair's Reach is the crash cabinet (id `core_overclock`). A galleon runs before
a rising sea: the swell climbs, the multiplier climbs with it, and the round ends
when the ship is broken. The art is layered so the cabinet can drive each part on
its own clock:

* the ship is painted level and with no water on it at all, so the cabinet can
  pitch it to the slope of the swell and hang the wake off its stern;
* the wake is its own sprite, so spray can stretch and thin with speed without
  touching the hull;
* the wreck is one sheet of four stages, re-cut here into exact square cells;
* the crew are one frame per state with both women in it, so their reaction is
  shared by construction rather than by two sprites kept in step.

The script prints the geometry the cabinet needs -- the ship's bow and its stern
in texture fractions -- so the constants in
src/ui/core_overclock/core_overclock_theme.gd stay checkable.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/corsair"
OUT = ROOT / "assets/production/corsair"

WRECK_GRID = (2, 2)
WRECK_CELL = 512

## One frame per state of the run, both women in each, so they always feel the
## same thing at the same time.
## v2 is the approved pass: the brunette was re-dressed to match the blonde as
## crew of one ship, and both go bare-headed -- a tricorn cropped the top of her
## head at cabinet scale. The flamboyant captain version is kept in source as an
## unused alternative.
## v3 takes every rope, hilt and pole out of their hands. Anything a character
## holds that reaches past her own outline gets sliced off by the lane crop, and
## a rope cut dead at the frame edge is the first thing the eye finds.
CREW_STATES: list[tuple[str, str]] = [
    ("ready", "crew_v3_ready_ea6f81cb.png"),
    ("tense", "crew_v3_tense_033b6430.png"),
    ("cheer", "crew_v3_cheer_96cada4d.png"),
    ("wince", "crew_v3_wince_f2d4370c.png"),
]
CREW_CANVAS = (1920, 1080)


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


def _clean(image: Image.Image, erode: int = 1) -> Image.Image:
    pipeline = _pipeline()
    cleaned = pipeline.defringe(image.convert("RGBA"), erode)
    cleaned = pipeline.clean_alpha(cleaned)
    return pipeline._bleed(cleaned, np.zeros(1))


def _square(image: Image.Image, side: int, margin: int = 6) -> Image.Image:
    piece = _trim(image)
    scale = (side - margin * 2) / max(piece.size)
    piece = piece.resize(
        (max(1, round(piece.width * scale)), max(1, round(piece.height * scale))), Image.LANCZOS
    )
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(piece, ((side - piece.width) // 2, (side - piece.height) // 2))
    return square


def build_sea() -> None:
    """The night sea the swell is drawn over. Deliberately empty in the middle."""
    sea = Image.open(SOURCE / "sea_4k.png").convert("RGB")
    if sea.size != (3840, 2160):
        sea = sea.resize((3840, 2160), Image.LANCZOS)
    sea.save(OUT / "corsair_sea.png", optimize=True)
    print("corsair_sea.png", sea.size)


def build_ship() -> None:
    """The hull, with bow and stern measured so the cabinet can aim the wake."""
    ship = _square(_clean(Image.open(SOURCE / "ship_568a1063.png")), 768, 8)
    ship.save(OUT / "corsair_ship.png", optimize=True)
    alpha = np.asarray(ship.getchannel("A")) > 128
    ys, xs = np.nonzero(alpha)
    # She is painted level, bow to the right: the bow is the right-hand extreme
    # and the stern the left-hand one, both taken at the waterline.
    waterline = int(np.median(ys))
    band = np.abs(ys - waterline) < ship.height * 0.08
    bow_x = int(xs[band].max())
    stern_x = int(xs[band].min())
    print(
        "corsair_ship.png %s bow=(%.4f, %.4f) stern=(%.4f, %.4f)"
        % (
            ship.size,
            bow_x / ship.width,
            waterline / ship.height,
            stern_x / ship.width,
            waterline / ship.height,
        )
    )


def build_compass() -> None:
    """The multiplier dial: a brass compass with a blank cream face.

    Prints the blank face's centre and radius in texture fractions, which is
    what the cabinet needs to lay the number inside the case rather than over
    the bezel.
    """
    compass = _square(_clean(Image.open(SOURCE / "compass_13f114f4.png")), 1024, 8)
    compass.save(OUT / "corsair_compass.png", optimize=True)
    rgb = np.asarray(compass.convert("RGB"), dtype=np.int16)
    alpha = np.asarray(compass.getchannel("A")) > 128
    # The face is the large pale area inside the case; brass is far warmer.
    pale = alpha & (rgb.min(axis=2) > 120) & ((rgb[..., 0] - rgb[..., 2]) < 46)
    ys, xs = np.nonzero(pale)
    left, right = xs.min(), xs.max()
    top, bottom = ys.min(), ys.max()
    print(
        "corsair_compass.png %s face centre=(%.4f, %.4f) radius=%.4f"
        % (
            compass.size,
            (left + right) / 2 / compass.width,
            (top + bottom) / 2 / compass.height,
            (right - left) / 2 / compass.width,
        )
    )


def build_wake() -> None:
    thrust = _square(_clean(Image.open(SOURCE / "wake_45c672bf.png")), 512, 6)
    thrust.save(OUT / "corsair_wake.png", optimize=True)
    print("corsair_wake.png", thrust.size)


def build_foam() -> None:
    """The crest laid along the top of the swell, tiled horizontally."""
    foam = _clean(Image.open(SOURCE / "foam_79a94205.png"))
    foam = _trim(foam).resize((1024, 256), Image.LANCZOS)
    foam.save(OUT / "corsair_foam.png", optimize=True)
    print("corsair_foam.png", foam.size)


def build_parrot_flight() -> None:
    """Re-cuts the generated 2x2 flap cycle so every cell is exact.

    She is the object on the line, so her body must not shift between frames:
    each cell is trimmed and centred on the same square, and only the wings
    differ.
    """
    sheet = _clean(Image.open(SOURCE / "parrot_flight_f4cd7a4a.png"))
    out = Image.new("RGBA", (2 * 512, 2 * 512), (0, 0, 0, 0))
    step_x = sheet.width / 2
    step_y = sheet.height / 2
    for row in range(2):
        for column in range(2):
            cell = sheet.crop(
                (int(column * step_x), int(row * step_y),
                 int((column + 1) * step_x), int((row + 1) * step_y))
            )
            if np.asarray(cell.getchannel("A")).max() <= 16:
                continue
            out.paste(_square(cell, 512, 6), (column * 512, row * 512))
    out.save(OUT / "corsair_parrot_flight.png", optimize=True)
    print("corsair_parrot_flight.png %s 2x2 cells of 512" % (out.size,))


def build_trail() -> None:
    """The glowing beam laid along the climb, tiled end to end."""
    trail = _clean(Image.open(SOURCE / "trail_9dbed124.png"))
    trail = _trim(trail).resize((1024, 256), Image.LANCZOS)
    # The glow reaches the edge of its own bitmap, which leaves a lit corner when
    # the beam is tiled. Fade the top and bottom to nothing so it seams cleanly.
    alpha = np.asarray(trail.getchannel("A"), dtype=np.float32) / 255.0
    rows = np.linspace(-1.0, 1.0, trail.height, dtype=np.float32)
    feather = np.clip(1.0 - np.abs(rows) ** 6, 0.0, 1.0)[:, None]
    alpha = alpha * feather
    alpha[0, :] = 0.0
    alpha[-1, :] = 0.0
    trail.putalpha(Image.fromarray((alpha * 255.0).round().astype(np.uint8), "L"))
    trail.save(OUT / "corsair_trail.png", optimize=True)
    print("corsair_trail.png", trail.size)


def build_props() -> None:
    for name, source, side in [
        ("corsair_parrot.png", "parrot_023a0f22.png", 512),
        ("corsair_crest.png", "crest_2b1f476e.png", 512),
    ]:
        piece = _square(_clean(Image.open(SOURCE / source)), side)
        piece.save(OUT / name, optimize=True)
        print(name, piece.size)
    trim = _clean(Image.open(SOURCE / "deck_trim_317dbeed.png")).resize((1920, 1080), Image.LANCZOS)
    trim.save(OUT / "corsair_deck_trim.png", optimize=True)
    print("corsair_deck_trim.png", trim.size)


def build_frame() -> None:
    """The chart frame the crash is drawn inside, as a nine-slice.

    Boxing the graph is what the other cabinets do: the play area gets a painted
    edge and the room decorates up to it, so the game reads as a thing on the
    wall rather than a drawing floating on a photograph.
    """
    frame = _clean(Image.open(SOURCE / "crash_frame_592335ce.png"), 1)
    frame = frame.resize((1536, 864), Image.LANCZOS)
    frame.save(OUT / "corsair_frame.png", optimize=True)
    opaque = np.asarray(frame.getchannel("A")) > 128
    row = opaque[frame.height // 2]
    border = int(np.argmin(row)) if row.any() else 0
    print("corsair_frame.png %s border=%d px" % (frame.size, border))


def build_wreck() -> None:
    """Re-cuts the generated 2x2 break-up so every cell is trimmed and exact."""
    sheet = _clean(Image.open(SOURCE / "wreck_14c9dff1.png"))
    columns, rows = WRECK_GRID
    out = Image.new("RGBA", (columns * WRECK_CELL, rows * WRECK_CELL), (0, 0, 0, 0))
    step_x = sheet.width / columns
    step_y = sheet.height / rows
    for row in range(rows):
        for column in range(columns):
            cell = sheet.crop(
                (
                    int(column * step_x),
                    int(row * step_y),
                    int((column + 1) * step_x),
                    int((row + 1) * step_y),
                )
            )
            if np.asarray(cell.getchannel("A")).max() <= 16:
                continue
            out.paste(_square(cell, WRECK_CELL, 4), (column * WRECK_CELL, row * WRECK_CELL))
    out.save(OUT / "corsair_wreck.png", optimize=True)
    print("corsair_wreck.png %s %dx%d cells of %d" % (out.size, columns, rows, WRECK_CELL))


## Where each of them stands on the crew canvas, as fractions of it. These are
## the cabinet's two host lanes: narrow strips hard against the left and right
## edges, clear of the crash area between them and clear of the deck below.
CREW_LANES: dict[str, tuple[float, float, float]] = {
    # centre x, foot y, height -- all fractions of the 1920x1080 canvas
    "left": (0.152, 0.955, 0.62),
    "right": (0.856, 0.955, 0.62),
}


def build_crew() -> None:
    """Cuts each woman out of her shared frame and stands her in her own lane.

    The pair are generated as one frame per state so their reaction is shared by
    construction. Asking the generator to also place them in narrow edge lanes
    did not work -- it cropped them and drifted their costumes -- so the framing
    is done here instead, where it is exact and repeatable. Splitting the frame
    down the middle keeps the property that matters: both women in a state still
    come from a single picture, so they can never feel different things.
    """
    pipeline = _pipeline()
    for name, source in CREW_STATES:
        frame = _clean(Image.open(SOURCE / source), 1)
        canvas = Image.new("RGBA", CREW_CANVAS, (0, 0, 0, 0))
        middle = frame.width // 2
        halves = {"left": frame.crop((0, 0, middle, frame.height)),
                  "right": frame.crop((middle, 0, frame.width, frame.height))}
        for side, half in halves.items():
            if half.getbbox() is None:
                continue
            figure = _trim(half)
            centre_x, foot_y, height = CREW_LANES[side]
            tall = round(CREW_CANVAS[1] * height)
            wide = max(1, round(figure.width * tall / figure.height))
            figure = figure.resize((wide, tall), Image.LANCZOS)
            canvas.alpha_composite(
                figure,
                (round(CREW_CANVAS[0] * centre_x - wide / 2),
                 round(CREW_CANVAS[1] * foot_y) - tall),
            )
        canvas = pipeline._bleed(canvas, np.zeros(1))
        out = OUT / ("corsair_crew_%s.png" % name)
        canvas.save(out, optimize=True)
        alpha = np.asarray(canvas.getchannel("A")) > 128
        ys, xs = np.nonzero(alpha)
        clear = int((alpha[:, int(CREW_CANVAS[0] * 0.25):int(CREW_CANVAS[0] * 0.75)]).sum())
        print(
            "corsair_crew_%s.png %s used=Rect2(%d, %d, %d, %d) middle_px=%d"
            % (name, canvas.size, xs.min(), ys.min(),
               xs.max() - xs.min() + 1, ys.max() - ys.min() + 1, clear)
        )


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    build_sea()
    build_ship()
    build_compass()
    build_wake()
    build_foam()
    build_parrot_flight()
    build_trail()
    build_props()
    build_frame()
    build_wreck()
    build_crew()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
