"""Build and verify the layered floor art from one authored room layout.

Every floor room is described once, in virtual 960x540 coordinates, by
``data/floors/<room>.json``. Godot reads the same file at runtime, so the solid
polygons, the depth-sorted occluder pieces and the interaction anchors used in
game are exactly the ones rendered by this tool.

Commands (run from the repository root with a Python that has Pillow + numpy):

    python tools/art/floor_layers.py build   data/floors/main_floor.json
    python tools/art/floor_layers.py overlay data/floors/main_floor.json OUT.png
    python tools/art/floor_layers.py grid    data/floors/main_floor.json OUT_DIR
    python tools/art/floor_layers.py check   data/floors/main_floor.json

``build`` writes the transparent foreground (only real object fronts, cut from
the approved background with anti-aliased alpha), the collision reference mask
and the composite preview named in the layout. ``overlay`` and ``grid`` are
review aids. ``check`` validates the layout: polygon sanity, anchor
walkability and one continuous walkable route to every destination.
"""

from __future__ import annotations

import json
import math
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
VIRTUAL = (960, 540)
SUPERSAMPLE = 4


def res_path(path: str) -> Path:
    """Map a ``res://`` path to the repository filesystem."""
    return ROOT / path.removeprefix("res://")


def load_layout(path: str | Path) -> dict:
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def points(entry: dict) -> list[tuple[float, float]]:
    return [(float(x), float(y)) for x, y in entry["points"]]


def polygon_mask(size: tuple[int, int], polygons: list[list[tuple[float, float]]],
                 scale: float) -> np.ndarray:
    """Anti-aliased coverage in [0, 1] for virtual-space polygons."""
    width, height = size
    big = Image.new("L", (width * SUPERSAMPLE, height * SUPERSAMPLE), 0)
    draw = ImageDraw.Draw(big)
    factor = scale * SUPERSAMPLE
    for polygon in polygons:
        draw.polygon([(x * factor, y * factor) for x, y in polygon], fill=255)
    small = big.resize((width, height), Image.BOX)
    return np.asarray(small, dtype=np.float32) / 255.0


def refine_alpha(rgb: np.ndarray, coverage: np.ndarray, mode: str) -> np.ndarray:
    """Optional colour refinement inside a traced polygon.

    ``foliage`` keeps leaves and pots but drops carpet showing between fronds;
    everything else keeps the traced polygon coverage unchanged.
    """
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    if mode == "bright":
        # Ropes and brass posts are far brighter than the dark carpet under them.
        keep = np.clip((np.maximum(r, g) - 0.40) / 0.12, 0.0, 1.0)
        keep_image = Image.fromarray((keep * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
        return coverage * np.asarray(keep_image, dtype=np.float32) / 255.0
    if mode != "foliage":
        return coverage
    leafy = np.clip((g - r * 0.72) / 0.10, 0.0, 1.0)
    brass = np.clip(((r + g) * 0.5 - b - 0.10) / 0.12, 0.0, 1.0) * (g > 0.28)
    keep = np.maximum(leafy, brass)
    keep_image = Image.fromarray((keep * 255).astype(np.uint8))
    keep_image = keep_image.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.2))
    keep = np.asarray(keep_image, dtype=np.float32) / 255.0
    return coverage * np.clip(keep * 1.4, 0.0, 1.0)


def build_foreground(layout: dict) -> Image.Image:
    background = Image.open(res_path(layout["background"])).convert("RGB")
    scale = background.width / VIRTUAL[0]
    rgb = np.asarray(background, dtype=np.float32) / 255.0
    alpha = np.zeros((background.height, background.width), dtype=np.float32)
    for occluder in layout["occluders"]:
        coverage = polygon_mask(background.size, [points(occluder)], scale)
        coverage = refine_alpha(rgb, coverage, occluder.get("refine", "none"))
        alpha = np.maximum(alpha, coverage)
    out = np.dstack([rgb, alpha])
    # Fully transparent texels carry no colour so filtering can never pull a
    # matte into an object edge.
    out[alpha <= 0.0, :3] = 0.0
    return Image.fromarray((np.clip(out, 0.0, 1.0) * 255.0 + 0.5).astype(np.uint8), "RGBA")


