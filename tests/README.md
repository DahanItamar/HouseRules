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
| AC-009 | Mid-spin Back opens a stake-at-risk confirmation; confirmed exit emits ABANDONED once, forfeits stake, saves, and ignores late resolution. |
| AC-010 | Wallet and round amounts remain integer typed; negative requests rejected. |
| AC-011 | Unfunded transaction leaves balance unchanged and emits rejection. |
| AC-012 | Balance change signal includes exact previous/current values once. |
| AC-013 | Drawing another named RNG stream cannot perturb a cabinet stream. |
| AC-014 | Identical seeds and inputs reproduce all three domain results. |
| AC-015 | Leaving cabinet and returning to menu both persist state through real storage. |
| AC-016–022 | Save replacement, schema, migration, corrupt/zero-byte preservation, future-version refusal through LocalPlatform. |
| AC-024 | A losing slot round completes a participation contract and grants its flat reward; progress survives save/load. |
| AC-027 | Strict million-round test for each cabinet; all three shipped samples pass. |
| AC-028–036 | Exhaustive slot paytable, blackjack naturals/soft 17/double, fixed unique mines, cashout, bust and cap. |
| AC-037 | Every gameplay action has its documented gamepad button; movement also has D-pad and left-stick bindings. |
| AC-038 | Raw device changes swap glyphs and synchronously refresh a live floor prompt in both directions. |
| AC-039 | Physical D-pad and left-stick events move the reusable wrapping snap cursor. |
| AC-040 | Native canvas rendering is verified at exact FHD and QHD output sizes; 4K configuration/aspect coverage is automated. |
| AC-042 | Runtime labels meet the 8px body floor; chips, stake and multiplier meet the 16px critical floor. |
| AC-043 | CI validates every translation reference and rejects literal text assigned to UI or scene text sinks. |
| M5 audio | Deterministic 16-bit PCM cues are cached and emitted for navigation and cabinet events. |
| AC-037 disconnect | Losing the active gamepad pauses behind a blocking overlay; reconnecting resumes it. |
| AC-051 | Both v1 wing transition points show their lifetime-wagered thresholds and refuse entry while locked. |

The input regression injects a real `InputEventAction` and verifies cabinet back
does not also trigger menu exit. Physical controller use, handheld readability,
rendered animation and crash/power-loss behavior are **not certified** by these
headless tests.

## Measured RTP

All three runs use seed **20260918**, declared before measurement, and the shipped
resources and math. The seed was not changed. The slot paytable was deliberately
retuned after the original high-variance distribution failed this gate: its exact
RTP and 500× maximum were preserved while return moved toward frequent outcomes.
`results/rtp.json` records one million rounds per cabinet:

| Cabinet | Observed | Declared | Strict ±1 percentage point gate |
| --- | ---: | ---: | --- |
| Classic slot | 95.5083% | 95.5% | PASS |
| Blackjack | 99.0051888518% | 99.0% | PASS |
| Minefield | 96.39864% | 97.0% | PASS |

Blackjack uses the specified basic strategy, 10-chip base stakes, and includes
doubled stakes in the denominator. Minefield uses legal 25-chip stakes, 3 mines,
and cashes out after the first 3 safe tile indices. Integer payout rounding lowers
its expectation relative to the continuous 97% formula; this sample is not proof
that every legal mine count/stake/cashout combination attains 97%.

Exact enumeration of the 31-stop slot gives RTP **95.4952838105468%**. Its
single-stop 500× jackpot remains the maximum win, while a 3× two-cherry return
carries more of the expectation. Payout-multiplier variance is now
**14.8194940320**, giving a one-million-round standard error of about **0.3850
percentage points**. The fixed acceptance gate therefore passes without changing
the declared target, maximum win, seed or sample size.
