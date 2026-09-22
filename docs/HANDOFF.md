# House Rules — project handoff

Updated 2026-09-22 for the public repository release. Everything below was
checked against the repository.

---

## 1. Where the project stands

**Nine playable cabinets**, all nine reachable on a floor: Elven Court (slots),
Blackjack 21, Hexbound Vault, Ruby Roulette, Texas Hold'em, Velvet Baccarat,
Match Point, Harlequin Masquerade (cluster-pays) and **Corsair's Reach**
(crash). **Four rooms**: Main Floor, High Roller Salon, VIP Penthouse,
Manager's Office.

* GUT: **573/573**, 53 scripts, 124,982 assertions, including the million-round
  RTP harness per cabinet.
* `tools/check_localization.py`: passes (621 keys, 448 referenced).
* `gdformat --check` and `gdlint` over all of `src` and `tests`: pass.
* Public-release CI is green on 2026-09-22: localization, formatting, linting,
  Godot import, the full test/RTP gate, supplemental variance diagnostics, and
  evidence upload all passed.
* Canonical screenshot sets were re-shot against this runtime build.
* `export/HouseRules.pck` is 421.3 MB and was smoke-launched successfully. The
  public-repository cleanup changes only documentation, tooling, CI, and retired
  evidence, so the packaged runtime remains current.
  SHA-256 `a9eeab88a66b630197460bfe38dcfbc20b62e47e9edc0237e33cb9d978583c04`
  (rebuild after any runtime code or asset change).

### Public-release cleanup

* Replaced the development-heavy README with a player- and contributor-friendly
  overview, gallery, run instructions, controls, test contract, and AI disclosure.
* Removed obsolete builder prompt files and five superseded one-off screenshot
  batches; canonical captures and every README image remain.
* Removed the ignored 1,410-frame temporary walk dump. In total, about 640 MiB
  of tracked and local-only review output was removed from the working tree.
* Replaced workstation-specific paths with repository-relative or PATH-based
  discovery and restricted GitHub Actions to read-only repository contents.
* Scanned the current tree and all Git commits for private keys and common OpenAI,
  GitHub, AWS, Google, and Slack token formats: no credential-shaped value found.
  All commit authors use the GitHub noreply address.
* The current tracked tree has no file over GitHub's 100 MB per-file limit.

## 2. What this session did

### The main menu

It was a badge, a prompt panel and one settings key. It is now a list the
player walks: three painted chevron rows with a cyan chevron outline contained
inside the focused row, a version ticker and the play-money notice band, over
the hall.

Photographing it exposed two real bugs. **The focus ring had vanished** — a
hidden `Control` in Godot can still own focus, and the retired settings key was
hidden but left at `FOCUS_ALL`, so it took focus off the row the player was
standing on and held it somewhere invisible. `test_ui` had been asserting that
an invisible node is focusable. **The reveal was animating nothing anybody
sees** — kicker, rule, title, subtitle and prompt panel, all hidden. It now
drops the badge, slides the rows in one after another and settles the chrome.
Those four typeset nodes are deleted, and `MENU_SUBTITLE` with them; it still
read "Three games. One bankroll." with nine on the floor.

`project.godot` had no `application/config/version`, so the ticker read "v".

### One selected-state cue, everywhere

`src/ui/focus_ring.gd` is now the single definition. The colour is unchanged —
cyan is reserved by the UI design system for keyboard and controller focus — but the
line is drawn **inside** the key with no centre, so the painted plate, its
hover brightening and a toggle's selected face stay visible under it. The
corner radius is measured off each theme's button art rather than guessed.

The selected tint now stays in the SDR range instead of bleaching painted
materials. Long How to Play control labels wrap and paginate at their measured
height rather than ending in ellipses. Match Point's primary Serve key keeps
its intended cream enamel face, and focus falls back to an enabled stake key
when Serve is unavailable. Motion-sensitive tests explicitly choose full or
reduced motion, so a player's saved accessibility preference cannot make the
suite nondeterministic.

Three genuine bugs came out of that sweep: **filled focus boxes were erasing
painted keys** (a focused poker CALL lost its silver frame entirely while its
neighbours kept theirs; same in the vault keys and the exit confirmation),
**focus rings carried drop shadows**, which is the glow the house style
forbids, and **floor keys had no hover state at all** — hover and normal were
byte-identical.

