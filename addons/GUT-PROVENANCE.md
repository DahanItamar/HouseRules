# GUT test dependency

Vendored `addons/gut` from https://github.com/bitwes/Gut at tag `v9.5.0`,
commit `8255c6305761754748f9fd641da5fd8f51c1708a`.
Upstream MIT license is preserved at `gut/LICENSE.md`.
Third-party code is excluded from project formatting and lint checks.

Local compatibility patch: `gut_loader.gd` reads `exclude_addons` using
`ProjectSettings.get_setting(key, true)` rather than `Object.get(key)`.
Godot 4.7.2 returned Nil through the latter and raised an error before test setup.
