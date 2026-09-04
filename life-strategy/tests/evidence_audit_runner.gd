extends SceneTree

## CI/local entry point for evidence lifecycle checks:
##
##   godot --headless --path . --script res://tests/evidence_audit_runner.gd
##   godot --headless --path . --script res://tests/evidence_audit_runner.gd -- --as-of=2026-07-15

const HealthEvidenceRegistryScript := preload("res://scripts/health/HealthEvidenceRegistry.gd")


func _initialize() -> void:
	var as_of_date := Time.get_date_string_from_system(true)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--as-of="):
			as_of_date = argument.trim_prefix("--as-of=")

	var registry := HealthEvidenceRegistryScript.new()
	var load_result: Dictionary = registry.load_registry()
	var audit: Dictionary = registry.audit(as_of_date)
	var output := {
		"as_of_date": as_of_date,
		"registry_status": String(load_result.get("status", "unknown")),
		"valid": bool(audit.get("valid", false)),
		"review_due_ids": audit.get("review_due_ids", []),
		"needs_review_ids": audit.get("needs_review_ids", []),
		"next_review_due_at": String(audit.get("next_review_due_at", "")),
		"review_due_at_by_id": audit.get("review_due_at_by_id", {}),
		"errors": audit.get("errors", []),
		"warnings": audit.get("warnings", []),
	}
	print("HEALTH_EVIDENCE_AUDIT=" + JSON.stringify(output))
	var has_due_review := not (audit.get("review_due_ids", []) as Array).is_empty()
	quit(1 if not bool(audit.get("valid", false)) or has_due_review else 0)