Cyan is now reserved for focus alone: the stake-change flash bar went brass,
the vault cursor takes `FocusRing.COLOR` and holds at the top of its pulse
under reduced motion rather than the bottom, and two dead `CYAN` constants are
gone.

### Corsair's Reach

The art stopped being Forno d'Oro two commits before this session; the code had
not. It still called a round a bake, its methods `request_bake`/`begin_bake`,
its audio cues `oven_load` through `oven_burn`, and its own header described
"a crash game dressed as a pizza bake". **Two of those were visible to the
player**: the How to Play overlay read "Bake / Pull it out" and "Oven timer".

Then the guide itself: it still described "your galleon" and "the compass",
neither of which has existed since the parrot became the line and the dial was
replaced by bare type.

Four more things the capture pass caught:

* **The dormant readout was unreadable.** `number_color` defaulted to `INK`, a
  dark brown, and was only lit when a run began — so at anchor the biggest
  number on the canvas was dark brown on dark blue, behind the dark rim the
  bare readout draws to hold itself against moonlight.
* **The wreck landed on the crew.** Wreckage is drawn at the bird, and on an
  early break-up the bird is in the corner of the chart, so a puff 300 across
  spilled out of the frame and over the woman beside it.
* **The capture could no longer finish.** Slowing `growth_per_second` to 0.12
  made 9× take 18 s, past the 12 s ceiling on that wait.
* **The break-up was a galleon.** She is the object on the curve, so she has to
  be the thing the sea takes. It is four stages of her bursting into scarlet,
  blue and yellow macaw feathers now, and the particles are bounded to the
  chart so nothing settles on the crew.

The crew are v5: the tricorn captain stands on the right, and both women are
turned three-quarter **inward toward the board** rather than facing the player.
Each state is still **one frame holding both women**, which is the property the
cabinet depends on — their reaction is shared by construction and they can
never be caught feeling different things about the same result.
`prepare_corsair.py` splits each frame down the middle; `middle_px=0` on all
four, so neither woman reaches the chart.

### Match Point

The thirteen courts were flat rectangles filled with one of three colours, and
the serving hatch was three stroked rectangles — the last furniture in the game
drawn by the code that places it, with painted art all around it. Both are
painted plates now: brass-rimmed troughs with the drop slot painted as an
opening, in three faces for the three payout bands, and a brass-framed recess
whose interior is shaded so it reads as depth.

Three plates rather than one tinted three ways, because a brass edge and a
green centre are different materials. The face of each is deliberately plain:
the multiplier changes with the risk setting, so it is still drawn over the top.

What the board still draws in code is state, not material — the studs the ball
touched, the ring on the court that took it, the ball's shadow. Those change
every drop and belong there. `court_fill` also survives for the result plaque,
whose cells are too small for a plate to show anything but its rim.

### Captures

`tools/capture_all.ps1` re-shoots every set in one pass, reports the shot count
per set, fails on a `SCRIPT ERROR` or an empty set, and deletes the
`session_<pid>` save sandboxes the tools leave behind. It exists because there
was no single way to refresh the evidence, so sets drifted at different rates
and old photographs kept surviving into the README — twice the user had to
point at one. Run it after any change to the UI, the floors or the cabinet art.

The eight Forno-era Corsair filenames are gone; `05_long_bake.png` held a
photograph of a parrot and the README linked it under that name.

## 3. What was wrong when this session started

* **Velvet Baccarat was dead.** `baccarat_style.gd` defaulted a helper's colour
  to `IVORY`, which that palette does not define (it is `PEARL`). The parse
  error took down every script preloading it. One word, 13 of 17 failures.
* **CI had been failing on every push**, at `gdformat --check`: 27 files had
  drifted out of format long before this session. Behind it, `test_ui` loaded
  capture PNGs as Godot resources, which needs an import cache a fresh checkout
  does not have.
* **The Manager's Office drew the player 2.6–3.2× scale.**
  `src/nodes/character_scaler.gd` now states what an adult may measure and
  clamps to it; `tests/test_character_scale.gd` walks all four rooms at 21
  depths. It caught a second one on its first run: **the High Roller ramp was
  inverted**, so walking toward the camera made the player smaller.