def build_collision(layout: dict, size: tuple[int, int]) -> Image.Image:
    """White is walkable carpet, black is solid or outside the walk bounds."""
    scale = size[0] / VIRTUAL[0]
    walk = polygon_mask(size, [[(float(x), float(y)) for x, y in layout["walk_bounds"]]], scale)
    solid = polygon_mask(size, [points(entry) for entry in layout["solids"]], scale)
    walkable = np.clip(walk - solid, 0.0, 1.0)
    return Image.fromarray((walkable * 255.0 + 0.5).astype(np.uint8), "L")


def build_preview(layout: dict, foreground: Image.Image) -> Image.Image:
    """Background with the foreground layer on top, as the player sees the room."""
    background = Image.open(res_path(layout["background"])).convert("RGBA")
    return Image.alpha_composite(background, foreground).convert("RGB")


def render_overlay(layout: dict, out: str, scale: float = 2.0) -> None:
    background = Image.open(res_path(layout["background"])).convert("RGBA")
    base = background.resize((round(VIRTUAL[0] * scale), round(VIRTUAL[1] * scale)),
                             Image.LANCZOS)
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    def sp(point: tuple[float, float]) -> tuple[float, float]:
        return (point[0] * scale, point[1] * scale)

    draw.line([sp(p) for p in layout["walk_bounds"]] + [sp(layout["walk_bounds"][0])],
              fill=(80, 255, 120, 200), width=2)
    for entry in layout["solids"]:
        draw.polygon([sp(p) for p in points(entry)], fill=(255, 40, 60, 70),
                     outline=(255, 60, 80, 255))
    for entry in layout["occluders"]:
        poly = [sp(p) for p in points(entry)]
        draw.polygon(poly, outline=(60, 220, 255, 255))
        xs = [p[0] for p in poly]
        base_y = float(entry["baseline"]) * scale
        draw.line([(min(xs), base_y), (max(xs), base_y)], fill=(255, 230, 60, 230), width=1)
    for name, anchor in layout.get("anchors", {}).items():
        x, y = sp(anchor)
        draw.ellipse([x - 5, y - 5, x + 5, y + 5], outline=(255, 255, 255, 255), width=2)
        draw.text((x + 7, y - 7), name, fill=(255, 255, 255, 255))
    Image.alpha_composite(base, layer).convert("RGB").save(out)


def render_grid(layout: dict, out_dir: str) -> None:
    background = Image.open(res_path(layout["background"])).convert("RGB")
    scale = background.width / VIRTUAL[0]
    target = Path(out_dir)
    target.mkdir(parents=True, exist_ok=True)
    tiles = [(x, y) for y in range(0, VIRTUAL[1], 180) for x in range(0, VIRTUAL[0], 240)]
    for x0, y0 in tiles:
        x1, y1 = min(x0 + 240, VIRTUAL[0]), min(y0 + 180, VIRTUAL[1])
        crop = background.crop((round(x0 * scale), round(y0 * scale),
                                round(x1 * scale), round(y1 * scale)))
        zoom = 5.0
        crop = crop.resize((round((x1 - x0) * zoom), round((y1 - y0) * zoom)), Image.LANCZOS)
        draw = ImageDraw.Draw(crop)
        for gx in range(x0, x1 + 1, 10):
            major = gx % 50 == 0
            px = (gx - x0) * zoom
            draw.line([(px, 0), (px, crop.height)], fill=(0, 255, 255) if major else (0, 90, 90))
            if major:
                draw.text((px + 2, 2), str(gx), fill=(0, 255, 255))
        for gy in range(y0, y1 + 1, 10):
            major = gy % 50 == 0
            py = (gy - y0) * zoom
            draw.line([(0, py), (crop.width, py)], fill=(0, 255, 255) if major else (0, 90, 90))
            if major:
                draw.text((2, py + 2), str(gy), fill=(0, 255, 255))
        crop.save(target / f"grid_{x0:03d}_{y0:03d}.png")


# --- layout validation -------------------------------------------------------

def _point_in_polygon(x: float, y: float, polygon: list[tuple[float, float]]) -> bool:
    inside = False
    count = len(polygon)
    for index in range(count):
        ax, ay = polygon[index]
        bx, by = polygon[(index + 1) % count]
        if (ay > y) != (by > y):
            cross = ax + (y - ay) * (bx - ax) / (by - ay)
            if x < cross:
                inside = not inside
    return inside


