# House Rules — session handoff

Rewritten 2026-09-20 at the end of the session. Everything below was checked
against the repo, not remembered.

---

## 1. Where the project stands

**Nine playable cabinets**, all nine now reachable on a floor: Elven Court
(slots), Blackjack, Hexbound Vault, Ruby Roulette, Texas Hold'em, Velvet
Baccarat, Match Point, Harlequin Masquerade (cluster-pays) and **Corsair's
Reach** (crash). **Four rooms**: Main Floor, High Roller Salon, VIP Penthouse,
Manager's Office.

* GUT: **566/566**, including the million-round RTP harness per cabinet.
* `tools/check_localization.py`: passes (618 keys, 444 referenced).
* `gdformat --check` and `gdlint` over **all** of `src` and `tests`: pass.
* **CI is green.** It had been red on every push for a long time; see §3.
* `export/HouseRules.pck` rebuilt, 400.1 MB, smoke-launched from an absolute
  path and left running cleanly.
  SHA-256 `3ad52d4be9c7400fc879f0124737ab32ce864aa36e14f78bb3b46e14d111d362`
  (rebuild after any commit — that hash is for `98c0832`).

## 2. The crash cabinet is now Corsair's Reach

The `core_overclock` id, its maths and its verified 97% return are unchanged.
Everything the player sees was replaced twice: first as Forno d'Oro (a pizza
bake), then re-themed to pirates at the user's request.

A parrot climbs an exponential curve inside a painted chart frame and the
glowing trail is drawn live behind her. There is no ship, no water and no dial:
a crash game is one object climbing a line, and anything else on the canvas
competes with the number, which is set as bare type over the chart. Two crew
stand in narrow lanes either side, one painted frame per state so their reaction
is shared by construction.

`growth_per_second` went 0.40 → 0.12, so 2× takes 5.8 s instead of 1.7 s. That
does not touch the return — the end point is drawn before she leaves — it only
decides how long you hold your nerve, and it is what makes the wing beat read as
flight instead of a vibrating sprite.

Every Forno asset is deleted, including the deck kit, the icon and the sprite
sheets the bursts were still reading from.

## 3. What was wrong when this session started

* **Velvet Baccarat was dead.** `baccarat_style.gd` defaulted a helper's colour
  to `IVORY`, which that palette does not define (it is `PEARL`). The parse
  error took down every script preloading it. One word, 13 of 17 suite failures.
* **CI had been failing on every push**, at `gdformat --check`: 27 files had
  drifted out of format, long before this session. Then a second failure behind
  it — `test_ui` loaded capture PNGs as Godot resources, which needs an import
  cache a fresh checkout does not have. Both fixed; the capture directory now
  carries a `.gdignore` so Godot stops importing ~2 GB of evidence per run.
* **The Manager's Office drew the player 2.6–3.2× scale**, a third of the screen
  tall. `src/nodes/character_scaler.gd` now states what an adult may measure and
  clamps to it, and `tests/test_character_scale.gd` walks all four rooms at 21
  depths. It caught a second one on its first run: **the High Roller ramp was
  inverted** (1.85 far, 1.75 near), so walking toward the camera made the player
  smaller.
* **The menu had never been photographed** — the build starts on the floor, so
  the shot `capture_game.gd` calls `01_menu` is the floor. `tools/capture_menu.gd`
  fixes that, and it immediately showed the hall plate was not rendering at all:
  a TextureRect adopts its texture's size the moment you assign it, so a 3840 px
  master made the node 3840 wide.
* **Test isolation.** Seventeen scripts wrote `Wallet.test_mode_enabled`
  directly instead of calling `set_test_mode()`, desyncing the wallet's two
  balances so every later `reset()` was a no-op. Two lever tests and one room
  transition measured wall-clock time and failed under load.

## 4. Open, and honestly open

1. **The selected/focus button design.** The user says it looks bad. The cyan
   focus ring is mandated by `CLAUDE.md` and asserted by tests in several
   cabinets, so changing its colour is a design-system decision, not a tweak.
   The painted *selected* plates exist and are unused:
   `assets/production/ui/kit/menu_key_hover.png`, and the chevron pair and
   selector arrow in `assets/source/layered_v2/branding/`.
2. **The AAA menu list.** Chevron plates, selector arrow, version ticker and
   bottom notice bar are generated and not wired. The menu today is the badge, a
   prompt panel and one painted key.
3. **README photos.** The README was rewritten against verified numbers
   (`c2d702a`) but illustrated with older committed captures, because the new
   menu and Corsair shots were untracked at the time. They are tracked now and
   should replace them, sized uniformly as the user asked.
4. **The quick-bet row is not on every machine.** It is on the three cabinets
   that use the shared deck (Elven Court/Blackjack/Vault via `cabinet_panel`,
   Corsair, Harlequin). Roulette and Baccarat bet by placing chips of a chosen
   denomination on spots — a `MIN/10/25/X2/X5/ALL` row does not map onto that
   model. Poker and Match Point have fixed stake keys instead. This is a design
   decision that has never actually been made, and the original handoff assumed
   it was mechanical.
5. **Repository size.** ~3.2 GB tracked, ~2.2 GB of it assets and ~947 MB of
   screenshots. `walk_tmp/` (≈350 MB) is ignored and the Forno set is deleted,
   but Git LFS or pruning old capture sets would cut far more. Push in sections
   — `git push origin <sha>:refs/heads/main` — one push can exceed GitHub's 2 GB
   limit.
6. **Stale docs the README agent found.** `docs/SPEC.md` §2 still says v1 is
   "three playable machines" and that the High Roller and VIP rooms are "empty
   and unreachable"; `docs/cabinets/baccarat.md` and `match_point.md` say floor
   placement is pending when both are seated. There is no `LICENSE` file.

## 5. How to verify

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -s addons/gut/gut_cmdln.gd -gexit
git checkout tests/results/rtp.json   # the suite rewrites its elapsed times
python tools/check_localization.py
python -m gdtoolkit.formatter --check src tests ; python -m gdtoolkit.linter src tests
```

`gdformat`/`gdlint` are not on PATH; install `tools/requirements-dev.txt` and run
them as Python modules. `gdlintrc` waives `max-file-lines` and
`max-public-methods` with the reasoning written down — those are decisions, not
oversights.

Art pipelines: `tools/art/prepare_corsair.py`, `prepare_harlequin.py`,
`prepare_ui_kit.py`, `build_key_art.py`, `cut_forno_hosts.py` (rembg
segmentation for opaque character renders). Captures:
`tools/capture_menu.tscn`, `capture_core_overclock.tscn`,
`capture_upgrade_cluster.tscn`, `capture_game.tscn`.

## 6. Higgsfield notes

The **locally configured** MCP server fails to connect (`CONNECTION_CLOSED`);
the **claude.ai connector** works and is what this session used.

* A reference image uses the role `image_references`, not `reference`.
* `background: "transparent"` is a request, not a guarantee — check the alpha
  and fall back to `rembg` (`isnet-general-use`) plus
  `prepare_characters.defringe()`.
* A **local file** can be used as a reference without the upload widget:
  `media_upload` with `method: "upload_url"`, PUT the bytes yourself, then
  `media_confirm`. This is what kept the two approved hosts consistent across
  every generated state.
* Generated lettering is checked by eye before it ships; the badge in
  `assets/branding/` is generated, and `tools/art/build_key_art.py` can draw the
  same lockup from the shipped font at any size as a fallback.
* Provenance for every generated asset belongs in
  `docs/art/GENERATION-REPORT.md`.
