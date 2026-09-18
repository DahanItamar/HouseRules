# Verification

Use Godot **4.7.2 standard** and Python with `tools/requirements-dev.txt` installed.

```text
gdformat --check src tests
gdlint src tests
godot --headless --editor --path . --quit
python tools/check_localization.py
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
godot --headless --path . -s tests/slot_rtp_diagnostic.gd
```

`godot` means the pinned executable; on this workstation use
`C:/Godot/Godot_v4.7.2-stable_win64_console.exe`.
GUT is vendored at version 9.5.0; see `addons/GUT-PROVENANCE.md` for its source,
license, commit and one compatibility patch. Test saves use unique `user://tests/`
directories; they do not overwrite the player's normal save.

## Acceptance coverage

| Criteria | Automated evidence |
| --- | --- |
| AC-001 | Equal displacement for all eight movement directions. |
| AC-002 | Approach a shipped cabinet; verify selected definition and visible named prompt. |
| AC-003 | Interact at the cabinet; a live session is installed by the router. |
| AC-004 | Below minimum bet, unavailable prompt and refused interaction. |
| AC-005 | Context carries current balance, shipped limits definition and named stream. |
| AC-006 | Real slot emits one RoundResult; wallet unchanged before settlement. |
| AC-007 | Stake and payout settle together; replaying the same result is rejected. |
| AC-008 | Exit restores the recorded floor position. |
| AC-009 | Mid-spin exit emits ABANDONED once, forfeits stake, saves, ignores late timer resolution. |
| AC-010 | Wallet and round amounts remain integer typed; negative requests rejected. |
| AC-011 | Unfunded transaction leaves balance unchanged and emits rejection. |
| AC-012 | Balance change signal includes exact previous/current values once. |
| AC-013 | Drawing another named RNG stream cannot perturb a cabinet stream. |
| AC-014 | Identical seeds and inputs reproduce all three domain results. |
| AC-015 | Leaving cabinet and returning to menu both persist state through real storage. |
| AC-016–022 | Save replacement, schema, migration, corrupt/zero-byte preservation, future-version refusal through LocalPlatform. |
| AC-024 | A losing slot round completes a participation contract and grants its flat reward; progress survives save/load. |
| AC-027 | Strict million-round test for each cabinet; current slot sample fails. |
| AC-028–036 | Exhaustive slot paytable, blackjack naturals/soft 17/double, fixed unique mines, cashout, bust and cap. |
| AC-037 | Every gameplay action has its documented gamepad button; movement also has D-pad and left-stick bindings. |
| AC-038 | Raw device changes swap glyphs and synchronously refresh a live floor prompt in both directions. |
| AC-039 | Physical D-pad and left-stick events move the reusable wrapping snap cursor. |
| AC-040 | FHD, DCI 2K, QHD and 4K targets retain the reviewed integer scale; cabinet captures remain 960×540. |
| AC-042 | Runtime labels meet the 8px body floor; chips, stake and multiplier meet the 16px critical floor. |
| AC-043 | CI validates every translation reference and rejects literal text assigned to UI or scene text sinks. |
| AC-037 disconnect | Losing the active gamepad pauses behind a blocking overlay; reconnecting resumes it. |
| AC-051 | Both v1 wing transition points show their lifetime-wagered thresholds and refuse entry while locked. |

The input regression injects a real `InputEventAction` and verifies cabinet back
does not also trigger menu exit. Physical controller use, handheld readability,
rendered animation and crash/power-loss behavior are **not certified** by these
headless tests.

## Measured RTP and unresolved gate

All three runs use seed **20260918**, declared before measurement, and the shipped
resources and math. No seeds or paytables were changed to produce a passing run.
`results/rtp.json` records one million rounds per cabinet:

| Cabinet | Observed | Declared | Strict ±1 percentage point gate |
| --- | ---: | ---: | --- |
| Classic slot | 92.8342% | 95.5% | **FAIL** |
| Blackjack | 99.0051888518% | 99.0% | PASS |
| Minefield | 96.39864% | 97.0% | PASS |

Blackjack uses the specified basic strategy, 10-chip base stakes, and includes
doubled stakes in the denominator. Minefield uses legal 25-chip stakes, 3 mines,
and cashes out after the first 3 safe tile indices. Integer payout rounding lowers
its expectation relative to the continuous 97% formula; this sample is not proof
that every legal mine count/stake/cashout combination attains 97%.

Exact enumeration of the slot's 216 symbol combinations gives RTP
**95.39794921875%**. The 500× jackpot produces variance 84.0132629722357 in units
of stake squared, so one million rounds has standard error **0.9166 percentage
points**. The failing sample is about 2.80 standard errors below exact expectation.
A one-percentage-point gate therefore cannot reliably distinguish math defects
from this machine's sampling variation.

A separately declared ten-million-round diagnosis with the **same seed** returned
**94.98781%**, with 2,376 jackpots. `results/slot_diagnostic.json` preserves that
supplemental evidence. It **does not replace the failed million-round acceptance
test**. CI remains blocking/red for AC-027 pending an explicit specification
decision about sample size or a variance-aware statistical criterion.
