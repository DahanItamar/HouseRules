"""Build the progression and stats UI kit from the Higgsfield masters.

python tools/art/prepare_progression.py

Sources are the raw gpt_image_2_5 outputs (transparent) in
assets/source/layered_v2/progression/. They are never modified.

* Nine-slice pieces (bar track, bar fill, stats panel): any partial
  transparency inside the silhouette is composited over the flat centre
  colour sampled just inside the rim, so nothing stretches but solid paint.
  The bars additionally have every column between their end caps replaced by
  the median column, which makes a horizontal stretch exact; the fill keeps
  its vertical brushed sheen, because that axis is never stretched.
* The medallion row and the 4x2 icon sheet are split on their alpha gaps,
  trimmed and centred on one square canvas each, so every rank and every stat
  icon draws at the same size.
* The deed keeps its painted aspect and is only trimmed and scaled.

Writes assets/production/ui/progression/*.png + progression.json and a contact
sheet at tests/results/screenshots/ui_assets/progression_sheet.png.
"""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/progression"
OUT = ROOT / "assets/production/ui/progression"
SHEET = ROOT / "tests/results/screenshots/ui_assets/progression_sheet.png"

MEDALLION_CANVAS = 256
ICON_CANVAS = 128
DEED_LONG_SIDE = 1024
PAD = 6
FACE_TOL = 26.0

SOURCES = {
    "bar_track": "bar_track_b2d793e1.png",
    "bar_fill": "bar_fill_86e1fde1.png",
    "stats_panel": "stats_panel_2c0382a9.png",
    "rank_medallions": "rank_medallions_494570ad.png",
    "stat_icons": "stat_icons_029a8af5.png",
    "deed_keys": "deed_keys_f92a6f07.png",
}
# The five painted medallions, left to right.
MEDALLION_NAMES = ["rank_guest", "rank_regular", "rank_high_roller", "rank_whale", "rank_owner"]
# The 4x2 sheet, reading order.
ICON_NAMES = [
    "icon_chips",
    "icon_coin",
    "icon_up",
    "icon_down",
    "icon_clock",
    "icon_cabinet",
    "icon_laurel",
    "icon_flame",
]
# The sixth rank has no painted medallion: Partner reuses the Owner key,
# tinted to aged bronze so the pure gold key stays the last rung's alone.
PARTNER_TINT = (0.74, 0.62, 0.52)


def read(path: Path) -> np.ndarray:
    image = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
    if image is None:
        raise SystemExit("Missing source: %s" % path)
    if image.shape[2] == 3:
        image = np.dstack([image, np.full(image.shape[:2], 255, np.uint8)])
    return np.dstack([image[..., 2], image[..., 1], image[..., 0], image[..., 3]]).astype(
        np.float32
    )


