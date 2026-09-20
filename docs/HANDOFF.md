# House Rules — session handoff

Rewritten 2026-09-20. Last commit on `main`: `44fa0f5 feat: cut the table games' keys
from their painted kits too`. Everything is pushed to `origin/main` and the working
tree is clean.

**The previous handoff described ~430 uncommitted paths left on disk by agents that
died with their session. That work is now committed and pushed in fourteen sections.**

---

## 1. Where the project stands

Nine playable cabinets: Elven Court (slots), Blackjack, Hexbound Vault, Ruby Roulette,
Texas Hold'em vs NPCs, Velvet Baccarat, Match Point, **Harlequin Masquerade**
(cluster-pays) and **Forno d'Oro** (crash). Four rooms: Main Floor, High Roller Salon,
VIP Penthouse, Manager's Office.

The GUT suite is **561/561 green**, including the million-round RTP harness for every
cabinet. `python tools/check_localization.py` passes. `gdformat --check` and `gdlint`
pass for every file this session touched.

## 2. What landed this session

| Commit | What |
| --- | --- |
| `e9387ce` | Wallet test-bank leak between test scripts |
| `5eeae81` | Shared cabinet deck, input glyphs, help card; **Velvet Baccarat repair** |
| `3da26c8` | Video walk atlas, per-room avatar depth, ambient life, room transitions |
| `78b73a8` | Harlequin Masquerade cabinet |
| `7cd2d1c` | Developer menu and House Level progression |
| `4dc058b` | Slot lever test made deterministic |
| `709220c` | Forno d'Oro cabinet, screen rebuilt |
| `2816b2f` | Painted deck kits for Forno and Harlequin |
| `d61e8bc` | Those kits limited to keys and medallions |
| `21b7825` | Superseded Tidewater Gold set kept for provenance |
| `4e32267` | RTP harness and perf probe cover the new cabinets |
| `d62e2e0` | Capture evidence; `walk_tmp/` ignored |
| `44fa0f5` | Table games' keys cut from their painted kits |

### Defects the user reported, and what was done

* **Velvet Baccarat was dead.** `baccarat_style.gd` defaulted a helper's colour to
  `IVORY`, which that palette does not define (it is `PEARL`). The parse error took
  down every script preloading it, so the cabinet could not be opened. One word; it
  was causing 13 of the 17 suite failures.
* **Manager's Office avatar was enormous.** A draft put him on a 2.6–3.2 scale ramp.
  He is back on the Main Floor's 1.0–1.67 ramp.
* **The Forno screen.** Rebuilt — see §3.
* **Flat, code-drawn buttons everywhere.** Every cabinet now draws its keys from its
  painted kit, including the four table games that built their own controls.

## 3. Forno d'Oro, rebuilt

Three art problems, all fixed:

* the oven was painted off to the right, so the dial and pizza floated over the
  counter attached to nothing → the backdrop is regenerated with the oven dead
  centre and the pizza bakes inside its painted arch;
* the pizza had one state, browned by a colour tint → there are nine painted stages
  derived from one hero pizza (dough ball, stretched, sauced, topped, early, melting,
  golden, deep, burnt). The countdown steps through the making; the bake walks the
  browning;
* a drawn bake curve plotted the same multiplier the dial showed → the curve is gone.

## 4. Open decisions for the user

1. **Forno d'Oro second host.** The user asked for TWO hosts, one per side, and
   approved the concept. The matched pose art is in `assets/source/layered_v2/forno/`
   (`left_*` blonde, `right_*` caramel brunette; the v2 burnt poses match emotions
   across both). **It has still not been shown to them and is not wired in.** The left
   character's skirt is very short and they were warned but have not ruled. The new
   centred backdrop has clear standing room on both sides, so the layout is ready for
   it. The single approved hostess stands on the right today.
2. **Painted panel frames for the two new kits.** Their button and medallion ship; the
   panel plates were pulled because their border drew thicker than the deck's content
   inset and clipped the balance and table limits. They need redrawing to that inset.
3. **Repository size.** Still ~2.3 GB because every 4K master, source video and capture
   set is tracked. `walk_tmp/` (≈350 MB of unreferenced frames) is now ignored, but Git
   LFS or pruning the older capture sets would cut far more. Push in sections —
   `git push origin <sha>:refs/heads/main` — because one push can exceed GitHub's 2 GB
   limit.

## 5. How to verify

```powershell
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import
& 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . -s addons/gut/gut_cmdln.gd -gexit
git checkout tests/results/rtp.json   # the suite rewrites its elapsed times
python tools/check_localization.py
python -m gdtoolkit.formatter --check src tests ; python -m gdtoolkit.linter src tests
```

`gdformat`/`gdlint` are not on PATH; install `tools/requirements-dev.txt` and run them
as Python modules. 27 files were already unformatted on `main` before this session and
were left alone; only files this session touched were formatted.

## 6. Higgsfield notes

The **locally configured** Higgsfield MCP server fails to connect (`CONNECTION_CLOSED`).
The **claude.ai connector** works and is what this session used. Account: Ultra, ~1,860
credits. `gpt_image_2_5` ~3 credits, `bytedance_image_upscale` for 4K.

* A reference image must use the role `image_references`, not `reference`.
* There is a second "boost credits" pool; when it empties, submissions fail with
  `429 not_enough_boost_credits` even though the main balance is untouched. Retry.
* The content filter rejects wording it reads as sexualised. Rephrase toward
  "elegant", "editorial", "tasteful".
* Never reproduce a real person's likeness or a copyrighted character.
* Provenance for every generated asset belongs in `docs/art/GENERATION-REPORT.md`.
