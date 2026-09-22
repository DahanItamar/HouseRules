"""Build the player's full-body walk atlas from the Higgsfield/Kling walk videos.

    python tools/art/build_player_walk_video.py
    python tools/art/build_player_walk_video.py --probe   # signals + contact sheets

Five 24 fps 1440x1440 clips of the same ivory-jacket player walking on flat grey
give the five authored facings; W, SW and NW are horizontal mirrors of E, SE and
NE. For each clip the tool

1. extracts every frame with ffmpeg and keys out the flat grey. `key_out` from
   build_player_walk.py does the unmixing; a chromaticity test plus a border
   flood fill removes the soft ground shadow, which is grey of the same hue and
   would otherwise survive the distance key.
2. measures the feet's separation in three bands of the lower body, which peaks
   once per step, and the signed offset of the leading foot from the body axis,
   which peaks once per cycle, and fits a sinusoid to each to find the step
   rate, and with it the cycle and the contact the cycle starts on.
3. picks the cycle that starts at the contact whose leading foot is on the
   screen-right of the body axis, and samples it at eight even phases. Samples
   land on the nearest real frame; nothing is cross-faded, so no beat can morph.
4. stabilises: the torso centre's drift (the model's slow slide across the
   plate, tracked as a one-cycle moving average) is removed while its per-frame
   sway is kept, and the whole cycle shares one ground reference, so the natural
   vertical bob survives.
5. scales by one factor per view, to TARGET_HEIGHT in a CELL cell with the
   lowest sole of the cycle on FOOT_LINE.

Output layout matches src/floor/character_walk_atlas.gd: 8 columns
(N, NE, E, SE, S, SW, W, NW, clockwise from north) x 8 phase rows, 240 px cells
with a 9 px transparent gutter.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_player_walk import key_out  # noqa: E402  (same-folder tool)

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/walk_v2"
OUTPUT = ROOT / "assets/production/characters/player_walk_v3.png"
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"

CELL = 240
GUTTER = 9
FOOT_LINE = CELL // 2 + 110
TARGET_HEIGHT = 200
PHASES = 8

# column -> (clip, steady-state frame window). The window ends before the camera
# pushes in far enough to crop the shoes (front and front34 reach the bottom of
# the plate around frame 90) and starts after the model's first, shortened step.
VIEWS: dict[int, tuple[str, range]] = {
    0: ("video_back_454b106f.mp4", range(14, 86)),
    1: ("video_back34_4658ceb8.mp4", range(14, 86)),
    2: ("video_side_512bf8fa.mp4", range(14, 96)),
    3: ("video_front34_55aa5bdd.mp4", range(14, 76)),
    4: ("video_front_4921f301.mp4", range(14, 66)),
}
NAMES = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
MIRRORS = {5: 3, 6: 2, 7: 1}
STEP_FRAMES = range(8, 24)


# --------------------------------------------------------------------------- #
# frames
# --------------------------------------------------------------------------- #
def extract(clip: str, frames_dir: Path) -> list[Path]:
    out = frames_dir / Path(clip).stem
    out.mkdir(parents=True, exist_ok=True)
    if not any(out.glob("*.png")):
        subprocess.run(
            [str(FFMPEG), "-v", "error", "-y", "-i", str(SOURCE / clip),
             "-vsync", "0", str(out / "%03d.png")],
            check=True,
        )
    return sorted(out.glob("*.png"))


def backdrop(rgb: np.ndarray) -> np.ndarray:
    edges = np.concatenate([rgb[:6].reshape(-1, 3), rgb[-6:].reshape(-1, 3),
                            rgb[:, :6].reshape(-1, 3), rgb[:, -6:].reshape(-1, 3)])
    return np.median(edges.astype(np.float32), axis=0)


def outside_mask(rgb: np.ndarray, bg: np.ndarray) -> np.ndarray:
    """True where the pixel is plate or its soft shadow, not the figure.

    A shadow is the backdrop scaled down, so it keeps the backdrop's direction
    in RGB. Pixels close to that line and between 0.45x and 1.10x as bright are
    candidates; only the component that reaches the border is really outside, so
    a grey fold inside the jacket cannot punch a hole.
    """
    flat = rgb.astype(np.float32)
    scale = (flat @ bg) / float(bg @ bg)
    residual = np.linalg.norm(flat - scale[..., None] * bg, axis=-1)
    plate = (residual < 18.0) & (scale > 0.45) & (scale < 1.10)
    count, labels = cv2.connectedComponents(plate.astype(np.uint8), connectivity=4)
    border = set(labels[0].tolist()) | set(labels[-1].tolist())
    border |= set(labels[:, 0].tolist()) | set(labels[:, -1].tolist())
    border.discard(0)
    return np.isin(labels, list(border))


def largest_blob(alpha: np.ndarray) -> np.ndarray:
    solid = (alpha > 128).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(solid, connectivity=8)
    if count <= 1:
        return alpha
    biggest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    return np.where(labels == biggest, alpha, 0).astype(np.uint8)


def cut_figure(path: Path) -> np.ndarray:
    """RGBA of one frame: grey keyed out, shadow dropped, fringe de-greyed."""
    rgb = np.asarray(Image.open(path).convert("RGB"))
    rgba = key_out(rgb).astype(np.float32)
    outside = outside_mask(rgb, backdrop(rgb))
    rgba[outside] = 0.0
    # A distance key reads the figure's own mid-greys -- the lapel piping, the
    # shirt's shadow side -- as half transparent and unmixes their colour away.
    # Everything two pixels inside the silhouette is solid by construction, so
    # it keeps full alpha and its original colour; only the rim stays soft.
    core = cv2.erode((~outside).astype(np.uint8), np.ones((3, 3), np.uint8), iterations=2) > 0
    rgba[core, 3] = 255.0
    rgba[core, :3] = rgb[core]
    # De-fringe: pull the faintest edge pixels (the ones still carrying plate
    # grey after unmixing) to nothing and re-solidify the rest.
    rgba[..., 3] = np.clip(rgba[..., 3] * 1.18 - 34.0, 0.0, 255.0)
    rgba[rgba[..., 3] < 1.0] = 0.0
    out = rgba.astype(np.uint8)
    out[..., 3] = largest_blob(out[..., 3])
    out[out[..., 3] == 0] = 0
    return out


# --------------------------------------------------------------------------- #
# gait analysis
# --------------------------------------------------------------------------- #
def measure(rgba: np.ndarray) -> dict:
    solid = rgba[..., 3] > 128
    ys, xs = np.nonzero(solid)
    top, bottom = int(ys.min()), int(ys.max())
    height = max(bottom - top, 1)
    torso = solid[top:top + int(height * 0.45)]
    torso_x = float(np.nonzero(torso)[1].mean())
    # The head and collar carry no swinging arms, so their centre is the one
    # part of the silhouette that tracks the body without the arms' bias.
    head = solid[top:top + max(int(height * 0.16), 4)]
    head_x = float(np.nonzero(head)[1].mean())
    # One peak per step in each band: the feet are farthest apart at a contact.
    # Three heights, because a view that hides the shins (the back) still parts
    # its shoes, and a view that hides the shoes (the front) still parts its
    # shins.
    spread = []
    for fraction in (0.74, 0.84, 0.90):
        band = solid[top + int(height * fraction):bottom + 1]
        band_xs = np.nonzero(band.any(0))[0]
        spread.append(float(band_xs.max() - band_xs.min()) / height)
    lead = solid[bottom - max(height // 14, 2):bottom + 1]
    lead_xs = np.nonzero(lead)[1]
    return {
        "top": top,
        "bottom": bottom,
        "height": height,
        "torso_x": torso_x,
        "head_x": head_x,
        "spread": spread,
        # One peak per cycle: the lowest (leading) foot swaps sides each step.
        "lead": (float(lead_xs.mean()) - torso_x) / height,
    }


def flatten(signal: np.ndarray) -> np.ndarray:
    """Signal minus its quadratic trend.

    The back view's legs overlap more and more as the model turns a few degrees
    over the clip, which buries its small gait oscillation under a slow slide.
    Removing a quadratic leaves the gait and needs no period to do it.
    """
    t = np.arange(len(signal), dtype=np.float64)
    return signal - np.polyval(np.polyfit(t, signal, 2), t)


def wave(signal: np.ndarray, period: float) -> tuple[float, float, float]:
    """Single-harmonic least-squares fit: (amplitude, phase, r-squared).

    The wave is amplitude * cos(2*pi*t/period + phase), so its crests are at
    t = (TAU*k - phase) * period / TAU.
    """
    t = np.arange(len(signal), dtype=np.float64)
    angle = 2.0 * np.pi * t / period
    design = np.column_stack([np.cos(angle), np.sin(angle), np.ones_like(t)])
    coefficients, *_ = np.linalg.lstsq(design, signal, rcond=None)
    residual = float(((signal - design @ coefficients) ** 2).sum())
    total = float(((signal - signal.mean()) ** 2).sum())
    return (
        float(np.hypot(coefficients[0], coefficients[1])),
        float(np.arctan2(-coefficients[1], coefficients[0])),
        1.0 - residual / max(total, 1e-12),
    )


def step_period(spreads: list[np.ndarray]) -> float:
    """Frames per step, to a twentieth of a frame.

    Every band's foot separation runs at the step rate, so the step rate is the
    period that explains all three at once. Fitting at the step rate rather than
    the cycle rate avoids the half/double ambiguity: the cycle is simply twice
    the step, and which of the cycle's two steps comes first is settled
    separately, by the footedness signal.
    """
    best, best_score = float(STEP_FRAMES.start), -9.0
    for twentieths in range(STEP_FRAMES.start * 20, STEP_FRAMES.stop * 20):
        period = twentieths / 20.0
        score = sum(wave(spread, period)[2] for spread in spreads)
        if score > best_score:
            best, best_score = period, score
    return best


def start_frame(separation: np.ndarray, lead: np.ndarray, step: float) -> float:
    """First contact of a full cycle whose leading foot is screen-right.

    Contacts are the crests of the foot-separation wave, one per step, which is
    the one gait landmark every view shows. Of the two in a cycle this takes the
    one where the fitted once-per-cycle footedness wave is high -- the contact
    with the leading foot on the screen-right of the body axis. Mirroring for
    W/SW/NW swaps that foot, as a mirrored walker's footedness should. Where a
    view's footedness wave is faint (a depth view hides which foot is which) the
    choice between the cycle's two contacts is arbitrary, but every column still
    starts on a contact, which is what keeps the rows aligned across the atlas.
    """
    _, contact_phase, _ = wave(separation, step)
    _, foot_phase, _ = wave(lead, step * 2.0)
    latest = len(separation) - step * 2.0 - 1.0
    for k in range(-2, 24):
        crest = (2.0 * np.pi * k - contact_phase) * step / (2.0 * np.pi)
        if 0.0 <= crest <= latest:
            if np.cos(2.0 * np.pi * crest / (step * 2.0) + foot_phase) > 0.0:
                return crest
    return 0.0


def sample_phases(start: float, period: float, count: int) -> list[int]:
    """Eight even phases on real frames -- never blended, so nothing morphs."""
    return [
        min(max(int(round(start + period * phase / PHASES)), 0), count - 1)
        for phase in range(PHASES)
    ]


def drift_baseline(head: np.ndarray, period: float) -> np.ndarray:
    """One-cycle moving average of the head centre: the plate drift alone.

    A straight line cannot follow a model who slides across the plate unevenly,
    so the baseline is a one-cycle moving average (edges held). It is reported
    for the log; the frames themselves are aligned on the head centre directly,
    which removes drift and head sway together and leaves the hips and shoulders
    free to sway around the axis.
    """
    span = max(int(round(period)), 3)
    padded = np.pad(head, (span // 2, span - span // 2 - 1), mode="edge")
    kernel = np.ones(span) / span
    return np.convolve(padded, kernel, mode="valid")[: len(head)]


# --------------------------------------------------------------------------- #
# placement
# --------------------------------------------------------------------------- #
def place(cuts: list[np.ndarray], stats: list[dict], drift: np.ndarray) -> list[Image.Image]:
    """One scale for the view; drift removed, body sway and bob kept."""
    scale = TARGET_HEIGHT / max(s["height"] for s in stats)
    ground = max(s["bottom"] for s in stats)
    cells: list[Image.Image] = []
    for rgba, stat, axis in zip(cuts, stats, drift):
        image = Image.fromarray(rgba)
        image = image.resize(
            (round(image.width * scale), round(image.height * scale)), Image.LANCZOS
        )
        cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        cell.alpha_composite(
            image,
            (round(CELL / 2 - axis * scale), round(FOOT_LINE - ground * scale)),
        )
        pixels = np.asarray(cell).copy()
        pixels[:GUTTER] = 0
        pixels[-GUTTER:] = 0
        pixels[:, :GUTTER] = 0
        pixels[:, -GUTTER:] = 0
        cells.append(Image.fromarray(pixels))
    return cells


def build_view(column: int, frames_dir: Path, probe: bool) -> tuple[list[Image.Image], dict]:
    clip, window = VIEWS[column]
    paths = extract(clip, frames_dir)
    cuts = [cut_figure(paths[i]) for i in window]
    stats = [measure(rgba) for rgba in cuts]
    spreads = [
        flatten(np.array([s["spread"][band] for s in stats])) for band in range(3)
    ]
    separation = sum(spreads) / len(spreads)
    lead = flatten(np.array([s["lead"] for s in stats]))
    step = step_period(spreads)
    period = step * 2.0
    start = start_frame(separation, lead, step)
    picked = sample_phases(start, period, len(cuts))
    head = np.array([s["head_x"] for s in stats])
    baseline = drift_baseline(head, period)
    axes = np.array([stats[i]["head_x"] for i in picked])
    report = {
        "column": column,
        "name": NAMES[column],
        "clip": clip,
        "window": [window.start, window.stop],
        "step_frames": round(step, 2),
        "period_frames": round(period, 1),
        "start_frame": round(window.start + start, 1),
        "source_frames": [window.start + i for i in picked],
        "drift_px": round(float(baseline[-1] - baseline[0]), 1),
        "sway_px": round(float(np.ptp(head - baseline)), 1),
        "height_px": [stats[i]["height"] for i in picked],
    }
    if probe:
        print(
            "%-3s period=%4.1f start=%5.1f frames=%s drift=%+.1f sway=%.1f heights=%s"
            % (
                NAMES[column], period, report["start_frame"], report["source_frames"],
                report["drift_px"], report["sway_px"], report["height_px"],
            )
        )
    return place([cuts[i] for i in picked], [stats[i] for i in picked], np.array(axes)), report


def contact_sheet(cells: list[Image.Image], path: Path) -> None:
    sheet = Image.new("RGBA", (CELL * len(cells), CELL), (0, 0, 0, 0))
    for index, cell in enumerate(cells):
        sheet.alpha_composite(cell, (index * CELL, 0))
    backing = Image.new("RGBA", sheet.size, (24, 24, 28, 255))
    backing.alpha_composite(sheet)
    backing.convert("RGB").save(path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--probe", action="store_true", help="print gait numbers")
    parser.add_argument(
        "--sheets", type=Path, default=None, help="write a per-view contact sheet here"
    )
    parser.add_argument(
        "--frames-dir",
        type=Path,
        default=Path(tempfile.gettempdir()) / "houserules_walk_frames",
        help="where extracted video frames are cached",
    )
    args = parser.parse_args()

    columns: dict[int, list[Image.Image]] = {}
    reports = []
    for column in VIEWS:
        cells, report = build_view(column, args.frames_dir, args.probe)
        columns[column] = cells
        reports.append(report)
        if args.sheets:
            args.sheets.mkdir(parents=True, exist_ok=True)
            contact_sheet(cells, args.sheets / ("view_%s.png" % NAMES[column]))
    for column, source in MIRRORS.items():
        columns[column] = [c.transpose(Image.FLIP_LEFT_RIGHT) for c in columns[source]]
        if args.sheets:
            contact_sheet(columns[column], args.sheets / ("view_%s.png" % NAMES[column]))

    atlas = Image.new("RGBA", (CELL * 8, CELL * PHASES), (0, 0, 0, 0))
    for column, cells in columns.items():
        for phase, cell in enumerate(cells):
            atlas.alpha_composite(cell, (column * CELL, phase * CELL))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUTPUT)
    print("wrote", OUTPUT.relative_to(ROOT), atlas.size)
    for report in reports:
        print("  %-3s %s period=%.1f frames=%s" % (
            report["name"], report["clip"], report["period_frames"], report["source_frames"]
        ))


if __name__ == "__main__":
    main()
