extends SceneTree

## The original generator is frozen as text in fixtures/recovery_v1_baseline.
## Current production no longer has the old burden rules. Never overwrite the
## original JSON by running today's code under the historical generator name.
func _initialize() -> void:
	print("Legacy recovery generation is retired. Read the frozen JSON and archived source in res://tests/fixtures/recovery_v1_baseline/.")
	quit(1)
