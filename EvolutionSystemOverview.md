# Evolution System Overview

## Architecture

The evolution system is now unified with a single source of truth in `Races.luau`. All evolution definitions, requirements, and branching paths are managed through this module.

## Evolution Triggers

Evolution can be triggered in three ways:

### 1. Combat Trigger
- **When**: After any combat encounter where the monster survives
- **Chance Multiplier**: 1.2x (20% bonus)
- **Location**: `CombatManager.ProcessCombatResults()`
- **Timing**: 2 second delay after combat results are processed

### 2. Training Trigger
- **When**: After successfully completing any training exercise
- **Chance Multiplier**: 1.1x (10% bonus)
- **Location**: `TrainingSystem.Start()`
- **Timing**: 1 second delay after training success

### 3. Item Trigger (Future)
- **When**: Player uses an evolution item
- **Chance Multiplier**: 1.0 (Guaranteed if requirements met)
- **Status**: System ready, awaiting item implementation

### 4. Manual Trigger
- **When**: Player manually requests evolution via Remote
- **Chance Multiplier**: 1.0 (Base chance)
- **Remote**: `EvolutionRequest`

## Evolution Requirements

Each evolution path has gates that must be met:

- **minStats**: Minimum stat values (e.g., `{ Strength = 100, Speed = 80 }`)
- **minWins**: Minimum number of combat victories
- **minBond**: Minimum bond level with the monster
- **maxCareMistakes**: Maximum allowed care mistakes (for pure paths)
- **baseRaceFamily**: Must be from specific race family

## Evolution Chance System

The chance of evolution is calculated based on:

1. **Base Progress**: How close the monster is to meeting requirements (0-100%)
2. **Trigger Multiplier**: Bonus based on how evolution was triggered
3. **Win Bonus**: 
   - 10+ wins: 1.15x
   - 20+ wins: 1.3x
4. **Bond Bonus**:
   - 40+ bond: 1.1x
   - 70+ bond: 1.2x
5. **Cap**: Maximum 99% chance (always preserve some RNG)

### Progression Tiers
- 90%+ progress → 95% evolution chance
- 70-89% progress → 75% evolution chance
- 50-69% progress → 50% evolution chance
- 30-49% progress → 25% evolution chance
- 10-29% progress → 10% evolution chance
- <10% progress → 5% forced evolution chance

## Move System

### Move Learning
Moves are learned through the same trigger system:
- **Combat**: After winning battles
- **Training**: After training sessions
- **Evolution**: When evolving to new race

### Move Inheritance
When evolving, the monster:
1. Keeps all previous moves (up to max)
2. Gets starter moves for the new race
3. May unlock new moves via `MoveUnlocks` system
4. Highest rarity previous moves are prioritized for inheritance

### Max Moves: 4
When a new move is learned and the monster has 4 moves:

**Replacement Priority** (kept first):
1. BasicAttack (always kept)
2. Primordial rarity moves
3. Ascended rarity moves
4. Specialist rarity moves
5. Advanced rarity moves
6. Amateur rarity moves (replaced first)

## Evolution Paths

### Progenitor Family
```
RealitySeed (Fledgeling)
    → CosmicWeaver (Champion)
        → VoidWalker (Elder)
            → EntropicVoid (Unique)
        → Architect (Elder)
            → PrimeConcept (Unique)
```

### Construct Family
```
Core (Fledgeling)
    → Golem (Rookie)
        → Titan (Champion)
            → Colossus (Elder)
                → IronColoss (Unique)
```

### Beast Family
```
Hopling (Fledgeling)
    → Pugilhare (Rookie)
        → Strikeron (Champion)
            → Monarchare (Elder)
                → SteelBoxer (Unique)
```

### Raptor Family
```
Raptor (Fledgeling)
    → Dino (Rookie)
        → Beast (Champion)
            → Dragon (Elder)
                → NetherDragon (Unique)
```

## Stage Progression

Each race belongs to a stage with stat caps:

- **Fledgeling**: 300 total stats cap
- **Rookie**: 600 total stats cap
- **Champion**: 1200 total stats cap
- **Elder**: 1800 total stats cap
- **Unique**: 2000 total stats cap

## Stat Gains on Evolution

When evolving, stats are boosted based on the new stage:

### Fledgeling → Rookie
- HP: +10% + 0 flat
- MP: +10% + 0 flat
- Other stats: +5% each

### Rookie → Champion
- HP: +12% + 20 flat
- MP: +12% + 10 flat
- Strength, Defense: +8% each
- Skill, Speed: +6% each
- Intelligence: +8%
- Luck: +6%

### Champion → Elder
- HP: +15% + 35 flat
- MP: +15% + 15 flat
- Strength, Defense: +12% each
- Skill, Speed: +10% each
- Intelligence: +12%
- Luck: +10%

### Elder → Unique
- HP: +18% + 50 flat
- MP: +18% + 20 flat
- Strength, Defense: +16% each
- Skill, Speed: +12% each
- Intelligence: +16%
- Luck: +12%

## Key Functions

### EvolutionManager.TryEvolve(monsterData, trigger, opts)
Checks if evolution is possible and rolls for success.
- Returns: `(success, targetRace/reason, chance)`

### EvolutionManager.StartEvolution(player, playerData, trigger, opts)
Initiates the evolution process with VFX and rebuilding.
- Triggers VFX on client
- Schedules CompleteEvolution after effect duration
- Returns: `(success, targetRace/reason)`

### EvolutionManager.CompleteEvolution(player, newRaceName, oldPivot)
Applies the evolution changes:
- Updates race and stage
- Applies stat boosts
- Merges moves (previous + starters + unlocks)
- Rebuilds monster model
- Repositions at old pivot
- Updates HP/MP on Humanoid

### EvolutionManager.CheckEvolutionTrigger(player, trigger, opts)
Automatic evolution check after triggers.
- Called by Combat/Training systems
- Logs why evolution succeeded/failed
- Returns: `(success, result)`

## Global Access

The evolution system is available globally as:
```lua
_G.EVOLUTION
```

This allows any system to:
- Check for evolution: `_G.EVOLUTION.CheckEvolutionTrigger(player, "combat")`
- Force evolution: `_G.EVOLUTION.StartEvolution(player, data, "item", {evoItem = "StonePlate"})`
- Check requirements: `_G.EVOLUTION.TryEvolve(monsterData)`

## Integration Points

### CombatManager
- After combat results are processed
- Checks evolution for all surviving participants
- 2 second delay before check

### TrainingSystem
- After successful training completion
- Checks evolution for the training monster
- 1 second delay before check

### Shared.luau
- Manual evolution requests via EvolutionRequest remote
- Calls `_G.EVOLUTION.StartEvolution` with "manual" trigger

## Future Enhancements

1. **Evolution Items**: System is ready, needs item inventory implementation
2. **Branching Choices**: Player choice between multiple valid evolutions
3. **De-evolution**: Mechanic for reverting to previous forms
4. **Mega Evolution**: Temporary super forms during combat
5. **Fusion**: Combining two monsters into one
