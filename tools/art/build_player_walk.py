"""Build the player walk atlas from Higgsfield walk-cycle sheets.

python tools/art/build_player_walk.py

Each source sheet is a grid of frames on a flat grey background. Frames are
keyed out, scaled by one factor per sheet and placed so the sheet's lowest
foot lands on the atlas foot line (CELL centre + 110 px, inside the gutter) and its median
torso centre on the cell centre. Per-frame differences (bob, stride, sway) are
kept, sheet-level offsets are removed. West-facing columns are mirrors of the
east-facing ones. Output layout matches src/floor/character_walk_atlas.gd:
8 columns (N, NE, E, SE, S, SW, W, NW) by 4 leg phases, 240 px cells with a
9 px transparent gutter.
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/walk_v2"
OUTPUT = ROOT / "assets/production/characters/player_walk_v2.png"
CELL = 240
GUTTER = 9
FOOT_LINE = CELL // 2 + 110
TARGET_HEIGHT = 200
# column -> (sheet, grid columns, grid rows, two stride frames, gait)
# The generated sheets rarely move the legs between frames, so the cycle is
# synthesised from their strides: "depth" gaits (walking toward or away from
# the camera) swap the forward foot by mirroring the legs and level the feet
# for the passing beat; "lateral" gaits pull both feet in under the hips for
# the passing beat. Every beat therefore moves both legs.
SHEETS = {
    0: ("walk_north_1d559697.png", 4, 1, [0, 0], "depth"),
    1: ("walk_northeast_485daf1c.png", 4, 1, [1, 3], "lateral"),
    2: ("walk_east_919bbe86.png", 4, 2, [0, 3], "lateral"),
    3: ("walk_southeast_6fb1a3c6.png", 4, 1, [0, 2], "lateral"),
    4: ("walk_south_1fda4226.png", 4, 1, [0, 0], "depth"),
}
MIRRORS = {5: 3, 6: 2, 7: 1}
PASSING_SPREAD = 0.18
PASSING_LIFT = 0.012


def leg_start(rgba: np.ndarray) -> int:
    """First row below the jacket hem and the hanging hands."""
    rgb = rgba[..., :3].astype(int)
    solid = rgba[..., 3] > 128
    ivory = solid & (rgb[..., 0] > 170) & (rgb[..., 1] > 160) & (rgb[..., 2] > 130)
    skin = solid & (rgb[..., 0] > 150) & (rgb[..., 0] - rgb[..., 2] > 45) & ~ivory
    width = max(solid.sum(1).max(), 1)
    hem = max(i for i, n in enumerate(ivory.sum(1)) if n > width * 0.08)
    hands = [i for i, n in enumerate(skin.sum(1)) if n > 2 and i > hem - 80]
    return max(hem, max(hands) if hands else hem) + 4


def leg_axis(rgba: np.ndarray, start: int) -> float:
    xs = np.nonzero(rgba[start:start + 12, :, 3] > 128)[1]
    return float(xs.mean())


def mirror_legs(rgba: np.ndarray) -> np.ndarray:
    """Swap the forward foot by mirroring everything below the leg line."""
    out = rgba.copy()
    start = leg_start(rgba)
    axis = leg_axis(rgba, start)
    legs = rgba[start:]
    flipped = np.zeros_like(legs)
    width = rgba.shape[1]
    for x in range(width):
        source = round(2 * axis - x)
        if 0 <= source < width:
            flipped[:, x] = legs[:, source]
    out[start:] = flipped
    return out


def level_feet(rgba: np.ndarray) -> np.ndarray:
    """Passing beat for depth gaits: both feet end on the same row."""
    out = rgba.copy()
    start = leg_start(rgba)
    axis = round(leg_axis(rgba, start))
    halves = [(0, axis), (axis, rgba.shape[1])]
    bottoms = []
    for x0, x1 in halves:
        rows = np.nonzero((rgba[start:, x0:x1, 3] > 128).any(1))[0]
        bottoms.append(start + rows.max() if len(rows) else start)
    target = round(sum(bottoms) / 2)
    out[start:] = 0
    for (x0, x1), bottom in zip(halves, bottoms):
        length = max(bottom - start, 1)
        piece = Image.fromarray(rgba[start:bottom + 1, x0:x1])
        piece = piece.resize((x1 - x0, target - start + 1), Image.LANCZOS)
        region = out[start:target + 1, x0:x1]
        np.copyto(region, np.asarray(piece), where=np.asarray(piece)[..., 3:4] > region[..., 3:4])
    return out


def gather_feet(rgba: np.ndarray, spread: float) -> np.ndarray:
    """Passing beat for lateral gaits: pull both feet in under the hips."""
    # Each leg slides toward the hip axis without being squeezed, so the shoes
    # keep their shape; the slide grows from nothing at the hips to full at the
    # feet.
    start = leg_start(rgba)
    axis = leg_axis(rgba, start)
    solid = rgba[..., 3] > 128
    rows = np.nonzero(solid[start:].any(1))[0]
    bottom = start + rows.max()
    feet = solid[bottom - max((bottom - start) // 6, 1):bottom + 1]
    left = np.nonzero(feet[:, :round(axis)].any(0))[0]
    right = np.nonzero(feet[:, round(axis):].any(0))[0] + round(axis)
    left_gap = axis - left.mean() if len(left) else 0.0
    right_gap = right.mean() - axis if len(right) else 0.0
    out = rgba.copy()
    out[start:] = 0
    width = rgba.shape[1]
    for y in range(start, bottom + 1):
        t = (y - start) / max(bottom - start, 1)
        shift_left = round(left_gap * (1.0 - spread) * t)
        shift_right = round(right_gap * (1.0 - spread) * t)
        row = out[y]
        cut = round(axis)
        for x0, x1, shift in ((0, cut, shift_left), (cut, width, -shift_right)):
            piece = rgba[y, x0:x1]
            d0, d1 = x0 + shift, x1 + shift
            s0, s1 = max(0, -d0), (x1 - x0) - max(0, d1 - width)
            target = row[max(d0, 0):min(d1, width)]
            source = piece[s0:s1]
            np.copyto(target, source, where=source[..., 3:4] > target[..., 3:4])
    return out


def lift(rgba: np.ndarray, fraction: float) -> np.ndarray:
    solid = np.nonzero((rgba[..., 3] > 128).any(1))[0]
    shift = round((solid.max() - solid.min()) * fraction)
    out = np.zeros_like(rgba)
    out[:-shift or None] = rgba[shift:]
    return out


def cycle(frames: list[np.ndarray], gait: str) -> list[np.ndarray]:
    stride_a, stride_b = frames
    if gait == "depth":
        other = mirror_legs(stride_a)
        return [stride_a, lift(level_feet(stride_a), PASSING_LIFT),
                other, lift(level_feet(other), PASSING_LIFT)]
    return [stride_a, lift(gather_feet(stride_a, PASSING_SPREAD), PASSING_LIFT),
            stride_b, lift(gather_feet(stride_b, PASSING_SPREAD), PASSING_LIFT)]


def key_out(cell: np.ndarray) -> np.ndarray:
    """RGBA with the flat grey background removed and grey fringe unmixed."""
    rgb = cell[..., :3].astype(np.float32)
    border = np.concatenate([rgb[:6].reshape(-1, 3), rgb[-6:].reshape(-1, 3),
                             rgb[:, :6].reshape(-1, 3), rgb[:, -6:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    distance = np.sqrt(((rgb - bg) ** 2).sum(-1))
    alpha = np.clip((distance - 10.0) / 30.0, 0.0, 1.0)
    # Unmix the grey from partially transparent edge pixels.
    safe = np.maximum(alpha, 1e-3)[..., None]
    colour = np.clip((rgb - bg * (1.0 - alpha[..., None])) / safe, 0, 255)
    out = np.dstack([colour, alpha * 255.0]).astype(np.uint8)
    out[alpha < 0.04] = 0
    return out


def largest_figure(rgba: np.ndarray) -> np.ndarray:
    """Zero everything outside the bounding box of the main figure."""
    solid = rgba[..., 3] > 128
    ys, xs = np.nonzero(solid)
    keep = np.zeros_like(solid)
    keep[ys.min():ys.max() + 1, xs.min():xs.max() + 1] = True
    rgba[~keep] = 0
    return rgba


def frames_for(sheet: str, cols: int, rows: int, order: list[int]) -> list[np.ndarray]:
    image = np.asarray(Image.open(SOURCE / sheet).convert("RGBA"))
    height, width = image.shape[:2]
    cw, ch = width // cols, height // rows
    frames = []
    for index in order:
        gx, gy = index % cols, index // cols
        cell = image[gy * ch:(gy + 1) * ch, gx * cw:(gx + 1) * cw]
        frames.append(largest_figure(key_out(cell)))
    return frames


def place(frames: list[np.ndarray]) -> list[Image.Image]:
    stats = []
    for rgba in frames:
        solid = rgba[..., 3] > 128
        ys, xs = np.nonzero(solid)
        top, bottom = ys.min(), ys.max()
        torso = solid[top:top + int((bottom - top) * 0.45)]
        tx = np.nonzero(torso)[1].mean()
        stats.append((top, bottom, tx))
    scale = TARGET_HEIGHT / max(b - t for t, b, _ in stats)
    ground = float(max(b for _, b, _ in stats))
    centre = float(np.median([x for _, _, x in stats]))
    cells = []
    for rgba in frames:
        img = Image.fromarray(rgba)
        img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
        cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        cell.alpha_composite(img, (round(CELL / 2 - centre * scale), round(FOOT_LINE - ground * scale)))
        # Enforce the transparent gutter.
        arr = np.asarray(cell).copy()
        arr[:GUTTER] = 0
        arr[-GUTTER:] = 0
        arr[:, :GUTTER] = 0
        arr[:, -GUTTER:] = 0
        cells.append(Image.fromarray(arr))
    return cells


def main() -> None:
    atlas = Image.new("RGBA", (CELL * 8, CELL * 4), (0, 0, 0, 0))
    columns: dict[int, list[Image.Image]] = {}
    for column, (sheet, cols, rows, order, gait) in SHEETS.items():
        columns[column] = place(cycle(frames_for(sheet, cols, rows, order), gait))
    for column, source in MIRRORS.items():
        columns[column] = [c.transpose(Image.FLIP_LEFT_RIGHT) for c in columns[source]]
    for column, cells in columns.items():
        for phase, cell in enumerate(cells):
            atlas.alpha_composite(cell, (column * CELL, phase * CELL))
    atlas.save(OUTPUT)
    print("wrote", OUTPUT.relative_to(ROOT), atlas.size)


if __name__ == "__main__":
    main()
