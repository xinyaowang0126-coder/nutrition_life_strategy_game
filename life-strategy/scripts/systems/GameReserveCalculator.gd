class_name GameReserveCalculator
extends RefCounted

## Pure game-resource formula. No meal, composition or health-score inputs.
static func calculate(state: Dictionary, day: int, total_days: int, recovery_contribution: float) -> int:
	var mental := float(state["mood"]) * 0.55 + (100.0 - float(state["stress"])) * 0.45
	var remaining_days: int = max(0, total_days - day)
	var budget_safety := 100.0
	if remaining_days > 0:
		budget_safety = clamp(float(state["balance"]) / (float(remaining_days) * 18.0) * 100.0, 0.0, 100.0)
	var recovery_term := recovery_contribution
	# A legacy diet score cannot grant resource points or decide an ending.
	var score := mental * 0.30
	score += float(state["energy"]) * 0.25
	score += float(state["satiety"]) * 0.20
	score += recovery_term
	score += float(state["study_progress"]) * 0.10
	score += budget_safety * 0.05
	if int(state["energy"]) < 16:
		score -= 10
	if int(state["mood"]) < 16:
		score -= 10
	if int(state["satiety"]) < 20:
		score -= 10
	if int(state["satiety"]) < 5:
		score -= 15
	if int(state["stress"]) > 88:
		score -= 10
	if remaining_days > 0 and int(state["balance"]) < remaining_days * 10:
		score -= 8
	return int(round(clamp(score, 0.0, 100.0)))
