"""Build the player's painted upper-body atlas for the procedural leg rig.

PARKED: the procedural leg rig was rejected and does not ship; its outputs live
in tools/prototypes/procedural_legs/ (excluded from export).

python tools/art/build_player_torso.py

The legs were drawn procedurally (tools/prototypes/procedural_legs/avatar_legs.gd)
because image generators cannot hold a consistent gait. This tool keeps the
painted Higgsfield upper body: it runs the same key-out and placement as
build_player_walk.py, picks one clean upright frame per direction (a passing
frame, where the arms hang closest to the body) and cuts it at the jacket hem.
Everything that belongs to the trousers and shoes is removed, including the
trouser patch visible in the open front of the jacket; the hands and cuffs that
hang below the hem stay.

Outputs:
- tools/prototypes/procedural_legs/player_torso_v2.png: 8 columns (N, NE, E, SE, S,
  SW, W, NW) x 1 row of 240 px cells with a 9 px transparent gutter, at the same
  scale and foot line (cell centre + 110 px) as player_walk_v2.png. West-facing
  columns are mirrors of the east-facing ones.
- tools/prototypes/procedural_legs/player_torso_v2.json: per-direction hem line
  and left/right hip pivots in cell pixels (copied into the prototype's HIPS).
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

import build_player_walk as walk

ROOT = walk.ROOT
OUTPUT = ROOT / "tools/prototypes/procedural_legs/player_torso_v2.png"
DATA = ROOT / "tools/prototypes/procedural_legs/player_torso_v2.json"
CELL = walk.CELL
GUTTER = walk.GUTTER
FOOT_LINE = walk.FOOT_LINE
# Frame index per authored column inside build_player_walk's four-beat cycle;
# 1 is the first passing beat.
TORSO_FRAME = {0: 1, 1: 1, 2: 1, 3: 1, 4: 1}
# Hip joints sit this far above the highest jacket hem, so the leg (hip to sole)
# is about 53 % of the 200 px figure and the thigh tops stay under the jacket.
HIP_ABOVE_HEM = 10
# Half the distance between the hip joints in world pixels, and the ground
# depth compression of the top-down 3/4 camera. Lateral hip offsets are
# projected as (l.x, l.y * DEPTH) * HIP_HALF_WIDTH.
HIP_HALF_WIDTH = 10.0
DEPTH = 0.55


def hem_row(rgba: np.ndarray) -> int:
    rgb = rgba[..., :3].astype(int)
    solid = rgba[..., 3] > 128
    ivory = solid & (rgb[..., 0] > 170) & (rgb[..., 1] > 160) & (rgb[..., 2] > 130)
    width = max(solid.sum(1).max(), 1)
    return max(i for i, n in enumerate(ivory.sum(1)) if n > width * 0.08)


def cut_torso(rgba: np.ndarray) -> tuple[np.ndarray, int]:
    """Remove trousers and shoes; keep head, jacket, sleeves, hands."""
    hem = hem_row(rgba)
    rgb = rgba[..., :3].astype(int)
    alpha = rgba[..., 3]
    luminance = rgb.max(-1)
    dark = (alpha > 0) & (luminance < 78)
    # Only consider the leg zone: the jacket's front opening can show trousers
    # a little above the hem, the bow tie is far above it.
    zone_top = hem - 22
    dark[:zone_top] = False
    count, labels = cv2.connectedComponents(dark.astype(np.uint8), connectivity=8)
    trousers = np.zeros_like(dark)
    for label in range(1, count):
        component = labels == label
        if component[hem + 6:].any():
            trousers |= component
    # Grow by one pixel so the dark anti-aliased rim of the trousers goes too,
    # but never into clearly light jacket or skin pixels.
    grown = cv2.dilate(trousers.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    trousers |= grown & (luminance < 120) & (np.arange(CELL)[:, None] > hem - 2)
    out = rgba.copy()
    out[trousers] = 0
    # Keep only what is attached to the upper body (hands hang off the cuffs).
    solid = out[..., 3] > 24
    count, labels = cv2.connectedComponents(solid.astype(np.uint8), connectivity=8)
    ys, xs = np.nonzero(solid)
    head_label = labels[ys.min(), xs[ys == ys.min()][0]]
    keep = labels == head_label
    keep = cv2.dilate(keep.astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
    out[~keep] = 0
    return out, hem


def trouser_centre(rgba: np.ndarray, hem: int) -> float:
    rgb = rgba[..., :3].astype(int)
    dark = (rgba[..., 3] > 128) & (rgb.max(-1) < 78)
    band = dark[hem + 2:hem + 12]
    xs = np.nonzero(band)[1]
    return float(xs.mean())


def lateral(direction: int) -> tuple[float, float]:
    """Screen projection of the walker's right-hand hip offset."""
    angle = direction * math.pi / 4.0  # clockwise from north
    facing = (math.sin(angle), -math.cos(angle))
    right = (-facing[1], facing[0])
    return right[0] * HIP_HALF_WIDTH, right[1] * DEPTH * HIP_HALF_WIDTH


def gutter(cell: np.ndarray) -> np.ndarray:
    cell = cell.copy()
    cell[:GUTTER] = 0
    cell[-GUTTER:] = 0
    cell[:, :GUTTER] = 0
    cell[:, -GUTTER:] = 0
    return cell


def main() -> None:
    torsos: dict[int, np.ndarray] = {}
    hems: dict[int, int] = {}
    centres: dict[int, float] = {}
    for column, (sheet, cols, rows, order, gait) in walk.SHEETS.items():
        cells = walk.place(walk.cycle(walk.frames_for(sheet, cols, rows, order), gait))
        full = np.asarray(cells[TORSO_FRAME[column]]).copy()
        torso, hem = cut_torso(full)
        torsos[column] = gutter(torso)
        hems[column] = hem
        centres[column] = trouser_centre(full, hem)
    for column, source in walk.MIRRORS.items():
        torsos[column] = torsos[source][:, ::-1].copy()
        hems[column] = hems[source]
        centres[column] = CELL - centres[source]
    hip_y = min(hems.values()) - HIP_ABOVE_HEM
    atlas = Image.new("RGBA", (CELL * 8, CELL), (0, 0, 0, 0))
    directions = []
    for column in range(8):
        atlas.alpha_composite(Image.fromarray(torsos[column]), (column * CELL, 0))
        dx, dy = lateral(column)
        centre = round(centres[column], 1)
        directions.append(
            {
                "column": column,
                "hem": hems[column],
                "hip_left": [round(centre - dx, 2), round(hip_y - dy, 2)],
                "hip_right": [round(centre + dx, 2), round(hip_y + dy, 2)],
            }
        )
    atlas.save(OUTPUT)
    DATA.write_text(
        json.dumps(
            {
                "cell": CELL,
                "foot_line": FOOT_LINE,
                "hip_half_width": HIP_HALF_WIDTH,
                "depth": DEPTH,
                "torso_frames": TORSO_FRAME,
                "directions": directions,
            },
            indent=2,
        )
        + "\n"
    )
    print("wrote", OUTPUT.relative_to(ROOT), atlas.size)
    print("wrote", DATA.relative_to(ROOT))
    for entry in directions:
        print(entry)


if __name__ == "__main__":
    main()
