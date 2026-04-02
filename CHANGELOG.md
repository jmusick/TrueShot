# Changelog

## v0.7.1 - 2026-04-02

### Improved
- Friendly startup message with human-readable profile names
- Single-line chat output on login instead of two lines
- Updated README with full documentation

## v0.7.0 - 2026-04-02

### Added
- **Survival Hunter**: Pack Leader and Sentinel profiles
  - Stampede KC sequencing after Takedown (Pack Leader)
  - WFB charge management with near-cap cutoff (Sentinel)
  - Moonlight Chakram timing in Takedown window (Sentinel)
  - Takedown burst window tracking (8s)
  - Flamefang Pitch support
- All three Hunter specs now covered (BM, MM, SV) with 6 profiles total

## v0.6.0 - 2026-04-02

### Added
- **Marksmanship Hunter**: Dark Ranger and Sentinel profiles
  - Trueshot opener sequence: TS > BA > WA > BA (Dark Ranger)
  - Volley/Trueshot anti-overlap to prevent Double Tap waste
  - Post-Rapid Fire Trueshot gating for Bulletstorm uptime
  - Moonlight Chakram filler timing gated by Aimed Shot charges (Sentinel)

## v0.5.2 - 2026-04-02

### Added
- Tiered update rates: 10Hz combat, 2Hz idle, 0Hz hidden
- Instant event response on target change, spell cast, combat transitions
- DurationObject cooldown path for secret-safe rendering
- Charge edge ring for multi-charge spells

### Improved
- Cooldown swipe opacity reduced from 80% to 60%
- GCD filtering preserved on DurationObject path

### Fixed
- Scrollable settings panel
- Charge count only shown when regenerating

## v0.5.1 - 2026-04-02

### Added
- DurationObject cooldown rendering (C_Spell.GetSpellCooldownDuration)
- Charge cooldown edge ring (SetDrawSwipe false, SetDrawEdge true)

## v0.5.0 - 2026-04-02

### Added
- **Masque integration** for icon skinning (optional, zero-dependency)
- **First-icon scale** (1.0x - 2.0x) for visual hierarchy
- **Queue orientation** (LEFT, RIGHT, UP, DOWN)
- **Override glow** with pulsing animation (cyan PIN, blue PREFER)
- **Charge cooldown** display for multi-charge spells
- **Backdrop toggle** for clean floating-icons look

## v0.4.2 - 2026-04-01

### Added
- Macro keybind support

## v0.4.1 - 2026-04-01

### Fixed
- Bestial Wrath cooldown tracking fixes

### Improved
- Performance optimizations

## v0.4.0 - 2026-04-01

### Changed
- Renamed from HunterFlow to TrueShot
- Full UX overhaul

### Added
- BM Dark Ranger profile (Black Arrow, Withering Fire, Wailing Arrow state machine)
- BM Pack Leader profile (BW management, Nature's Ally, Wild Thrash AoE)
- Hero path auto-detection via IsPlayerSpell
- Settings panel in Game Options
- Cast success feedback
- Cooldown swipes (best-effort)
- Keybind display
- Range indicator
- Phase and reason overlay
