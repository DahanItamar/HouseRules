"""Build the reusable House Rules card deck from the Higgsfield source generations.

Run from the repository root:  python assets/source/layered_v2/cards/prepare_cards.py

Never overwrites a source generation. Outputs under assets/production/cards/:
  card_face.png          ivory card stock (poker proportion 63:88, rounded alpha corners)
  card_back.png          ornate burgundy/brass back, made exactly point-symmetric
  suit_<name>.png        spade / heart / diamond / club pip art (square, transparent)
  ace_spades.png         ornate ace-of-spades centrepiece (transparent)
  court_<rank>_<suit>.png  double-headed court panels: the generated half plus the same
                           half rotated 180 degrees, exactly like a printed court card
Ranks and indices are drawn in code (src/ui/playing_card.gd) so every card is exact.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[4]
SRC = ROOT / "assets/source/layered_v2/cards"
BLACKJACK_SRC = ROOT / "assets/source/layered_v2/blackjack"
OUT = ROOT / "assets/production/cards"

CARD_SIZE = (730, 1024)  # 63 x 88 mm poker proportion
CORNER_RADIUS = 44
SUIT_NAMES = ["spade", "heart", "diamond", "club"]
COURTS = {
    ("K", "spade"): "court_K_spades_77cbb1a3.png",
    ("Q", "spade"): "court_Q_spades_edb63c23.png",
    ("J", "spade"): "court_J_spades_d6bff1f4.png",
    ("K", "heart"): "court_K_hearts_54db661d.png",
    ("Q", "heart"): "court_Q_hearts_ec95a5d1.png",
    ("J", "heart"): "court_J_hearts_8bfa84be.png",
    ("K", "diamond"): "court_K_diamonds_5b18c996.png",
    ("Q", "diamond"): "court_Q_diamonds_d5a7e1ff.png",
    ("J", "diamond"): "court_J_diamonds_a611b0c5.png",
    ("K", "club"): "court_K_clubs_2e6eab3d.png",
    ("Q", "club"): "court_Q_clubs_e8e8582f.png",
    ("J", "club"): "court_J_clubs_1837fd84.png",
}
COURT_HALF = (600, 452)


def _rounded(image: Image.Image, radius: int = CORNER_RADIUS) -> Image.Image:
    mask = Image.new("L", (image.width * 4, image.height * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, mask.width - 1, mask.height - 1), radius=radius * 4, fill=255
    )
    mask = mask.resize(image.size, Image.LANCZOS)
    out = image.convert("RGBA")
    alpha = np.minimum(np.array(out)[..., 3], np.array(mask))
    out.putalpha(Image.fromarray(alpha))
    return out


def _face() -> None:
    # Ivory stock sampled from the interior of the generated face template (inside its
    # brass hairlines), so the paper grain is painted rather than flat.
    template = Image.open(BLACKJACK_SRC / "card_face_c62dd28a.png").convert("RGB")
    inner = template.crop((150, 170, 1210, 1878))
    _rounded(inner.resize(CARD_SIZE, Image.LANCZOS)).save(OUT / "card_face.png", optimize=True)


def _back() -> None:
    back = Image.open(SRC / "back_627d91d2.png").convert("RGB")
    back = back.resize(CARD_SIZE, Image.LANCZOS)
    rgb = np.array(back)
    half = CARD_SIZE[1] // 2
    # Exact point symmetry, as on a printed back: the lower half is the upper half
    # rotated 180 degrees.
    rgb[CARD_SIZE[1] - half:] = np.rot90(rgb[:half], 2)
    _rounded(Image.fromarray(rgb)).save(OUT / "card_back.png", optimize=True)


def _trim(image: Image.Image, pad: int = 6) -> Image.Image:
    rgba = np.array(image.convert("RGBA"))
    rgba[rgba[..., 3] < 10] = 0
    image = Image.fromarray(rgba)
    image = image.crop(image.getbbox())
    side = max(image.size) + pad * 2
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.alpha_composite(image, ((side - image.width) // 2, (side - image.height) // 2))
    return square


def _suits() -> None:
    sheet = Image.open(SRC / "suits_8533fe4e.png").convert("RGBA")
    half = sheet.width // 2
    quadrants = [(0, 0), (half, 0), (0, half), (half, half)]
    for name, (x, y) in zip(SUIT_NAMES, quadrants):
        pip = _trim(sheet.crop((x, y, x + half, y + half)))
        pip.resize((256, 256), Image.LANCZOS).save(OUT / f"suit_{name}.png", optimize=True)


def _ace() -> None:
    ace = _trim(Image.open(SRC / "ace_spades_e7fdc80d.png"), 4)
    ace.resize((768, 768), Image.LANCZOS).save(OUT / "ace_spades.png", optimize=True)


def _courts() -> None:
    for (rank, suit), name in COURTS.items():
        half = Image.open(SRC / name).convert("RGB")
        # The generated half is cut at mid-chest; below the cut the model leaves a
        # thin ivory band. Crop to the last painted row so both halves meet on the
        # figure's own dark edge line, like the rule on a printed court card.
        luma = np.array(half.convert("L")).astype(np.float32)
        centre = luma[:, half.width // 6: half.width * 5 // 6].mean(axis=1)
        bottom = half.height
        while bottom > half.height * 0.8 and centre[bottom - 1] > 200.0:
            bottom -= 1
        half = half.crop((0, 0, half.width, bottom)).resize(COURT_HALF, Image.LANCZOS)
        panel = Image.new("RGB", (COURT_HALF[0], COURT_HALF[1] * 2))
        panel.paste(half, (0, 0))
        panel.paste(half.rotate(180), (0, COURT_HALF[1]))
        panel.save(OUT / f"court_{rank}_{suit}.png", optimize=True)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    _face()
    _back()
    _suits()
    _ace()
    _courts()
    print("deck ready:", sorted(p.name for p in OUT.glob("*.png")))
