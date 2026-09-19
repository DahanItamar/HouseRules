"""Derive the Blackjack v2 production assets from the Higgsfield source generations.

Run from the repository root:  python assets/source/layered_v2/blackjack/prepare_blackjack_v2.py

Never overwrites a source generation. Outputs (all under assets/production/blackjack/):
  props/card_shoe_v2.png, props/chip_stack_v2.png  (trimmed, real alpha)
  dealer/blackjack_dealer_v2_salon_<pose>.png      (the salon dealer's pose masters)
  dealer/blackjack_dealer_v2_salon_hands_<pose>.png (hands/cuffs/cards below the rail line,
                                                    drawn in front of the table rail)
The playing-card deck itself lives in assets/production/cards/ (see
assets/source/layered_v2/cards/prepare_cards.py). The table master (blackjack_table_v2.png) is produced separately: a 1.12x top-centred crop of
table_a_d99954b1.png resized to 3840x2160 with the painted betting circle inpainted out.
"""

from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[4]
SRC = ROOT / "assets/source/layered_v2/blackjack"
OUT = ROOT / "assets/production/blackjack"
HOSTS = ROOT / "assets/production/characters/hosts"

## Source row of the dealer masters that sits exactly on the table's far rail edge.
RAIL_SOURCE_Y = 1360
RAIL_FEATHER = 10
POSES = {"cards": "", "deal": "_deal", "reveal": "_reveal", "player": "_player"}
BURGUNDY = np.array([92.0, 20.0, 32.0])


def _prop(src_name: str, out_name: str, max_side: int, mirror: bool = False) -> None:
    image = Image.open(SRC / src_name).convert("RGBA")
    rgba = np.array(image)
    rgba[rgba[..., 3] < 8] = 0
    image = Image.fromarray(rgba)
    image = image.crop(image.getbbox())
    if mirror:
        image = image.transpose(Image.FLIP_LEFT_RIGHT)
    scale = min(1.0, max_side / max(image.size))
    image = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    padded = Image.new("RGBA", (image.width + 4, image.height + 4), (0, 0, 0, 0))
    padded.alpha_composite(image, (2, 2))
    (OUT / "props").mkdir(parents=True, exist_ok=True)
    padded.save(OUT / "props" / out_name, optimize=True)


