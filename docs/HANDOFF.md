# House Rules — session handoff

Rewritten 2026-09-20, mid-session. Everything below was checked against the
repo, not remembered. The section that is *not* finished is §5, and it says so.

---

## 1. Where the project stands

**Nine playable cabinets**, all nine reachable on a floor: Elven Court (slots),
Blackjack 21, Hexbound Vault, Ruby Roulette, Texas Hold'em, Velvet Baccarat,
Match Point, Harlequin Masquerade (cluster-pays) and **Corsair's Reach**
(crash). **Four rooms**: Main Floor, High Roller Salon, VIP Penthouse,
Manager's Office.

* GUT: **566/566**, including the million-round RTP harness per cabinet.
  Last full green run this session: 123,881 asserts, 304 s.
* `tools/check_localization.py`: passes.
* `gdformat --check` and `gdlint` over all of `src` and `tests`: pass.
* CI is green.
* `export/HouseRules.pck` **needs a rebuild** — the last recorded hash is for
  `98c0832`, which is many commits stale. See §5.

## 2. What this session changed

Pushed to `main`, in order:

| Commit | What |
|---|---|
| `f96cca5`, `7ef24cf` | README rebuilt against verified numbers and illustrated with current captures, every photo full-width |
| `3c0d8cc` | **The main menu rebuilt** as three painted chevron rows with a gold selector arrowhead, a version ticker and the play-money notice band |
| `a196ee5` | (from the user) floor screenshot removed from the README |
| `27a4ec2` | **The menu's focus ring restored**, and the reveal rewritten to animate what is on screen |
| `22d4e4e` | Six cabinet pages and SPEC.md §2 corrected to describe the build rather than the plan |

### The menu

It was a badge, a prompt panel and one settings key. It is now a list the
player walks. Two real bugs came out of photographing it:

1. **The focus ring had disappeared.** A hidden `Control` in Godot can still
   own focus. The retired settings key was hidden when the rows went in but
   left at `FOCUS_ALL`, so it took focus off the row the player was standing on
   and held it somewhere invisible. `test_ui` had been asserting that an
   invisible node is focusable; it now asserts the opposite.
2. **The reveal was animating nothing anybody sees** — kicker, rule, title,
   subtitle and prompt panel, all hidden. It now fades the background, drops
   the badge, slides the three rows in one after another, and settles the
   chrome. Those four typeset nodes are deleted, and `MENU_KICKER` and
   `MENU_SUBTITLE` with them. The subtitle still read "Three games. One
   bankroll." with nine on the floor.

`project.godot` had no `application/config/version`, so the ticker read "v" and
the developer build panel read an empty string. It says `1.0.0` now.

## 3. What was wrong when this session started

* **Velvet Baccarat was dead.** `baccarat_style.gd` defaulted a helper's colour
  to `IVORY`, which that palette does not define (it is `PEARL`). The parse
  error took down every script preloading it. One word, 13 of 17 failures.
* **CI had been failing on every push**, at `gdformat --check`: 27 files had
  drifted out of format long before this session. Behind it, `test_ui` loaded
  capture PNGs as Godot resources, which needs an import cache a fresh checkout
  does not have. Both fixed; the capture directory carries a `.gdignore` so
  Godot stops importing ~2 GB of evidence per run.
* **The Manager's Office drew the player 2.6–3.2× scale.**
  `src/nodes/character_scaler.gd` now states what an adult may measure and
  clamps to it; `tests/test_character_scale.gd` walks all four rooms at 21
  depths. It caught a second one on its first run: **the High Roller ramp was
  inverted**, so walking toward the camera made the player smaller.
* **The menu had never been photographed** — the build starts on the floor, so
  the shot named `01_menu` was the floor. `tools/capture_menu.gd` fixes that.
* **Test isolation.** Seventeen scripts wrote `Wallet.test_mode_enabled`
  directly instead of calling `set_test_mode()`, desyncing the wallet's two
  balances so every later `reset()` was a no-op.

## 4. In flight when this was written

Two background agents were mid-task. **Check `git status` before trusting
this section** — if their files are still dirty, they did not land.

1. **Selected/focus state redesign** across every cabinet. New files
   `src/ui/focus_ring.gd` and `tests/test_focus_ring.gd`, plus edits to roughly
   twenty UI scripts (baccarat, roulette, poker, match point, cluster, deck,
   help, dev menu, prompts). The cyan focus ring is mandated by `CLAUDE.md` and
   asserted by tests in several cabinets, so its **colour** must not change.
