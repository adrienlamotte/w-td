class_name SimWorld
extends RefCounted
## Root of the headless simulation. Nothing in sim/ may touch Node or scenes
## (02_TECH_ARCHITECTURE.md section 3). Deterministic for a given seed.

const TICK_RATE: int = 30  # D-038
const SIM_DT: float = 1.0 / TICK_RATE

var tick: int = 0
# ponytail: one RNG for now; split per concern (spawns, loot, cards, combat) when those systems land.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(run_seed: int) -> void:
	_rng.seed = run_seed


## Advances the simulation by exactly one tick of SIM_DT.
func step() -> void:
	tick += 1


## Fingerprint of the whole sim state, used by determinism tests.
## Extend it with every entity array as they are added.
func state_hash() -> int:
	return hash([tick, _rng.state])
