class_name CampusStudyJournal
extends RefCounted


static func initial_state(legacy: bool = false) -> Dictionary:
	return {"version": 1, "legacy": legacy, "entries": []}


static func key(kind: String, context: Dictionary) -> String:
	var raw: Variant = context.get("food_ids", [])
	var ids: Array = raw.duplicate() if raw is Array else []
	ids.sort()
	return kind + ":" + JSON.stringify(ids)


static func entry(journal: Dictionary, kind: String, context: Dictionary, create: bool = false) -> Dictionary:
	if kind != "composition": return {}
	var id := key(kind, context)
	for row in journal.get("entries", []):
		if row["key"] == id: return row
	if not create or journal["entries"].size() >= 128: return {}
	var row := {"key": id, "kind": kind, "context": context.duplicate(true), "complete": not bool(journal.get("legacy", false)), "opens": 0, "help_views": 0, "retries": 0, "skips": 0, "help_seen": false, "answer_count": 0, "first_answer": {}, "answers": []}
	journal["entries"].append(row)
	return row


static func open(journal: Dictionary, kind: String, context: Dictionary) -> Dictionary:
	var row := entry(journal, kind, context, true)
	if not row.is_empty(): row["opens"] += 1
	return row


static func help(journal: Dictionary, kind: String, context: Dictionary) -> void:
	var row := entry(journal, kind, context, true)
	if row.is_empty(): return
	row["help_seen"] = true
	row["help_views"] += 1


static func retry(journal: Dictionary, kind: String, context: Dictionary) -> void:
	var row := entry(journal, kind, context, true)
	if not row.is_empty(): row["retries"] += 1


static func skip(journal: Dictionary, kind: String, context: Dictionary) -> void:
	var row := entry(journal, kind, context, true)
	if not row.is_empty(): row["skips"] += 1


static func answer(journal: Dictionary, kind: String, context: Dictionary, response: Dictionary, correct: bool) -> Dictionary:
	var row := entry(journal, kind, context, true)
	if row.is_empty(): return {}
	row["answer_count"] += 1
	var aided: bool = row["help_seen"]
	var result := {"number": row["answer_count"], "response": response.duplicate(true), "correct": correct, "after_help": aided, "independence": "after_help" if aided else ("independent" if row["complete"] else "unknown")}
	row["answers"].append(result)
	if row["answers"].size() > 65: row["answers"].remove_at(1)
	if row["first_answer"].is_empty(): row["first_answer"] = result.duplicate(true)
	return result


static func migrate(attempts: Array, active: Dictionary) -> Dictionary:
	var journal := initial_state(true)
	for attempt in attempts:
		if not attempt is Dictionary or not attempt.get("context") is Dictionary or typeof(attempt.get("after_help")) != TYPE_BOOL or typeof(attempt.get("correct")) != TYPE_BOOL: continue
		var row := entry(journal, "composition", attempt["context"], true)
		if row.is_empty(): continue
		if attempt["after_help"]: row["help_seen"] = true
		answer(journal, "composition", attempt["context"], {"choice": attempt.get("choice", "")}, attempt["correct"])
		row["help_seen"] = true
	if active.get("kind") == "study" and active.get("context") is Dictionary:
		var row := entry(journal, "composition", active["context"], true)
		if not row.is_empty() and active.get("help", false): row["help_seen"] = true
	return journal


static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3 or value.get("version") != 1 or typeof(value.get("legacy")) != TYPE_BOOL or not value.get("entries") is Array or value["entries"].size() > 128: return false
	var keys := {}
	for row in value["entries"]:
		if not row is Dictionary or row.size() != 12 or row.get("kind") != "composition" or not row.get("context") is Dictionary or row.get("key") != key(row["kind"], row["context"]) or keys.has(row["key"]): return false
		keys[row["key"]] = true
		if typeof(row.get("complete")) != TYPE_BOOL or typeof(row.get("help_seen")) != TYPE_BOOL: return false
		if row["complete"] != (not value["legacy"]): return false
		for field in ["opens", "help_views", "retries", "skips", "answer_count"]:
			if typeof(row.get(field)) != TYPE_INT or row[field] < 0 or row[field] > 100000: return false
		if row["help_views"] > 0 and not row["help_seen"]: return false
		if not row.get("first_answer") is Dictionary or not row.get("answers") is Array or row["answers"].size() > 65: return false
		if row["answer_count"] == 0:
			if not row["first_answer"].is_empty() or not row["answers"].is_empty(): return false
			continue
		if row["answers"].is_empty() or row["first_answer"] != row["answers"][0] or row["answers"][0].get("number") != 1 or row["answers"].back().get("number") != row["answer_count"]: return false
		var previous := 0
		for response in row["answers"]:
			if not response is Dictionary or response.size() != 5 or typeof(response.get("number")) != TYPE_INT or response["number"] <= previous or not response.get("response") is Dictionary or typeof(response.get("correct")) != TYPE_BOOL or typeof(response.get("after_help")) != TYPE_BOOL or response.get("independence") not in ["independent", "after_help", "unknown"]: return false
			if response["after_help"] and (not row["help_seen"] or response["independence"] != "after_help"): return false
			if not response["after_help"] and response["independence"] != ("independent" if row["complete"] else "unknown"): return false
			previous = response["number"]
	return true
