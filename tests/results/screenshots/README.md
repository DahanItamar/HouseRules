# Capture evidence

These are screenshots and contact sheets produced by the tools under `tools/`,
kept as evidence that a change looked right. They are **not** game art.

The directory carries a `.gdignore`, so Godot does not import any of it. That
keeps ~2 GB of PNGs out of the import cache and out of the exported package, and
it stops a fresh checkout failing before the first test runs because an image
here has no import file yet.

Tests that need to inspect a capture read the file instead of loading it as a
resource:

```gdscript
var image := Image.load_from_file(ProjectSettings.globalize_path(path))
var digest := FileAccess.get_sha256(path)
```