def write(rgba: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    out = np.clip(rgba, 0, 255).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(path)


def silhouette(alpha: np.ndarray, threshold: int = 110) -> np.ndarray:
    """Largest solid component with its holes filled."""
    solid = (alpha >= threshold).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(solid, 8)
    if count <= 1:
        return solid.astype(bool)
    biggest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    main = (labels == biggest).astype(np.uint8)
    padded = np.pad(main, 1)
    flood = padded.copy()
    mask = np.zeros((padded.shape[0] + 2, padded.shape[1] + 2), np.uint8)
    cv2.floodFill(flood, mask, (0, 0), 1)
    holes = (flood == 0)[1:-1, 1:-1]
    return main.astype(bool) | holes


def solid_mask(alpha: np.ndarray, threshold: int = 150) -> np.ndarray:
    """Every solidly painted region, holes filled, soft shadow left out."""
    solid = (alpha >= threshold).astype(np.uint8)
    solid = cv2.morphologyEx(solid, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    padded = np.pad(solid, 1)
    flood = padded.copy()
    mask = np.zeros((padded.shape[0] + 2, padded.shape[1] + 2), np.uint8)
    cv2.floodFill(flood, mask, (0, 0), 1)
    return solid.astype(bool) | (flood == 0)[1:-1, 1:-1]


def clean_alpha(rgba: np.ndarray, sil: np.ndarray) -> np.ndarray:
    """Cut everything outside the silhouette with a 2 px feather (halo removal)."""
    out = rgba.copy()
    dist = cv2.distanceTransform((~sil).astype(np.uint8), cv2.DIST_L2, 5)
    out[..., 3] *= np.clip(1.0 - dist / 2.0, 0.0, 1.0)
    alpha = out[..., 3]
    alpha[alpha >= 248] = 255
    alpha[alpha < 4] = 0
    out[alpha == 0, :3] = 0
    return out


def trim(rgba: np.ndarray) -> np.ndarray:
    ys, xs = np.nonzero(rgba[..., 3] > 0)
    return rgba[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1].copy()


def resize(rgba: np.ndarray, width: int, height: int) -> np.ndarray:
    """Premultiplied Lanczos resize, so no dark fringe bleeds into the edge."""
    premul = rgba.copy()
    premul[..., :3] *= premul[..., 3:4] / 255.0
    channels = [
        np.asarray(
            Image.fromarray(premul[..., c].astype(np.float32), "F").resize(
                (width, height), Image.LANCZOS
            )
        )
        for c in range(4)
    ]
    out = np.clip(np.dstack(channels), 0, 255)
    safe = np.maximum(out[..., 3:4], 1e-3) / 255.0
    out[..., :3] = np.where(out[..., 3:4] > 0, np.clip(out[..., :3] / safe, 0, 255), 0)
    out[..., 3][out[..., 3] >= 248] = 255
    out[..., 3][out[..., 3] < 4] = 0
    return out


def square(rgba: np.ndarray, canvas: int) -> np.ndarray:
    # The painted pieces carry a soft drop shadow well outside the metal. Trim
    # on the solid paint instead, or one medallion's halo would shrink it
    # against the others. Every solid part is kept, not just the largest: a
    # flame is three separate strands and a laurel is two halves and a knot.
    crop = trim(clean_alpha(rgba, solid_mask(rgba[..., 3])))
    inner = canvas - 2 * PAD
    scale = inner / max(crop.shape[:2])
    width = max(1, round(crop.shape[1] * scale))
    height = max(1, round(crop.shape[0] * scale))
    scaled = resize(crop, width, height)
    out = np.zeros((canvas, canvas, 4), np.float32)
    x0, y0 = (canvas - width) // 2, (canvas - height) // 2
    out[y0 : y0 + height, x0 : x0 + width] = scaled
    return out


def centre_colour(rgba: np.ndarray, sil: np.ndarray) -> np.ndarray:
    """The flat paint at the middle of the piece, away from every rim."""
    h, w = sil.shape
    band = rgba[h * 2 // 5 : h * 3 // 5, w * 2 // 5 : w * 3 // 5, :3]
    return np.median(band.reshape(-1, 3), axis=0)


def fill_leaks(rgba: np.ndarray, sil: np.ndarray, face: np.ndarray) -> np.ndarray:
    """Composite partial transparency inside the silhouette over the flat paint."""
    interior = cv2.erode(sil.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    a = rgba[..., 3:4] / 255.0
    mixed = rgba[..., :3] * a + face * (1.0 - a)
    rgba[interior, :3] = mixed[interior]
    rgba[interior, 3] = 255
    return rgba


def flat_centre(rgba: np.ndarray, sil: np.ndarray, face: np.ndarray) -> np.ndarray:
    """Paint every pixel already within tolerance of the flat centre exactly that
    colour, so a stretched middle patch is one solid, bandless surface."""
    close = np.sqrt(((rgba[..., :3] - face) ** 2).sum(-1)) < FACE_TOL
    interior = cv2.erode(sil.astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool)
    rgba[close & interior, :3] = face
    return rgba


def cap_width(sil: np.ndarray) -> int:
    """How far in from each end the capsule takes to reach its full height: the
    painted end cap, and therefore the only part a horizontal stretch must keep."""
    heights = sil.sum(0)
    full = heights.max()
    solid = heights >= full * 0.995
    left = int(np.argmax(solid))
    right = int(np.argmax(solid[::-1]))
    return max(left, right) + 3


def rim_height(sil: np.ndarray, rgba: np.ndarray, face: np.ndarray) -> int:
    """Thickness of the brass rim on the middle column."""
    column = rgba[:, sil.shape[1] // 2, :3]
    solid = np.nonzero(sil[:, sil.shape[1] // 2])[0]
    close = np.sqrt(((column - face) ** 2).sum(-1)) < FACE_TOL
    top = solid.min()
    while top < solid.max() and not close[top]:
        top += 1
    return int(top - solid.min()) + 3


def channel_inset(rgba: np.ndarray, face: np.ndarray) -> dict:
    """The flat channel's distance from each edge, in source pixels."""
    h, w, _ = rgba.shape
    flat = (np.sqrt(((rgba[..., :3] - face) ** 2).sum(-1)) < FACE_TOL) & (rgba[..., 3] > 200)
    rows = np.nonzero(flat[:, w // 2])[0]
    columns = np.nonzero(flat[h // 2])[0]
    return {
        "left": int(columns.min()),
        "right": int(w - 1 - columns.max()),
        "top": int(rows.min()),
        "bottom": int(h - 1 - rows.max()),
    }


def collapse_band(rgba: np.ndarray, cap: int) -> np.ndarray:
    """Make every column between the caps identical: an exact horizontal stretch."""
    band = rgba[:, cap : rgba.shape[1] - cap]
    rgba[:, cap : rgba.shape[1] - cap] = np.median(band, axis=1, keepdims=True)
    return rgba


def frame_margin(rgba: np.ndarray, sil: np.ndarray, face: np.ndarray) -> int:
    """Smallest nine-patch margin whose corner patches hold every ornament.

    Measured on the brass: a corner fan's rays have centre-coloured gaps
    between them, so the flat mask alone cannot bound them.
    """
    h, w = sil.shape
    ornament = sil & (np.sqrt(((rgba[..., :3] - face) ** 2).sum(-1)) > FACE_TOL * 1.5)
    opened = cv2.morphologyEx(
        ornament.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)
    ).astype(bool)
    limit = (min(h, w) - 8) // 2
    for margin in range(4, limit):
        if not opened[margin : h - margin, margin : w - margin].any():
            return margin + 3
    return limit


def hex_colour(face: np.ndarray) -> str:
    return "#%02x%02x%02x" % tuple(int(round(c)) for c in face[:3])


def split_runs(mask: np.ndarray, minimum: int) -> list[tuple[int, int]]:
    """Start/end index of every run of True at least `minimum` long."""
    runs: list[tuple[int, int]] = []
    start = None
    for index, value in enumerate(mask):
        if value and start is None:
            start = index
        elif not value and start is not None:
            if index - start >= minimum:
                runs.append((start, index))
            start = None
    if start is not None and len(mask) - start >= minimum:
        runs.append((start, len(mask)))
    return runs


def build_bar(name: str, manifest: dict) -> np.ndarray:
    rgba = read(SOURCE / SOURCES[name])
    sil = silhouette(rgba[..., 3])
    rgba = clean_alpha(rgba, sil)
    rgba = trim(rgba)
    sil = silhouette(rgba[..., 3])
    face = centre_colour(rgba, sil)
    rgba = fill_leaks(rgba, sil, face)
    if name == "bar_track":
        # Only the track has a flat near-black centre worth levelling; the fill
        # is all brushed brass and must keep its sheen.
        rgba = flat_centre(rgba, sil, face)
    cap = cap_width(sil)
    rgba = collapse_band(rgba, cap)
    vertical = rim_height(sil, rgba, face) if name == "bar_track" else 0
    manifest[name] = {
        "path": "res://assets/production/ui/progression/%s.png" % name,
        "kind": "nine_slice",
        "patch_margin": {
            "left": cap,
            "right": cap,
            "top": vertical,
            "bottom": vertical,
        },
        "centre_colour": hex_colour(face),
        "size": [int(rgba.shape[1]), int(rgba.shape[0])],
    }
    if name == "bar_track":
        # Where the flat channel actually starts inside the brass rim, so the
        # fill can be inset exactly instead of by a guessed margin.
        manifest[name]["channel_inset"] = channel_inset(rgba, face)
    write(rgba, OUT / ("%s.png" % name))
    return rgba


def build_panel(manifest: dict) -> np.ndarray:
    rgba = read(SOURCE / SOURCES["stats_panel"])
    sil = silhouette(rgba[..., 3])
    rgba = clean_alpha(rgba, sil)
    rgba = trim(rgba)
    sil = silhouette(rgba[..., 3])
    face = centre_colour(rgba, sil)
    rgba = fill_leaks(rgba, sil, face)
    rgba = flat_centre(rgba, sil, face)
    margin = frame_margin(rgba, sil, face)
    manifest["stats_panel"] = {
        "path": "res://assets/production/ui/progression/stats_panel.png",
        "kind": "nine_slice",
        "patch_margin": {"left": margin, "right": margin, "top": margin, "bottom": margin},
        "centre_colour": hex_colour(face),
        "size": [int(rgba.shape[1]), int(rgba.shape[0])],
    }
    write(rgba, OUT / "stats_panel.png")
    return rgba


def build_row(source: str, names: list[str], canvas: int, rows: int, manifest: dict) -> list:
    rgba = read(SOURCE / SOURCES[source])
    alpha = rgba[..., 3]
    solid = alpha > 40
    pieces: list[np.ndarray] = []
    row_runs = split_runs(solid.any(1), canvas // 8) if rows > 1 else [(0, rgba.shape[0])]
    if len(row_runs) != rows:
        raise SystemExit("%s: found %d rows, expected %d" % (source, len(row_runs), rows))
    for y0, y1 in row_runs:
        strip = rgba[y0:y1]
        columns = split_runs((strip[..., 3] > 40).any(0), canvas // 8)
        for x0, x1 in columns:
            pieces.append(strip[:, x0:x1])
    if len(pieces) != len(names):
        raise SystemExit("%s: found %d pieces, expected %d" % (source, len(pieces), len(names)))
    written = []
    for name, piece in zip(names, pieces):
        art = square(piece, canvas)
        write(art, OUT / ("%s.png" % name))
        manifest[name] = {
            "path": "res://assets/production/ui/progression/%s.png" % name,
            "kind": "icon",
            "size": [canvas, canvas],
        }
        written.append(art)
    return written


def build_partner(owner: np.ndarray, manifest: dict) -> np.ndarray:
    """The sixth rank: the Owner key in aged bronze, so gold stays the last rung."""
    art = owner.copy()
    for channel, factor in enumerate(PARTNER_TINT):
        art[..., channel] = np.clip(art[..., channel] * factor, 0, 255)
    write(art, OUT / "rank_partner.png")
    manifest["rank_partner"] = {
        "path": "res://assets/production/ui/progression/rank_partner.png",
        "kind": "icon",
        "size": [MEDALLION_CANVAS, MEDALLION_CANVAS],
        "derived_from": "rank_owner",
        "note": "Five medallions were painted for six ranks: Partner is the Owner key "
        "tinted to aged bronze so the pure gold key belongs to Owner alone.",
    }
    return art


def build_deed(manifest: dict) -> np.ndarray:
    rgba = read(SOURCE / SOURCES["deed_keys"])
    sil = silhouette(rgba[..., 3])
    rgba = trim(clean_alpha(rgba, sil))
    scale = DEED_LONG_SIDE / max(rgba.shape[:2])
    art = resize(rgba, max(1, round(rgba.shape[1] * scale)), max(1, round(rgba.shape[0] * scale)))
    write(art, OUT / "deed_keys.png")
    manifest["deed_keys"] = {
        "path": "res://assets/production/ui/progression/deed_keys.png",
        "kind": "art",
        "size": [int(art.shape[1]), int(art.shape[0])],
        "note": "The parchment is deliberately blank; the deed's wording is drawn in code.",
    }
    return art


def contact_sheet(tiles: list[np.ndarray]) -> None:
    cell = 160
    columns = 8
    rows = (len(tiles) + columns - 1) // columns
    sheet = np.zeros((rows * cell, columns * cell, 4), np.float32)
    sheet[..., :3] = 24.0
    sheet[..., 3] = 255.0
    for index, tile in enumerate(tiles):
        scale = (cell - 8) / max(tile.shape[:2])
        width = max(1, round(tile.shape[1] * scale))
        height = max(1, round(tile.shape[0] * scale))
        small = resize(tile, width, height)
        y0 = (index // columns) * cell + (cell - height) // 2
        x0 = (index % columns) * cell + (cell - width) // 2
        a = small[..., 3:4] / 255.0
        patch = sheet[y0 : y0 + height, x0 : x0 + width]
        patch[..., :3] = small[..., :3] * a + patch[..., :3] * (1.0 - a)
    write(sheet, SHEET)


def main() -> None:
    manifest: dict = {}
    tiles: list[np.ndarray] = []
    tiles.append(build_bar("bar_track", manifest))
    tiles.append(build_bar("bar_fill", manifest))
    tiles.append(build_panel(manifest))
    medallions = build_row("rank_medallions", MEDALLION_NAMES, MEDALLION_CANVAS, 1, manifest)
    tiles.extend(medallions)
    tiles.append(build_partner(medallions[-1], manifest))
    tiles.extend(build_row("stat_icons", ICON_NAMES, ICON_CANVAS, 2, manifest))
    tiles.append(build_deed(manifest))
    document = {
        "about": (
            "Progression and stats UI (Higgsfield gpt_image_2_5, transparent). Nine-slice "
            "pieces list a four-side patch margin in source pixels and the flat centre "
            "colour behind them. Icons and medallions are trimmed and centred on one "
            "square canvas each. Import with mipmaps."
        ),
        "jobs": {
            "bar_track": "b2d793e1-c398-4c34-b73f-0e79876c8e74",
            "bar_fill": "86e1fde1-d1a4-41d0-a537-4ea081f5ff3d",
            "stats_panel": "2c0382a9-8ad7-4e78-ab2e-5a87b4f7d3a1",
            "rank_medallions": "494570ad-98ef-417a-9142-ae90308d2649",
            "deed_keys": "f92a6f07-142a-4c32-be38-120bfa767386",
            "stat_icons": "029a8af5-834c-4c74-8935-f6f3e8b0576a",
        },
        "pieces": dict(sorted(manifest.items())),
    }
    (OUT / "progression.json").write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    contact_sheet(tiles)
    for name in sorted(manifest):
        entry = manifest[name]
        print("%-18s %-10s %s" % (name, entry["kind"], entry["size"]))
    print("manifest ->", OUT / "progression.json")
    print("sheet    ->", SHEET)


if __name__ == "__main__":
    main()