* **Test isolation.** Seventeen scripts wrote `Wallet.test_mode_enabled`
  directly instead of calling `set_test_mode()`, desyncing the wallet's two
  balances so every later `reset()` was a no-op.

## 4. Open

1. **`upgrade_cluster` declares `tier = 1` (HIGH_ROLLER) but stands in the VIP
   Penthouse.** Every other VIP cabinet is `tier = 2`. Nothing reads
   `CabinetDefinition.tier` to gate access, so nothing is broken, but one of the
   two is wrong and the call is the user's.
2. **The floor plaques say SLOTS / BLACKJACK / MINEFIELD VAULT** while the
   cabinets are branded Elven Court / Blackjack 21 / Hexbound Vault. The
   plaques are painted into the 3840 px background, so changing them is an art
   job. Arguably fine — a plaque names the game, a cabinet carries a brand —
   but it is a decision nobody has made.
3. **The quick-bet row is not on every machine.** It is on the cabinets using
   the shared deck (Elven Court, Blackjack, Vault, Corsair, Harlequin).
   Roulette and Baccarat bet by placing chips of a chosen denomination on
   spots — `MIN/10/25/X2/X5/ALL` does not map onto that. Poker and Match Point
   have fixed stake keys. This design decision has never actually been made.
4. **The bet HUD covers the crew's boots** in Corsair. The UI composition rules
   say HUD panels must not cover people. It reads as them standing behind the console,
   and it follows the wireframe the user drew, but it is worth a look.
5. **Licensing and release:** project-authored code, documentation, and original
   assets are published under MIT, with upstream notices retained separately.
   The first public release is tagged `v1.0.0`.
6. **Repository size**: the checked-out tracked tree is about **2.75 GiB** and
   packed Git history is about **3.95 GiB**, mostly high-resolution art, retained
   generation sources, and canonical visual QA. There is no individual file over
   100 MB, but a fresh clone remains substantial. A future Git LFS migration would
   require a deliberate history rewrite and storage-budget decision.

## 5. How to verify

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -s addons/gut/gut_cmdln.gd -- -gexit
git restore tests/results/rtp.json   # the suite rewrites its elapsed times
python tools/check_localization.py
python -m gdtoolkit.formatter --check src tests ; python -m gdtoolkit.linter src tests
powershell -File tools/capture_all.ps1           # every set; -Only <name> for one
```

`-gselect=<script>.gd` runs one script; `-gtest=` does **not** narrow the run.

`gdformat`/`gdlint` are not on PATH; install `tools/requirements-dev.txt` and
run them as Python modules. `gdlintrc` waives `max-file-lines` and
`max-public-methods` with the reasoning written down — decisions, not
oversights.

Art pipelines: `tools/art/prepare_corsair.py`, `cut_corsair_crew.py` (rembg
segmentation — the generator paints a checkerboard where it is asked for
transparency), `prepare_harlequin.py`, `prepare_ui_kit.py`, `build_key_art.py`.

## 6. Higgsfield notes

The **locally configured** MCP server fails to connect (`CONNECTION_CLOSED`);
the **claude.ai connector** works and is what this session used.

* A reference image uses the role `image_references`, not `reference`.
* `use_unlim: true` is rejected for `gpt_image_2_5` — that model bills credits.
* `background: "transparent"` is a request, not a guarantee. `gpt_image_2_5`
  returns an RGB image with a **painted checkerboard** where the transparency
  should be, so it has to be segmented. `cut_corsair_crew.py` does that with
  rembg `isnet-general-use` and alpha matting; it reports the painted fraction
  as well as the transparent one, because a cut that eats the subject comes
  back looking like a clean transparent frame.
* `defringe` takes `erode=1`, never `0`: zero divides by zero and takes the
  process down with exit `-1073741676`.
* A **local file** can be a reference without the upload widget: `media_upload`
  with `method: "upload_url"`, PUT the bytes yourself, then `media_confirm`.
  This is what kept both women consistent across every generated state.
* Provenance for every generated asset belongs in
  `docs/art/GENERATION-REPORT.md`, including the rejected takes and why.
