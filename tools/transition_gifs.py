"""Turn tools/capture_transitions.tscn frame folders into review GIFs.

    python tools/transition_gifs.py <frames-dir> [--fps 25] [--width 640]
        [--out tests/results/screenshots/transitions]

Each sub-folder of <frames-dir> (stairs_up, lift_down, ...) becomes one GIF,
downscaled from the 1080p capture with Lanczos. All frames of a clip share one
255-colour palette; pixels that did not change since the previous frame are
written as transparent so the GIF only stores what moved. A contact sheet of
every sixth frame is written beside it for quick review.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

TRANSPARENT = 255


def _load(folder: Path, width: int) -> list[Image.Image]:
    images: list[Image.Image] = []
    for path in sorted(folder.glob("frame_*.png")):
        with Image.open(path) as source:
            rgb = source.convert("RGB")
            height = round(rgb.height * width / rgb.width)
            images.append(rgb.resize((width, height), Image.Resampling.LANCZOS))
    return images


def _shared_palette(images: list[Image.Image]) -> Image.Image:
    # A strip of every fourth frame covers both rooms and the overlay colours.
    picks = images[::4]
    strip = Image.new("RGB", (images[0].width, images[0].height * len(picks)))
    for index, image in enumerate(picks):
        strip.paste(image, (0, index * image.height))
    return strip.quantize(colors=TRANSPARENT, method=Image.Quantize.MEDIANCUT)


def build(folder: Path, out: Path, fps: int, width: int) -> None:
    images = _load(folder, width)
    if not images:
        return
    palette = _shared_palette(images)
    indexed = [
        np.array(image.quantize(palette=palette, dither=Image.Dither.NONE)) for image in images
    ]
    frames: list[Image.Image] = []
    for index, pixels in enumerate(indexed):
        delta = pixels.copy()
        if index > 0:
            delta[pixels == indexed[index - 1]] = TRANSPARENT
        frame = Image.fromarray(delta, mode="P")
        frame.putpalette(palette.getpalette())
        frames.append(frame)
    target = out / f"{folder.name}.gif"
    frames[0].save(
        target,
        save_all=True,
        append_images=frames[1:],
        duration=round(1000 / fps),
        loop=0,
        transparency=TRANSPARENT,
        disposal=1,
        optimize=False,
    )
    picks = images[::6]
    thumb_w = 320
    thumb_h = round(images[0].height * thumb_w / width)
    columns = 4
    rows = (len(picks) + columns - 1) // columns
    sheet = Image.new("RGB", (thumb_w * columns, thumb_h * rows), (12, 10, 12))
    for index, image in enumerate(picks):
        sheet.paste(
            image.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS),
            ((index % columns) * thumb_w, (index // columns) * thumb_h),
        )
    sheet.save(out / f"{folder.name}_sheet.png")
    print(f"{target} frames={len(images)} bytes={target.stat().st_size}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("frames", type=Path)
    parser.add_argument("--fps", type=int, default=25)
    parser.add_argument("--width", type=int, default=640)
    parser.add_argument("--out", type=Path, default=Path("tests/results/screenshots/transitions"))
    arguments = parser.parse_args()
    arguments.out.mkdir(parents=True, exist_ok=True)
    for folder in sorted(path for path in arguments.frames.iterdir() if path.is_dir()):
        build(folder, arguments.out, arguments.fps, arguments.width)


if __name__ == "__main__":
    main()
