# Milestone 1 implementation notes

The locked specification files remain unchanged. These notes record explicit interpretations and mathematical discrepancies discovered while implementing the shipped rules. Simulation results belong in the generated RTP report; the calculations below describe exact expectations.

## Integer payouts

Wallet balances, stakes and payouts use integer chips. Fractional gross payouts round down once, using integer rational arithmetic. This is an implementation choice where the specification does not select a rounding rule. It affects blackjack naturals at odd stakes and most Minefield cash-outs. It must not be described as preserving the unrounded theoretical RTP at every legal stake.

Save currency, cumulative statistics and RNG seeds serialize as decimal strings to avoid losing 64-bit precision through JSON number parsing. Save readers must validate and accept these strings before conversion.

## Contracts

Three Main Floor contracts are active at a time. The first rotation guarantees
one participation objective, with replacements drawn from a named deterministic
RNG stream. Progress and completion count persist in save schema version 2; the
version 1 migration initializes a fresh rotation. Contract evaluation occurs
after a round settles, so a losing round can complete an objective and its flat
reward is applied independently of the cabinet payout (AC-024).

## Classic slot

The specified strip and paytable give an exact expected return of `31,260 / 32,768 = 0.9539794921875` (95.39794921875%). The cabinet document's `0.95399` is a small arithmetic/rounding discrepancy. The declared `0.955` target remains unchanged and lies within the specified one-percentage-point simulation tolerance. The implementation uses all specified weights and multipliers without retuning.

The per-round payout variance is approximately `84.0132629722` squared stake units. At one million independent spins the standard error of measured RTP is approximately `0.009165875`, or 0.9166 percentage points. A fixed one-percentage-point tolerance is therefore a noisy statistical gate for this paytable, with roughly a 28% false-failure probability even under correct math. Exact enumeration verifies the payout expectation without sampling noise. A failing seeded simulation must remain reported as failing; changing seeds to obtain a passing result is not verification.

## Minefield Vault

Before rounding and capping, the reciprocal-odds formula returns exactly 97% at any fixed legal cash-out depth. The shipped integer settlement and 5,000x cap invalidate the stronger claim of an identical 97% return for every configuration and strategy.

- With three mines, three reveals and a 25-chip stake, survival probability is `C(22,3)/C(25,3) = 1540/2300`. Gross payout floors to 36 chips; actual expected return is `0.964173913043478` (96.4173913043478%).
- With three mines, one reveal and a one-chip stake, gross payout floors to one chip. Expected return is 88%, not 97%.
- The 5,000x cap starts binding whenever survival probability is below `0.97/5000 = 0.000194`, approximately one in 5,155. It does not bind only below one in 5,200,300 as stated in the cabinet document.
- At twelve mines and thirteen safe reveals, survival is one in 5,200,300. Capping gross payout at 5,000x reduces expected return to approximately 0.0961483%, rather than 97%.

The cap remains exactly as specified. Runtime payout, display multiplier and analytical helper all use the same shipped paytable resource. The optional analytical-helper paytable argument permits verification of edited resources without duplicate payout constants.

## Blackjack

The payout table requires a doubled winning hand to return four times the original stake, while nearby prose describes a three-times-stake maximum. The implementation treats the cap as three times the final risked stake, which includes doubling. Thus a doubled win returns twice its final risked stake and preserves the explicit payout table. It is never incorrectly clipped to three times the original bet.

Natural gross payout is `floor(5 * stake / 2)`. Even stakes retain exact 3:2 profit; odd stakes lose half a chip to rounding. The million-hand harness uses an even stake and the documented no-split basic strategy. Reported RTP divides gross returned chips by all risked chips, including additional double stakes. The declared 99% target remains unchanged.

Blackjack shoes persist across hands within a cabinet visit and reshuffle only between hands when fewer than 52 cards remain. RNG independence and deterministic outcomes are tested with identical initial state and action sequences; restoring a complete mid-hand shoe is outside the current save contract.
