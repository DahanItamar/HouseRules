# M1 validation — 2026-09-18

Status: implementation and automated AC-001–015 checks pass; **AC-027 remains
failed for the classic slot's required million-round sample**. This is not a
production-readiness certification.

## Executed checks

- Godot 4.7.2 standard resource import completed without script errors.
- `gdformat --check src tests`: 33 files unchanged; pass.
- `gdlint src tests`: no problems; pass.
- GUT 9.5.0: **20 tests, 19 passing, 1 failing; 954/955 assertions**. The sole
  failure is the strict slot RTP tolerance. Process exit status is 1.
- The suite ran locally on Windows using the installed Godot binary. A GitHub
  Actions workflow is provided, but **no remote CI run was performed**.
- After the final router/prompt change, the six session tests were rerun:
  **6/6 passing, 52 assertions**, without runtime errors.
- A source scan found no HTTP, WebSocket, ENet, TCP/UDP client/server or external
  shell-link APIs in `src/`. This is static evidence, not a network packet capture.

The full run is recorded in [gut-output.txt](../tests/results/gut-output.txt).
Dependency provenance and the required Godot compatibility patch are recorded
in [GUT-PROVENANCE.md](../addons/GUT-PROVENANCE.md).

## AC-001–015 evidence

| AC | Automated observation | Result |
| --- | --- | --- |
| 001 | Avatar displacement has equal length in all eight directions. | PASS |
| 002 | Approaching a shipped cabinet selects it and shows its named prompt. | PASS |
| 003 | Interact creates a real cabinet session through SceneRouter. | PASS |
| 004 | Below minimum stake, unavailable text is displayed and entry is refused. | PASS |
| 005 | Session context contains balance, shipped bet limits and named RNG stream. | PASS |
| 006 | Real slot reports a RoundResult signal; balance is unchanged until settlement. | PASS |
| 007 | Session applies stake and payout together, and rejects duplicate settlement. | PASS |
| 008 | Exit returns to the floor at the recorded avatar position. | PASS |
| 009 | Exiting during spin resolves ABANDONED once, forfeits stake and saves. | PASS |
| 010 | Wallet results remain integer typed; invalid negative requests are rejected. | PASS |
| 011 | Insufficient funds emit rejection and preserve the balance. | PASS |
| 012 | A balance change emits the exact previous/current values once. | PASS |
| 013 | Named streams are stable; drawing one does not perturb another. | PASS |
| 014 | Equal seeds and input sequences reproduce all three cabinets' domain outcomes. | PASS |
| 015 | Cabinet exit and menu return persist state, verified by reading it back. | PASS |

These checks live in `tests/test_session.gd`, `tests/test_services.gd` and
`tests/test_domain.gd`. Additional regression tests exercise actual back-action
dispatch, zero-byte and malformed nested saves, schema migration, newer-version
refusal, atomic replacement, blackjack naturals/doubling/soft 17, mine placement,
cashout/bust/cap behavior and exhaustive slot symbol combinations.

Headless evidence does not certify physical gamepad use, 7-inch handheld
readability, full rendered animation or power-loss/crash behavior. Those require
the later device and manual verification passes.

## RTP evidence and unresolved acceptance

Seed **20260918** was chosen before measurement. Each cabinet executed one million
rounds through its shipped domain math and resources. Stakes and payouts are
summed as integer chips. The paytables and seed were not changed after observing
the result.

| Cabinet | Observed RTP | Target | Absolute error | AC-027 |
| --- | ---: | ---: | ---: | --- |
| Classic slot | 92.8342% | 95.5% | 2.6658 percentage points | **FAIL** |
| Blackjack | 99.0051888518% | 99.0% | 0.0051888518 percentage points | PASS |
| Minefield Vault | 96.39864% | 97.0% | 0.60136 percentage points | PASS |

[rtp.json](../tests/results/rtp.json) contains the sample sizes, stakes, payouts,
strategies and elapsed time. Blackjack uses the specified basic strategy with
10-chip starting stakes and includes doubles in total money wagered. Minefield
uses legal 25-chip stakes, 3 mines and a fixed 3-safe-reveal cashout rule. Integer
rounding and the payout cap mean the continuous 97% formula does not apply exactly
to every legal stake/strategy combination.

Exact slot enumeration yields **95.39794921875%**. Its 500× jackpot produces a
million-round standard error of approximately **0.9166 percentage points**. The
failing sample is about 2.80 standard errors below expectation. This explains why
the fixed ±1-percentage-point gate is unreliable for that sample size; it does
not turn the failed criterion into a pass.

A predeclared supplemental ten-million-round run at the same seed measured
**94.98781%**, including 2,376 jackpots. The result is retained in
[slot_diagnostic.json](../tests/results/slot_diagnostic.json). It supports the
sampling-variance diagnosis and **does not supersede the original failed test**.
The strict test and CI remain blocking until a specification decision changes
sample size or adopts an appropriate statistical criterion.
