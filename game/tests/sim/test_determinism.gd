extends GutTest
## Same seed + same commands = same state (02_TECH_ARCHITECTURE.md section 6).
## Skeleton: no commands exist yet; feed the same command list to both worlds once they do.

const TICKS: int = 30 * 60  # one simulated minute


func _run(run_seed: int) -> int:
	var world := SimWorld.new(run_seed)
	for i in TICKS:
		world.step()
	return world.state_hash()


func test_same_seed_same_state() -> void:
	assert_eq(_run(12345), _run(12345))


func test_different_seed_different_state() -> void:
	assert_ne(_run(12345), _run(54321))
