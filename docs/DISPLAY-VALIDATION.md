# Display Validation

House Rules uses a 960×540 logical coordinate system while Godot renders canvas
items directly at the output resolution. The resizable window preserves 16:9,
uses fractional scaling and opts into native high-DPI pixels. Dynamic fonts use
oversampling and MSDF; production raster art uses linear filtering and mipmaps.

| Target | Logical scale | Presented game area | Validation |
| --- | ---: | ---: | --- |
| 1920×1080 FHD / ROG Ally X | 2× | 1920×1080 | Exact engine capture committed |
| 2560×1440 QHD (“2K”) | 2.667× | 2560×1440 | Exact fullscreen engine capture committed |
| 3840×2160 4K UHD | 4× | 3840×2160 | Configuration and aspect tests pass; physical-panel capture pending |

Evidence lives in `tests/results/screenshots/fhd/03_slot_idle.png` and
`tests/results/screenshots/qhd_exact/03_slot_idle.png`. Tests assert their exact
pixel dimensions. The 4K target uses the same native `canvas_items` path and 4×
scale, but the current 2560×1440 monitor cannot produce an honest physical 4K
capture, so the repository does not mislabel an upscaled or clamped image as 4K.

The previous integer-only viewport enlarged one 960×540 frame and forced QHD
into a 1920×1080 letterboxed area. The current configuration draws UI, fonts and
high-resolution art at the output resolution while retaining stable logical
interaction coordinates.

Before release on new hardware, verify edge coverage, safe margins, controller
glyph readability and Windows DPI scaling at 100%, 125% and 150%. The final 4K
physical-device pass should capture menu, floor and all three games on a genuine
3840×2160 output.
