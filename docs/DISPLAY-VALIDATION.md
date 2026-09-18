# Display Validation

House Rules renders to a fixed 960×540 base viewport with nearest-neighbor
textures and integer-only viewport scaling. The window is resizable, preserves
aspect ratio, and opts into native high-DPI pixels. This keeps cabinet art and
text edges sharp instead of introducing fractional filtering.

| Target | Integer scale | Presented game area | Expected fit |
| --- | ---: | ---: | --- |
| 1920×1080 FHD / ROG Ally X | 2× | 1920×1080 | Exact |
| 2048×1080 DCI 2K | 2× | 1920×1080 | 64px side bars |
| 2560×1440 QHD (“2K”) | 2× | 1920×1080 | 320px side and 180px top/bottom bars |
| 3840×2160 4K UHD | 4× | 3840×2160 | Exact |

The QHD bars are intentional: 2560×1440 is not an integer multiple of 960×540.
Filling that panel would require fractional 2.666…× scaling and visibly uneven
pixel sizes. A future high-resolution UI mode may add a separate 1280×720 base;
the MVP favors consistent sharp pixels and predictable interaction geometry.

Automated tests protect the project settings, scale calculation, and the
960×540 dimensions of rendered slot, blackjack, and vault reference captures.
Release QA should still launch the exported Windows build on each physical
display class and verify OS DPI scaling, fullscreen behavior, safe margins, and
controller glyph readability.