def _segment_distance(px: float, py: float, a: tuple[float, float],
                      b: tuple[float, float]) -> float:
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy
    t = 0.0 if length == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def foot_is_walkable(layout: dict, x: float, y: float) -> bool:
    """Mirror of the runtime rule: the foot ellipse must fit the walkable space.

    The ellipse (``foot_radius`` = [rx, ry]) is tested as a circle of radius rx
    after stretching y by rx / ry, exactly as ``FloorRoomLayout`` does in Godot.
    """
    rx, ry = (float(value) for value in layout.get("foot_radius", [10.0, 6.0]))
    stretch = rx / ry

    def warp(polygon: list[tuple[float, float]]) -> list[tuple[float, float]]:
        return [(px, py * stretch) for px, py in polygon]

    wy = y * stretch
    bounds = warp([(float(px), float(py)) for px, py in layout["walk_bounds"]])
    if not _point_in_polygon(x, wy, bounds):
        return False
    for index in range(len(bounds)):
        if _segment_distance(x, wy, bounds[index], bounds[(index + 1) % len(bounds)]) < rx:
            return False
    for entry in layout["solids"]:
        polygon = warp(points(entry))
        if _point_in_polygon(x, wy, polygon):
            return False
        for index in range(len(polygon)):
            if _segment_distance(x, wy, polygon[index], polygon[(index + 1) % len(polygon)]) < rx:
                return False
    return True


def check_layout(layout: dict) -> list[str]:
    problems: list[str] = []
    for group in ("solids", "occluders"):
        names: set[str] = set()
        for entry in layout[group]:
            if entry["name"] in names:
                problems.append(f"duplicate {group} name {entry['name']}")
            names.add(entry["name"])
            if len(entry["points"]) < 3:
                problems.append(f"{group} {entry['name']} has fewer than three points")
    for occluder in layout["occluders"]:
        ys = [float(y) for _x, y in occluder["points"]]
        if not (min(ys) - 0.5 <= float(occluder["baseline"]) <= max(ys) + 24.0):
            problems.append(f"occluder {occluder['name']} baseline outside its footprint")
    step = 3
    grid = {}
    for gy in range(0, VIRTUAL[1] + 1, step):
        for gx in range(0, VIRTUAL[0] + 1, step):
            grid[(gx, gy)] = foot_is_walkable(layout, gx, gy)
    destinations = dict(layout.get("anchors", {}))
    destinations["spawn"] = layout["spawn"]
    destinations["return_point"] = layout["return_point"]
    for name, (x, y) in destinations.items():
        if not foot_is_walkable(layout, float(x), float(y)):
            problems.append(f"destination {name} at {x},{y} is not walkable")
    start = (round(layout["spawn"][0] / step) * step, round(layout["spawn"][1] / step) * step)
    reached = set()
    if grid.get(start):
        queue = deque([start])
        reached.add(start)
        while queue:
            cx, cy = queue.popleft()
            for nx, ny in ((cx + step, cy), (cx - step, cy), (cx, cy + step), (cx, cy - step)):
                if grid.get((nx, ny)) and (nx, ny) not in reached:
                    reached.add((nx, ny))
                    queue.append((nx, ny))
    for name, (x, y) in destinations.items():
        nearest = (round(x / step) * step, round(y / step) * step)
        if nearest not in reached:
            problems.append(f"destination {name} is not connected to the spawn")
    return problems


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    command, layout_path = argv[1], argv[2]
    layout = load_layout(layout_path)
    if command == "build":
        foreground = build_foreground(layout)
        foreground.save(res_path(layout["foreground"]), optimize=True)
        collision = build_collision(layout, foreground.size)
        collision.save(res_path(layout["collision_reference"]), optimize=True)
        preview = build_preview(layout, foreground)
        preview.save(res_path(layout["composite_preview"]), optimize=True)
        print("built", layout["id"], foreground.size)
    elif command == "overlay":
        render_overlay(layout, argv[3])
    elif command == "grid":
        render_grid(layout, argv[3])
    elif command == "check":
        problems = check_layout(layout)
        for problem in problems:
            print("PROBLEM", problem)
        print("ok" if not problems else f"{len(problems)} problem(s)")
        return 1 if problems else 0
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
