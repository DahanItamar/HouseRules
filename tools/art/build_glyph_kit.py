"""Build the controller-glyph kit and the shared result plaques.

python tools/art/build_glyph_kit.py

Sources are the raw Higgsfield gpt_image_2_5 outputs (1k, transparent) in
assets/source/layered_v2/ui_kit/. They are never modified.

* Round glyphs (Xbox A/B/X/Y, PlayStation face): the soft glow outside the
  bezel is cut back to the solid silhouette with a 2 px feather, so no halo
  remains; the inner face radius is measured from the bezel highlight.
* Nine-slice pieces (bumper pill, keycap, result banner, score badge): any
  partial transparency inside the silhouette is composited over the face
  colour (sampled just inside the rim on the middle row), then the face is
  flattened to that one colour so nothing stretches but flat paint. Only
  pixels that are already the face are flattened, so a corner fan's rays -
  which have face-coloured gaps between them - survive.
* Round glyphs and the D-pad are trimmed, scaled so the longer side is
  CANVAS - 2 * PAD and centred on a square CANVAS, so they share one visual
  size. The bumper and keycap keep their painted aspect and record their cap
  widths instead: they are drawn as three horizontal slices (left cap,
  stretched middle, right cap), which is the only axis they stretch on.
* The plaques keep their aspect and take a four-side patch margin proved to
  hold every ornament: the margin is searched on the brass, not on the face,
  and their straight rails are made uniform along the axis they stretch on.

Writes assets/production/ui/glyphs/*.png + glyphs.json, the two plaques into
assets/production/ui/kit/ (and a "shared" entry in ui_kit.json), and a contact
sheet at tests/results/screenshots/ui_assets/glyphs_sheet.png.
"""
from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/layered_v2/ui_kit"
GLYPHS = ROOT / "assets/production/ui/glyphs"
KIT = ROOT / "assets/production/ui/kit"
SHEET = ROOT / "tests/results/screenshots/ui_assets/glyphs_sheet.png"
CANVAS = 512
PAD = 8
FACE_TOL = 22.0
RUN = 8

# name -> (source file, kind, destination, decorated)
PIECES = {
    "xbox_a": ("glyph_xbox_a_8d8a7774.png", "round", "glyph", False),
    "xbox_b": ("glyph_xbox_b_1a9bf708.png", "round", "glyph", False),
    "xbox_x": ("glyph_xbox_x_cefdd668.png", "round", "glyph", False),
    "xbox_y": ("glyph_xbox_y_79263493.png", "round", "glyph", False),
    "ps_face": ("glyph_ps_face_74fff9b3.png", "round", "glyph", False),
    "bumper": ("glyph_bumper_de6ffec4.png", "nine_slice", "glyph", False),
    "keycap": ("glyph_keycap_18b1b0e2.png", "nine_slice", "glyph", False),
    "dpad": ("glyph_dpad_5272aab5.png", "icon", "glyph", False),
    "plaque_result_banner": ("plaque_result_banner_f7f222ae.png", "nine_slice", "kit", True),
    "plaque_score_badge": ("plaque_score_badge_af586893.png", "nine_slice", "kit", True),
}


def silhouette(alpha: np.ndarray, threshold: int = 128) -> np.ndarray:
    """Largest solid component with its holes filled."""
    solid = (alpha >= threshold).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(solid, 8)
    if count <= 1:
        return solid.astype(bool)
    biggest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    main = (labels == biggest).astype(np.uint8)
    # Fill holes: flood the outside from a padded border.
    padded = np.pad(main, 1)
    flood = padded.copy()
    mask = np.zeros((padded.shape[0] + 2, padded.shape[1] + 2), np.uint8)
    cv2.floodFill(flood, mask, (0, 0), 1)
    holes = (flood == 0)[1:-1, 1:-1]
    return (main.astype(bool)) | holes