2. **Pizza-naming purge** in the crash cabinet. Corsair's Reach still carried
   Forno d'Oro names all through its code — `request_bake()`, `begin_bake()`,
   `set_bake()`, audio cues `oven_load`/`oven_burn`, and doc comments calling it
   "a crash game dressed as a pizza bake". Also `locale/en.csv`
   (`DECK_FORNO_*` → `DECK_CORSAIR_*`, `CORE_OVERCLOCK_STATE_BAKING` →
   `_RUNNING`, and so on). `src/floor/floor_room_layout.gd` mentions
   `tools/art/bake_paint_ins.py`, which is a **genuine** use of "bake" — leave it.

`locale/en.csv` is shared between that purge and the menu work: the removal of
`MENU_KICKER` and `MENU_SUBTITLE` is sitting in that file uncommitted and
should go out with the Corsair rename.

## 5. Not done

1. **Re-shoot every capture set.** This is the top of the list. The user's
   standing instruction is that the README carries **new photos only**, and
   they have twice caught old ones. The menu shot is now correct and pushed,
   and the Corsair and High Roller shots were checked by eye and are current,
   but the rest have not been re-shot since the focus-ring and pizza-purge work
   landed, and that work changes how every button looks.
2. **Rename the Corsair capture files.** `tools/capture_core_overclock.gd` has
   already been relabelled (`03_countdown`, `04_early_climb`, `05_long_climb`,
   `06_hauled_in`, `07_paid_out`, `08_crashed`, `10_auto_haul_set`,
   `11_reduced_motion_climb`) but the **PNGs on disk still carry the old
   names**, and the README links a parrot photograph at
   `core_overclock_fhd/05_long_bake.png`. Re-run the capture, `git rm` the old
   files, and update the README link in the same commit.
3. **Rebuild `export/HouseRules.pck`**, smoke-launch it from an absolute path,
   and record its SHA-256 here.
4. **`upgrade_cluster` declares `tier = 1` (HIGH_ROLLER) but stands in the VIP
   Penthouse.** Every other VIP cabinet is `tier = 2`. Nothing reads
   `CabinetDefinition.tier` to gate access, so nothing is broken, but one of the
   two is wrong and the call is the user's.
5. **The quick-bet row is not on every machine.** It is on the cabinets using
   the shared deck (Elven Court, Blackjack, Vault, Corsair, Harlequin).
   Roulette and Baccarat bet by placing chips of a chosen denomination on
   spots — `MIN/10/25/X2/X5/ALL` does not map onto that. Poker and Match Point
   have fixed stake keys. This is a design decision that has never been made.
6. **Match Point's board is the most code-drawn screen left** — 11 draw
   primitives in `src/ui/match_point/match_point_board.gd` plus 6 in its style
   file. If the "painted assets, not code-drawn UI" pass continues, that is
   where it goes next.
7. **No `LICENSE` file.** That is the user's decision, not an oversight to fix.
8. **Repository size**: ~3.15 GB tracked, ~1.94 GB assets, 718 committed
   screenshot PNGs at ~1.2 GB. Push in sections —
   `git push origin <sha>:refs/heads/main` — one push can exceed GitHub's 2 GB
   limit.

## 6. How to verify

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -s addons/gut/gut_cmdln.gd -gexit
git checkout tests/results/rtp.json   # the suite rewrites its elapsed times
python tools/check_localization.py
python -m gdtoolkit.formatter --check src tests ; python -m gdtoolkit.linter src tests
```

`-gselect=<script>.gd` runs one script; `-gtest=` does **not** narrow the run.

`gdformat`/`gdlint` are not on PATH; install `tools/requirements-dev.txt` and
run them as Python modules. `gdlintrc` waives `max-file-lines` and
`max-public-methods` with the reasoning written down — decisions, not
oversights.

Captures write an isolated `session_<pid>` folder beside their output; delete it
before committing (`rm -rf tests/results/screenshots/*/session_*`).

Art pipelines: `tools/art/prepare_corsair.py`, `prepare_harlequin.py`,
`prepare_ui_kit.py`, `build_key_art.py`, `cut_forno_hosts.py`. Captures:
`tools/capture_menu.tscn`, `capture_core_overclock.tscn`,
`capture_upgrade_cluster.tscn`, `capture_game.tscn`.

## 7. Higgsfield notes

The **locally configured** MCP server fails to connect (`CONNECTION_CLOSED`);
the **claude.ai connector** works and is what this session used.

* A reference image uses the role `image_references`, not `reference`.
* `background: "transparent"` is a request, not a guarantee — check the alpha
  and fall back to `rembg` (`isnet-general-use`) plus
  `prepare_characters.defringe()`. Pass `erode=1`, never `0`: zero divides by
  zero and takes the process down with exit `-1073741676`.
* A **local file** can be a reference without the upload widget: `media_upload`
  with `method: "upload_url"`, PUT the bytes yourself, then `media_confirm`.
  This is what kept the two approved hosts consistent across every state.
* Provenance for every generated asset belongs in
  `docs/art/GENERATION-REPORT.md`.
