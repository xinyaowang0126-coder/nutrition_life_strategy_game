class_name DayCarryoverService
extends RefCounted

## Compatibility entry point for versioned frozen records only.
## Old diet-based evaluation is archived as text beside its frozen fixtures.
const Gameplay := preload("res://scripts/systems/RecoveryGameplayService.gd")


static func from_recovery(record: Variant, expected_day: Variant) -> Dictionary:
	return Gameplay.prepare_day(record, expected_day)
