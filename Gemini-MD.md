# GAME DESIGN DOCUMENT: RETRO CASINO HUB & MINI-GAME EXPERIENCE

## 1. High-Concept Overview
- **Genre**: 2D Top-Down Casino Exploration / Gambling Mini-Game Hub.
- **Visual Style**: Rich Pixel-Art, neon lighting, retro-inspired aesthetic with atmospheric jazz/synth background audio.
- **Perspective**: Top-down casino floor movement transitioning into full-screen 2D interactive UI for each game cabinet/table.
- **Core Gameplay Loop**: Explore Floor -> Choose Machine/Table -> Play Mini-Games -> Earn Chips -> Unlock High-Roller Tiers -> Final Showdown against "The House".

---

## 2. Casino Floor & Machine Concepts

### A. Classic Table Games
- **European Roulette**: Full board layout for inside/outside bets, interactive chip stack placement, and wheel spin animation.
- **Blackjack 21**: Fast dealer-vs-player card mechanics (Hit, Stand, Double Down, Split) with customizable deck themes.
- **Video Poker**: Single-player terminal based on Texas Hold'em / Five-Card Draw mechanics with scaling payouts.

### B. Hybrid & Interactive Slot Machines
- **The Dungeon Quest Slot**: An RPG-themed slot machine where reel combinations attack a monster display at the top of the cabinet. Defeating the boss triggers a massive loot bonus.
- **The Vault Heist Slot**: Landing 3 Vault symbols initiates a timed lock-picking mini-game (memory/timing-based) to crack the jackpot.
- **Pachinko / Plinko Cabinet**: Physics-based token drop machine where chips bounce down pegs into dynamic multiplier catch basins.
- **Cyber-Race Terminal**: Automated electronic betting station for simulated pixel-art races featuring dynamic odds and betting types.
- **Classic 3-Reel Retro Slot**: Nostalgic 777/Fruit machine with physical arm interaction and high-volatility payouts.

---

## 3. Progression & Meta-Systems

- **Tiered Casino Access**:
  1. *Main Floor*: Low stakes (Roulette, Fruit Slots, Pachinko).
  2. *High-Roller Lounge*: Mid-to-high stakes (Blackjack, Dungeon Slot, Cyber-Dog Racing).
  3. *VIP Penthouse*: Extreme stakes, high-level AI opponents, and secret high-payout games.
- **Economy & Reputation**: Chips double as currency and experience. Crossing chip thresholds unlocks new casino wings and cosmetic suit upgrades.
- **Narrative Endgame**: Reaching $1,000,000 unlocks the Penthouse for a final scripted high-stakes tournament against "The House" owner to win ownership of the casino.

---

## 4. Prompt & Task Instructions for Claude

> **ROLE & SCOPE**: Act as a Lead Game Designer. Focus ONLY on Game Design (GDD), System Architecture, Mechanics, UX Flows, and Balance. DO NOT generate any code or scripts.
>
> **YOUR TASK**: Expand this concept document by addressing the following points in detail:
> 
> 1. **UX/UI Transition State Machine**: Map out the exact visual and interaction flow when a player walks up to a machine on the 2D floor and transitions into the mini-game view.
> 2. **3 Additional Arcade/Casino Cabinets**: Design 3 new original mini-game cabinets that combine classic gambling odds with 80s/90s arcade mechanics.
> 3. **Economy & Payout Math**: Outline the exact chip progression curve, bet limits per area, and multiplier ratios for all games.
> 4. **Boss Showdown Blueprint**: Write a detailed step-by-step narrative and mechanic outline for the final boss match against "The House" owner.