# Display Validation

House Rules uses a 960×540 logical coordinate system while Godot renders canvas
items directly at the output resolution. The window is resizable, preserves the
16:9 presentation, opts into native high-DPI pixels, and uses fractional scaling
with linear-filtered production art. Dynamic fonts use oversampling and MSDF so
type remains crisp instead of being enlarged from a low-resolution framebuffer.

| Target | Logical scale | Presented game area | Expected fit |
| --- | ---: | ---: | --- |
| 1920×1080 FHD / ROG Ally X | 2× | 1920×1080 | Exact |
| 2560×1440 QHD (“2K”) | 2.667× | 2560×1440 | Exact |
| 3840×2160 4K UHD | 4× | 3840×2160 | Exact |

The previous integer-only viewport enlarged a single 960×540 frame and forced
QHD into a 1920×1080 letterboxed area. `canvas_items` keeps the existing logical
interaction coordinates while drawing UI and fonts at native display resolution.

Automated tests protect the canvas-items, HiDPI, fractional-scaling, linear
filtering and font-rendering settings. Release QA must capture menu, floor and all
three cabinets at FHD, QHD and 4K, then verify edge coverage, safe margins,
controller glyph readability and Windows DPI scaling at 100%, 125% and 150%.