def _recolor_card_backs(rgba: np.ndarray) -> np.ndarray:
    rgb = rgba[..., :3].astype(np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    blueness = np.clip((b - np.maximum(r, g) - 12.0) / 40.0, 0.0, 1.0)
    blueness *= rgba[..., 3] > 0
    lum = rgb.mean(axis=2, keepdims=True)
    tinted = np.clip(BURGUNDY * (lum / 95.0) * 1.35, 0, 255)
    out = rgba.copy().astype(np.float32)
    out[..., :3] = rgb * (1.0 - blueness[..., None]) + tinted * blueness[..., None]
    return np.clip(out, 0, 255).astype(np.uint8)


def _hands_overlay(rgba: np.ndarray, painted: np.ndarray) -> np.ndarray:
    """`rgba` is the original master (used to classify), `painted` the recoloured one."""
    rgb = rgba[..., :3].astype(np.int32)
    alpha = rgba[..., 3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    height = rgba.shape[0]
    rows = np.arange(height)[:, None]
    trousers = (np.max(rgb, axis=2) < 72) & ((np.max(rgb, axis=2) - np.min(rgb, axis=2)) < 34)
    vest = (r > 40) & (g < 48) & (r > g * 2.0) & (r > b * 1.3) & (rows < RAIL_SOURCE_Y + 90)
    # Warm rim light along the trouser silhouette is dim and hugs the alpha edge.
    near_edge = cv2.erode((alpha > 24).astype(np.uint8), np.ones((17, 17), np.uint8)) == 0
    rim = near_edge & (np.max(rgb, axis=2) < 130)
    keep = (alpha > 24) & ~trousers & ~rim & ~vest & (rows >= RAIL_SOURCE_Y - RAIL_FEATHER)
    mask = keep.astype(np.uint8) * 255
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    cleaned = np.zeros_like(mask)
    for label in range(1, count):
        component = labels == label
        # Hands, cuffs and cards are bright; trouser seams and hem shadows are not.
        if stats[label, cv2.CC_STAT_AREA] >= 1800 and rgb[component].mean() > 95:
            cleaned[component] = 255
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    cleaned = cv2.GaussianBlur(cleaned, (5, 5), 0)
    ramp = np.clip((rows - (RAIL_SOURCE_Y - RAIL_FEATHER)) / (RAIL_FEATHER * 2.0), 0.0, 1.0)
    coverage = (cleaned.astype(np.float32) / 255.0) * ramp * (alpha.astype(np.float32) / 255.0)
    hands = painted.copy()
    hands[..., 3] = np.clip(coverage * 255.0, 0, 255).astype(np.uint8)
    # A flat, soft contact shadow where the hands and cards meet the felt.
    shadow_alpha = cv2.GaussianBlur((coverage * 255.0).astype(np.uint8), (0, 0), 7)
    shadow_alpha = np.roll(shadow_alpha, 12, axis=0).astype(np.float32) * 0.34
    shadow_alpha *= rows >= RAIL_SOURCE_Y
    top = hands[..., 3].astype(np.float32) / 255.0
    out_alpha = top + (shadow_alpha / 255.0) * (1.0 - top)
    safe = np.maximum(out_alpha, 1e-6)
    out = np.zeros_like(hands, dtype=np.float32)
    out[..., :3] = hands[..., :3].astype(np.float32) * (top / safe)[..., None]
    out[..., 3] = out_alpha * 255.0
    out[0, 0, 3] = out[0, -1, 3] = out[-1, 0, 3] = out[-1, -1, 3] = 0
    return np.clip(out, 0, 255).astype(np.uint8)


## Salon dealer (stylized painterly brunette, Higgsfield gpt_image_2_5, see
## docs/art/GENERATION-REPORT.md): four poses generated on one aligned 1360x2048 frame.
SALON_POSES = {
    "cards": "dealer_base_a_00078168.png",
    "deal": "dealer_deal_b791d185.png",
    "reveal": "dealer_reveal_f23948f6.png",
    "player": "dealer_player_51c62ac7.png",
}
SALON_RAIL_Y = 1215
## Source rows above the rail where the hands layer fades in (fully opaque 6 rows above it).
HANDS_LEAD = 40


def _salon_hands(rgba: np.ndarray) -> np.ndarray:
    """Hands, cuffs and held cards below the rail line; skirt and legs stay behind the table."""
    rgb = rgba[..., :3].astype(np.int32)
    alpha = rgba[..., 3]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    rows = np.arange(rgba.shape[0])[:, None]
    skin = (r > 95) & (r > g + 12) & (g > b - 6) & ((r - b) > 28)
    white = np.min(rgb, axis=2) > 150
    card_back = (r > 70) & (r > g * 1.6) & (rows > SALON_RAIL_Y + 25)
    # Start the hands layer well above the rail and reach full opacity before the
    # rail edge, so the occluder's top edge can never show through the forearms.
    keep = (alpha > 24) & (skin | white | card_back) & (rows >= SALON_RAIL_Y - HANDS_LEAD)
    mask = keep.astype(np.uint8) * 255
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    cleaned = np.zeros_like(mask)
    bottom = rgba.shape[0] - 1
    for label in range(1, count):
        top = stats[label, cv2.CC_STAT_TOP]
        height = stats[label, cv2.CC_STAT_HEIGHT]
        # Legs reach the bottom edge of the frame: they belong behind the table.
        if top + height - 1 >= bottom - 2 or stats[label, cv2.CC_STAT_AREA] < 1500:
            continue
        cleaned[labels == label] = 255
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_CLOSE, np.ones((11, 11), np.uint8))
    cleaned = cv2.GaussianBlur(cleaned, (5, 5), 0)
    ramp = np.clip((rows - (SALON_RAIL_Y - HANDS_LEAD)) / (HANDS_LEAD - 6.0), 0.0, 1.0)
    coverage = (cleaned.astype(np.float32) / 255.0) * ramp * (alpha.astype(np.float32) / 255.0)
    top_alpha = coverage
    shadow = cv2.GaussianBlur((coverage * 255.0).astype(np.uint8), (0, 0), 7)
    shadow = np.roll(shadow, 12, axis=0).astype(np.float32) / 255.0 * 0.34
    shadow *= rows >= SALON_RAIL_Y
    out_alpha = top_alpha + shadow * (1.0 - top_alpha)
    safe = np.maximum(out_alpha, 1e-6)
    out = np.zeros(rgba.shape, dtype=np.float32)
    out[..., :3] = rgba[..., :3].astype(np.float32) * (top_alpha / safe)[..., None]
    out[..., 3] = out_alpha * 255.0
    out[0, 0, 3] = out[0, -1, 3] = out[-1, 0, 3] = out[-1, -1, 3] = 0
    return np.clip(out, 0, 255).astype(np.uint8)


def _dealer() -> None:
    (OUT / "dealer").mkdir(parents=True, exist_ok=True)
    for pose, name in SALON_POSES.items():
        rgba = np.array(Image.open(SRC / name).convert("RGBA"))
        rgba[rgba[..., 3] < 6] = 0
        for x, y in [(0, 0), (-1, 0), (0, -1), (-1, -1)]:
            rgba[y, x] = 0
        Image.fromarray(rgba).save(OUT / "dealer" / f"blackjack_dealer_v2_salon_{pose}.png", optimize=True)
        Image.fromarray(_salon_hands(rgba)).save(
            OUT / "dealer" / f"blackjack_dealer_v2_salon_hands_{pose}.png", optimize=True
        )
        used = Image.fromarray(rgba).getbbox()
        print(pose, "used rect", used)


if __name__ == "__main__":
    _prop("card_shoe_68045eb2.png", "card_shoe_v2.png", 768, mirror=True)
    _prop("chip_stack_e7403c67.png", "chip_stack_v2.png", 512)
    _dealer()