def clean_alpha(rgba: np.ndarray, sil: np.ndarray) -> np.ndarray:
    """Cut everything outside the silhouette with a 2 px feather (halo removal)."""
    out = rgba.astype(np.float32)
    outside = (~sil).astype(np.uint8)
    dist = cv2.distanceTransform(outside, cv2.DIST_L2, 5)
    keep = np.clip(1.0 - dist / 2.0, 0.0, 1.0)
    out[..., 3] *= keep
    alpha = out[..., 3]
    alpha[alpha >= 248] = 255
    alpha[alpha < 4] = 0
    out[alpha == 0, :3] = 0
    return out


def trim(rgba: np.ndarray, pad: int) -> np.ndarray:
    ys, xs = np.nonzero(rgba[..., 3] > 0)
    crop = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return np.pad(crop, ((pad, pad), (pad, pad), (0, 0)))


def resize(rgba: np.ndarray, width: int, height: int) -> np.ndarray:
    """Premultiplied Lanczos resize so no dark fringe bleeds into the edge."""
    premul = rgba.copy()
    premul[..., :3] *= premul[..., 3:4] / 255.0
    channels = [np.asarray(Image.fromarray(premul[..., c].astype(np.float32), "F")
                           .resize((width, height), Image.LANCZOS)) for c in range(4)]
    out = np.clip(np.dstack(channels), 0, 255)
    safe = np.maximum(out[..., 3:4], 1e-3) / 255.0
    out[..., :3] = np.where(out[..., 3:4] > 0, np.clip(out[..., :3] / safe, 0, 255), 0)
    out[..., 3][out[..., 3] >= 248] = 255
    out[..., 3][out[..., 3] < 4] = 0
    return out


def to_square(rgba: np.ndarray) -> np.ndarray:
    ys, xs = np.nonzero(rgba[..., 3] > 0)
    crop = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    inner = CANVAS - 2 * PAD
    scale = inner / max(crop.shape[:2])
    w, h = max(1, round(crop.shape[1] * scale)), max(1, round(crop.shape[0] * scale))
    scaled = resize(crop, w, h)
    out = np.zeros((CANVAS, CANVAS, 4), np.float32)
    x0, y0 = (CANVAS - w) // 2, (CANVAS - h) // 2
    out[y0:y0 + h, x0:x0 + w] = scaled
    return out


def stable_from(line: np.ndarray, valid: np.ndarray, face: np.ndarray, reverse: bool) -> int | None:
    """First index (scanning inward) where the colour stays within FACE_TOL of face for RUN px."""
    n = len(line)
    order = range(n - 1, -1, -1) if reverse else range(n)
    close = (np.sqrt(((line - face) ** 2).sum(-1)) < FACE_TOL) & valid
    started = False
    for i in order:
        if not valid[i] and not started:
            continue
        started = True
        window = close[i - RUN + 1:i + 1] if reverse else close[i:i + RUN]
        if len(window) == RUN and window.all():
            return i
    return None


