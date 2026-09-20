"""Assemble the ambient-life frame runs from tools/capture_ambient.gd into GIFs.

    python tools/art/assemble_ambient_gifs.py <frames_dir> [--fps 25] [--width 960]
        [--out tests/results/screenshots/ambient]

Each sub-folder of <frames_dir> (000.png, 001.png, ...) becomes <out>/<folder>.gif.
One adaptive palette is built from a sample of the run's frames and shared by
every frame without dithering, so subtle light breathing reads as smooth change
instead of shimmering dither noise.
"""

import argparse
import pathlib

from PIL import Image


def assemble(folder: pathlib.Path, out: pathlib.Path, fps: int, width: int) -> pathlib.Path:
    frames = [Image.open(path).convert("RGB") for path in sorted(folder.glob("*.png"))]
    if not frames:
        raise SystemExit(f"No frames in {folder}")
    if frames[0].width != width:
        height = round(frames[0].height * width / frames[0].width)
        frames = [frame.resize((width, height), Image.LANCZOS) for frame in frames]
    # Shared palette from a vertical strip of sampled frames.
    samples = frames[:: max(1, len(frames) // 6)]
    strip = Image.new("RGB", (width, frames[0].height * len(samples)))
    for index, frame in enumerate(samples):
        strip.paste(frame, (0, index * frame.height))
    palette = strip.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    quantized = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    target = out / f"{folder.name}.gif"
    quantized[0].save(
        target,
        save_all=True,
        append_images=quantized[1:],
        duration=round(1000 / fps),
        loop=0,
        optimize=True,
        disposal=1,
    )
    return target


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("frames_dir", type=pathlib.Path)
    parser.add_argument("--fps", type=int, default=25)
    parser.add_argument("--width", type=int, default=960)
    parser.add_argument("--out", type=pathlib.Path, default=pathlib.Path("tests/results/screenshots/ambient"))
    arguments = parser.parse_args()
    arguments.out.mkdir(parents=True, exist_ok=True)
    for folder in sorted(path for path in arguments.frames_dir.iterdir() if path.is_dir()):
        target = assemble(folder, arguments.out, arguments.fps, arguments.width)
        print(f"GIF {target} {target.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
