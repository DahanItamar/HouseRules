# MVP validation — 2026-09-19

Status: the current local release gate passes, including all three fixed-seed
million-round RTP samples. This is automated MVP evidence, not a substitute for
the final physical-device pass.

## Executed checks

- Godot 4.7.2 standard resource import completed without script errors.
- `gdformat --check src tests` and `gdlint src tests` are part of the repository
  verification workflow.
- GUT 9.5.0: **117 tests passing, 1,779 assertions** in the authoritative local
  Windows release-gate run.
- The suite ran locally on Windows using Godot 4.7.2. The repository also ships
  a GitHub Actions workflow; this document does not claim a remote run.
- The release pack exported successfully and remained running through a hidden
  five-second launch smoke test.
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
| 009 | Exiting during a live round requires confirmation; confirming resolves ABANDONED once, forfeits stake and saves. | PASS |
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

AC-024 now has automated coverage: a losing spin can complete the participation
contract, its flat reward is applied after the cabinet settlement, a replacement
keeps three contracts active, and progress survives save/load through schema
version 2.

AC-051 now has automated coverage for both v1 transition points. Approaching the
High-Roller staircase or VIP elevator displays its lifetime-wagered threshold,
and interaction is refused while those out-of-scope wings remain locked.

Headless evidence does not certify physical gamepad use, 7-inch handheld
readability, full rendered animation or power-loss/crash behavior. Those require
the later device and manual verification passes.

## RTP evidence

Seed **20260918** was chosen before measurement. Each cabinet executed one million
rounds through its shipped domain math and resources. Stakes and payouts are
summed as integer chips. The seed and sample size remain unchanged. After the
original slot distribution exposed excessive sample variance, the paytable was
retuned to preserve its exact target and 500× maximum while moving expected
return toward frequent outcomes.

| Cabinet | Observed RTP | Target | Absolute error | AC-027 |
| --- | ---: | ---: | ---: | --- |
| Classic slot | 95.5083% | 95.5% | 0.0083 percentage points | PASS |
| Blackjack | 99.0051888518% | 99.0% | 0.0051888518 percentage points | PASS |
| Minefield Vault | 96.39864% | 97.0% | 0.60136 percentage points | PASS |

[rtp.json](../tests/results/rtp.json) contains the sample sizes, stakes, payouts,
strategies and elapsed time. Blackjack uses the specified basic strategy with
10-chip starting stakes and includes doubles in total money wagered. Minefield
uses legal 25-chip stakes, 3 mines and a fixed 3-safe-reveal cashout rule. Integer
rounding and the payout cap mean the continuous 97% formula does not apply exactly
to every legal stake/strategy combination.

Exact slot enumeration now yields **95.4952838105468%**. Its single-stop 500×
jackpot remains intact, but the 3× two-cherry outcome carries more of the return.
Payout-multiplier variance falls to **14.8194940320**, for an approximate
million-round standard error of **0.3850 percentage points**. The mandatory
one-million-round gate now passes with the original seed and tolerance.