def face_colour(rgba: np.ndarray, sil: np.ndarray) -> tuple[np.ndarray, int, int]:
    """Colour sampled just inside the rim on the middle row, plus the rim's inner edges."""
    h, w = sil.shape
    row = h // 2
    xs = np.nonzero(sil[row])[0]
    left, right = xs.min(), xs.max()
    span = right - left
    rgb = rgba[row, :, :3]
    centre = np.median(rgb[left + span * 2 // 5:right - span * 2 // 5], axis=0)
    x0 = stable_from(rgb, sil[row], centre, False)
    x1 = stable_from(rgb, sil[row], centre, True)
    samples = np.concatenate([rgb[x0 + 2:x0 + 10], rgb[x1 - 9:x1 - 1]])
    return np.median(samples, axis=0), int(x0), int(x1)


def cap_margins(sil: np.ndarray) -> tuple[int, int]:
    """Width of the painted left/right caps: how far in the shape takes to reach full height.

    A pill's cap is its corner radius; a keycap's is its corner round plus rim. Everything
    between the two caps is one repeating column, so it is the part safe to stretch.
    """
    heights = sil.sum(0)
    full = heights.max()
    solid = heights >= full * 0.995
    left = int(np.argmax(solid))
    right = int(np.argmax(solid[::-1]))
    return left + 2, right + 2


def collapse_band(rgba: np.ndarray, left: int, right: int) -> np.ndarray:
    """Make every column between the caps identical, so a horizontal stretch is exact."""
    band = rgba[:, left:rgba.shape[1] - right]
    rgba[:, left:rgba.shape[1] - right] = np.median(band, axis=1, keepdims=True)
    return rgba


def edge_profiles(inner: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Per column/row, how far in from each edge the flat face starts."""
    h, w = inner.shape
    big = max(h, w)
    top = np.where(inner.any(0), inner.argmax(0), big)
    bottom = np.where(inner.any(0), inner[::-1].argmax(0), big)
    left = np.where(inner.any(1), inner.argmax(1), big)
    right = np.where(inner.any(1), inner[:, ::-1].argmax(1), big)
    return top, bottom, left, right


def inner_margin(rgba: np.ndarray, sil: np.ndarray, face: np.ndarray) -> int:
    """Smallest nine-patch margin whose four corner patches hold every ornament.

    Measured on the brass (everything painted that is not the flat face), not on the
    face: a corner fan's rays have face-coloured gaps between them, so the face mask
    reaches the corner and cannot bound the ornament. Beyond this margin every edge
    is the straight rail, which is what the stretched edge patches may contain.
    """
    h, w = sil.shape
    ornament = sil & (np.sqrt(((rgba[..., :3] - face) ** 2).sum(-1)) > FACE_TOL * 1.5)
    ornament = cv2.morphologyEx(ornament.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    ornament = ornament.astype(bool)
    limit = (min(h, w) - 8) // 2
    for m in range(4, limit):
        if not ornament[m:h - m, m:w - m].any():
            return m + 2
    return limit


def corner_extent(sil: np.ndarray, inner: np.ndarray) -> tuple[int, int]:
    """How far (rows, columns) the corner shape or ornament intrudes past the straight rim band."""
    h, w = sil.shape
    edges = []
    for y in range(h):
        xs = np.nonzero(inner[y])[0]
        edges.append(xs.min() if len(xs) else w)
    edges = np.array(edges)
    band = int(np.median(edges[h // 3:2 * h // 3]))
    rows = np.nonzero(edges[: h // 2] > band + 2)[0]
    cy = int(rows.max()) + 1 if len(rows) else 0
    cols = []
    for x in range(w):
        ys = np.nonzero(inner[:, x])[0]
        cols.append(ys.min() if len(ys) else h)
    cols = np.array(cols)
    bandy = int(np.median(cols[w // 3:2 * w // 3]))
    over = np.nonzero(cols[: w // 2] > bandy + 2)[0]
    cx = int(over.max()) + 1 if len(over) else 0
    return max(cy, band), max(cx, bandy)


def flatten_nine_slice(rgba: np.ndarray, decorated: bool) -> tuple[np.ndarray, int, str]:
    sil = silhouette(rgba[..., 3])
    rgba = clean_alpha(rgba, sil)
    face, x0, x1 = face_colour(rgba, sil)
    # Leak fix: composite any partial transparency inside the silhouette over the face.
    interior = cv2.erode(sil.astype(np.uint8), np.ones((5, 5), np.uint8)).astype(bool)
    a = rgba[..., 3:4] / 255.0
    mixed = rgba[..., :3] * a + face * (1.0 - a)
    rgba[interior, :3] = mixed[interior]
    rgba[interior, 3] = 255
    h, w = sil.shape
    rgb = rgba[..., :3]
    close = np.sqrt(((rgb - face) ** 2).sum(-1)) < FACE_TOL
    if decorated:
        # Row-by-row stable face span, so ornaments survive.
        inner = np.zeros_like(sil)
        for y in range(h):
            valid = interior[y]
            if not valid.any():
                continue
            a0 = stable_from(rgb[y], valid, face, False)
            a1 = stable_from(rgb[y], valid, face, True)
            if a0 is not None and a1 is not None and a1 > a0:
                inner[y, a0:a1 + 1] = True
        # Keep only the face region connected to the centre.
        count, labels = cv2.connectedComponents(inner.astype(np.uint8), 4)
        centre_label = labels[h // 2, w // 2]
        if centre_label:
            inner = labels == centre_label
        # A corner fan's rays sit inside that span with face-coloured gaps between
        # them; flatten only what is already the face, or the rays are painted out.
        inner &= close
    else:
        rim = min(x0 - int(np.nonzero(sil[h // 2])[0].min()), int(np.nonzero(sil[h // 2])[0].max()) - x1)
        dist = cv2.distanceTransform(sil.astype(np.uint8), cv2.DIST_L2, 5)
        inner = dist >= rim
    if decorated:
        # The border patches must hold every ornament: nine-patch never scales a corner.
        margin = inner_margin(rgba, sil, face)
    else:
        ext_y, ext_x = corner_extent(sil, inner)
        margin = max(ext_y, ext_x) + 4
    margin = min(margin, (min(h, w) - 8) // 2)
    # Face flatten (soft 1 px edge), then the whole centre patch hard.
    soft = cv2.GaussianBlur(inner.astype(np.float32), (3, 3), 0.8)[..., None]
    rgba[..., :3] = rgba[..., :3] * (1.0 - soft) + face * soft
    rgba[margin:h - margin, margin:w - margin, :3] = face
    rgba[margin:h - margin, margin:w - margin, 3] = 255
    if decorated:
        # The straight rails between the ornaments stretch, so make them exactly uniform.
        rgba[:margin, margin:w - margin] = np.median(
            rgba[:margin, margin:w - margin], axis=1, keepdims=True)
        rgba[h - margin:, margin:w - margin] = np.median(
            rgba[h - margin:, margin:w - margin], axis=1, keepdims=True)
        rgba[margin:h - margin, :margin] = np.median(
            rgba[margin:h - margin, :margin], axis=0, keepdims=True)
        rgba[margin:h - margin, w - margin:] = np.median(
            rgba[margin:h - margin, w - margin:], axis=0, keepdims=True)
    hex_colour = "#%02x%02x%02x" % tuple(int(round(c)) for c in face)
    return rgba, margin, hex_colour


def round_glyph(rgba: np.ndarray) -> tuple[np.ndarray, float, float]:
    sil = silhouette(rgba[..., 3], 160)
    rgba = clean_alpha(rgba, sil)
    return rgba, 0.0, 0.0


def face_radius(rgba: np.ndarray) -> tuple[float, float]:
    """Inner face radius as a fraction of the canvas half-size, and circularity."""
    sil = rgba[..., 3] >= 128
    ys, xs = np.nonzero(sil)
    cy, cx = ys.mean(), xs.mean()
    radius = np.sqrt(sil.sum() / np.pi)
    h, w = sil.shape
    yy, xx = np.mgrid[:h, :w]
    r = np.hypot(yy - cy, xx - cx)
    lum = rgba[..., :3].mean(-1)
    bins = np.arange(int(radius * 0.55), int(radius * 0.97), 2)
    profile = np.array([lum[(r >= b) & (r < b + 2)].mean() for b in bins])
    peak = bins[int(np.argmax(profile))]
    face = max(peak - 4, radius * 0.55)
    extent = max(xs.max() - xs.min(), ys.max() - ys.min()) / 2.0
    circularity = sil.sum() / (np.pi * extent ** 2)
    return float(face / (CANVAS / 2)), float(circularity)


def process() -> dict:
    GLYPHS.mkdir(parents=True, exist_ok=True)
    manifest = {"about": ("Controller glyph kit (Higgsfield gpt_image_2_5, 1k, transparent), built by "
                          "tools/art/build_glyph_kit.py. All glyphs share a %dx%d canvas with a %d px pad; "
                          "the longer side of each shape fills the canvas. Round glyphs: draw the letter or "
                          "symbol in code inside face_radius_fraction * half the drawn size, centred at "
                          "face_centre. Nine-slice: NinePatchRect with patch_margin (px in this file) and "
                          "the flat centre_colour." % (CANVAS, CANVAS, PAD)),
                "canvas": CANVAS, "glyphs": {}}
    shared = {}
    built = {}
    for name, (source, kind, dest, decorated) in PIECES.items():
        path = SOURCE / source
        if not path.exists():
            print("missing", source)
            continue
        rgba = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32)
        entry: dict = {"kind": kind, "source": "assets/source/layered_v2/ui_kit/" + source}
        if dest == "glyph":
            if kind == "round":
                rgba, _, _ = round_glyph(rgba)
                rgba = to_square(rgba)
                fraction, circ = face_radius(rgba)
                sil = rgba[..., 3] >= 128
                ys, xs = np.nonzero(sil)
                entry["face_radius_fraction"] = round(fraction, 3)
                entry["face_centre"] = [round(float(xs.mean()) / CANVAS, 3), round(float(ys.mean()) / CANVAS, 3)]
                entry["circularity"] = round(circ, 3)
            elif kind == "nine_slice":
                # Kept at its painted aspect: a pill is not square, and it is drawn as
                # three horizontal slices (left cap, stretched middle, right cap), so
                # only the cap widths matter.
                sil = silhouette(rgba[..., 3])
                rgba = trim(clean_alpha(rgba, sil), PAD)
                rgba, _margin, colour = flatten_nine_slice(rgba, decorated)
                left, right = cap_margins(silhouette(rgba[..., 3]))
                rgba = collapse_band(rgba, left, right)
                entry["cap_left"] = left
                entry["cap_right"] = right
                entry["size"] = [rgba.shape[1], rgba.shape[0]]
                entry["centre_colour"] = colour
            else:
                sil = silhouette(rgba[..., 3])
                rgba = to_square(clean_alpha(rgba, sil))
            out_path = GLYPHS / f"{name}.png"
            entry = {"path": "res://assets/production/ui/glyphs/%s.png" % name, **entry}
            manifest["glyphs"][name] = entry
        else:
            sil = silhouette(rgba[..., 3])
            rgba = trim(clean_alpha(rgba, sil), PAD)
            rgba, margin, colour = flatten_nine_slice(rgba, decorated)
            out_path = KIT / f"{name}.png"
            shared[name.replace("plaque_", "")] = {
                "path": "res://assets/production/ui/kit/%s.png" % name,
                "patch_margin": margin,
                "centre_colour": colour,
            }
        image = Image.fromarray(np.clip(np.round(rgba), 0, 255).astype(np.uint8), "RGBA")
        image.save(out_path)
        built[name] = image
        print("wrote", out_path.relative_to(ROOT), image.size, {k: v for k, v in entry.items() if k != "source"})
    (GLYPHS / "glyphs.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    if shared:
        kit_json = KIT / "ui_kit.json"
        data = json.loads(kit_json.read_text(encoding="utf-8"))
        data.setdefault("shared", {}).update(shared)
        kit_json.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        print("updated", kit_json.relative_to(ROOT), "shared:", sorted(data["shared"]))
    contact_sheet(built, manifest)
    return manifest


def contact_sheet(built: dict, manifest: dict) -> None:
    cell = 280
    cols = 5
    rows = (len(built) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * (cell + 24)), (128, 128, 128))
    draw = ImageDraw.Draw(sheet)
    for i, (name, image) in enumerate(built.items()):
        x, y = (i % cols) * cell, (i // cols) * (cell + 24)
        thumb = image.copy()
        thumb.thumbnail((cell - 24, cell - 24), Image.LANCZOS)
        sheet.paste(thumb, (x + (cell - thumb.width) // 2, y + (cell - thumb.height) // 2), thumb)
        draw.text((x + 10, y + cell + 4), name, fill=(20, 20, 20))
    SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(SHEET)
    print("wrote", SHEET.relative_to(ROOT))


if __name__ == "__main__":
    process()
