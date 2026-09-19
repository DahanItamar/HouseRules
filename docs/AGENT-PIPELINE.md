# Agency Agents integration

Upstream repository: [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents).

The adopted definitions were fetched from commit `ad9264e309bd5e5422c04784372d7841b1e5d604`. Local copies and the upstream MIT license are retained in `tools/agency-agents/` so the workflow is reviewable and reproducible without relying on a moving branch.

| Adopted definition | Pinned upstream path | Local copy | Execution responsibility |
| --- | --- | --- | --- |
| Software Architect | `engineering/engineering-software-architect.md` | `tools/agency-agents/engineering-software-architect.md` | Root integration: repository layout, six autoload services, platform saves, session routing, floor, cabinet adapters and acceptance integration. |
| Godot Gameplay Scripter | `game-development/godot/godot-gameplay-scripter.md` | `tools/agency-agents/godot-gameplay-scripter.md` | Domain agent: typed contracts, three pure-math cabinets, resource paytables, deterministic strategy APIs, and mathematical discrepancy review. |
| Reality Checker | `testing/testing-reality-checker.md` | `tools/agency-agents/testing-reality-checker.md` | QA agent: headless GUT tests, acceptance checks, million-round simulations, honest failure reporting and CI verification. |
| Image Prompt Engineer | `design/design-image-prompt-engineer.md` | `tools/agency-agents/design-image-prompt-engineer.md` | Asset agent: translate ASSET-SPECS briefs into Higgsfield generation requests, preserve generation provenance, and distinguish drafts from accepted production assets. |

The layered casino pass (2026-09-19, Claude Code with Claude agents) pinned these
additional definitions from the same commit:

| Adopted definition | Local copy | Execution responsibility |
| --- | --- | --- |
| Level Designer | `tools/agency-agents/level-designer.md` | Tracing blocked zones, occluders and anchors for the three rooms. |
| Technical Artist | `tools/agency-agents/technical-artist.md` | Layer builds, paint-in bakes and host pose masters. |
| Inclusive Visuals Specialist | `tools/agency-agents/design-inclusive-visuals-specialist.md` | Varied adult guests across age, skin tone, body type and presentation. |
| UI Finish Gate Reviewer | `tools/agency-agents/design-ui-finish-gate-reviewer.md` | Blackjack table and HUD composition review. |
| Evidence Collector | `tools/agency-agents/testing-evidence-collector.md` | Screenshot evidence at FHD, QHD and UHD. |
| Test Automation Engineer | `tools/agency-agents/testing-test-automation-engineer.md` | Floor composition and collision regression suite. |

Source links resolve against [the pinned tree](https://github.com/msitarzewski/agency-agents/tree/ad9264e309bd5e5422c04784372d7841b1e5d604). These personas supply working practices; they do not supersede the project's locked specification or confer additional tools or permissions.

## Project adaptations

- `docs/SPEC.md` and companion cabinet specifications take precedence over upstream architectural preferences. In particular, no EventBus autoload is introduced: the project's six-service boundary remains authoritative.
- Node composition applies to presentation and session coordination. Cabinet mathematics extends `RefCounted`, has no Node or SceneTree dependency, emits no signals, and receives an explicit RNG stream.
- `CabinetSession` is the only cabinet-result path to the wallet. Monetary settlement uses integer chips; paytable resource values drive production results and the simulation harness.
- The QA persona's evidence requirement means an executed simulation, exact enumeration, and a passing acceptance criterion are reported separately. A statistical failure is not relabeled as a pass, and seeds are not selected to hide a failure.
- Image prompting is adapted from photographic subjects to orthographic game assets, palette limits, target dimensions and visual cleanup requirements. Generation success alone does not establish pixel-art or production acceptance.

## Collaboration boundaries

The root coordinator assembled the team and assigned parallel work explicitly authorized by the user. Domain work owned `src/domain/` and `data/`; QA owned tests and simulation/CI artifacts; asset work owned generation requests and asset evidence. The root integrated shared runtime systems. API messages established cabinet methods and typed result contracts before testing and adapter integration.

The upstream files remain reference prompts, not executable plugins. Their local presence documents which definitions were read and adopted during this execution; it does not automatically activate future agents.
