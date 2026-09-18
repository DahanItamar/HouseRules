# Motion Integration

The five Higgsfield Seedance MP4 files in `assets/source/animations/` are the
motion-reference masters and provenance artifacts for the M5 animation pass.
They are intentionally not shipped as runtime video: Godot 4 core does not
decode MP4, and generated video frames do not share the registered origins
required by crisp pixel sprites.

The playable build translates those references into deterministic native
tweens over the accepted still assets:

- cabinet art fades and settles into place on entry;
- slot symbols bounce rapidly during the reel timer and snap to the result;
- blackjack's card back slides from the dealer toward the table;
- the vault snap cursor pulses continuously and newly revealed tiles fade in;
- every settled result flashes the cabinet frame in chip gold.

Native motion freezes with the scene tree on controller disconnect, preserves
gameplay state, and renders at the same 960×540 pixel base as the still art.
The generated MP4s may later be frame-extracted and hand-registered, but they
are not a runtime dependency of the MVP.
