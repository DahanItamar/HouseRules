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
| Harlequin Masquerade | `test_upgrade_cluster.gd`: the 4-way connection rule with an explicit diagonal-does-not-count board, cluster detection and separation, tumble gravity and refill, seeded replay equality, the upgrade ladder's thresholds, one-rounding settlement, chip conservation through the wallet, settlement gated on the replay, the measured return, 44px/TV-safe controls, protected readout rectangles the host and the floating arithmetic can never cover, and reduced motion bounding every phase. |
| Manager's Office | `test_manager_office.gd`: UHD layers with clear alpha, walkable connected anchors, furniture edge samples, foreground depth, the Main Floor door route, room switching with one player, contracts board parity with Economy, marker parity after the move from the cashier, persisted one-time invitations, the tour (first run, action steps, skip, replay, saved state, reduced motion), the in-panel cameo facing the text, one shared colour grade per person, TV-safe 44px targets. |

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
| Ruby Roulette | 97.7191% | 97.3% (exact 36/37) | PASS |
| Match Point | 96.1322% | 96.0% (exact 39320/40960 = 95.99609375%) | PASS |
| Velvet Baccarat | 98.99387% | 98.9% (exact Banker, 20 chips: 98.9421%) | PASS |
| Harlequin Masquerade | see `results/rtp.json` | 96.6% | PASS |

Blackjack uses the specified basic strategy, 10-chip base stakes, and includes
doubled stakes in the denominator. Minefield uses legal 25-chip stakes, 3 mines,
and cashes out after the first 3 safe tile indices. Integer payout rounding lowers
its expectation relative to the continuous 97% formula; this sample is not proof
that every legal mine count/stake/cashout combination attains 97%.
Match Point drops 10 credits per round and cycles the Low, Medium and High tables;
all three return exactly 95.99609375%, and legal stakes (multiples of 10) settle
without rounding.
Velvet Baccarat puts 20 chips on Banker every coup from an eight-deck shoe shuffled
for every coup. `tests/test_baccarat.gd` enumerates every ordered deal exactly:
Banker 98.9421%, Player 98.7649%, Tie 85.6404%, each pair 89.6386%. Every chip is a
multiple of 20, so the whole-chip commission is exactly 5%.

Harlequin Masquerade (`upgrade_cluster`) plays one 10-chip board per round and lets
it tumble to the end. Its return is exactly linear in `data/paytables/upgrade_cluster.tres`,
so it was tuned by measuring a reference curve over **ten million** rounds and scaling
that one array by the ratio to the target; `tests/upgrade_cluster_rtp_diagnostic.gd`
records the confirming run in `results/upgrade_cluster_diagnostic.json`. Prices are
milli-bet integers rather than the two decimals the machine prints, because at
two-decimal granularity the four cheapest prices on the board all round down and cost
0.7 percentage points of return on their own. Payout-multiple variance is about
**13.0**, a one-million-round standard error of roughly **0.36 percentage points**,
which is why the paytable was tuned against the ten-million sample and not the gate's
own. See `docs/cabinets/upgrade_cluster.md` §6.

Exact enumeration of the 31-stop slot gives RTP **95.4952838105468%**. Its
single-stop 500× jackpot remains the maximum win, while a 3× two-cherry return
carries more of the expectation. Payout-multiplier variance is now
**14.8194940320**, giving a one-million-round standard error of about **0.3850
percentage points**. The fixed acceptance gate therefore passes without changing
the declared target, maximum win, seed or sample size.
