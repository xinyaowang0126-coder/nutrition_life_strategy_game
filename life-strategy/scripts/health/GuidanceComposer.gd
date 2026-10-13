class_name GuidanceComposer
extends RefCounted

## Re-evaluates the supplied immutable snapshot, never trusts a caller's
## claimed "approved" result. It does not read live food cards or issue actions.
const Config := preload("res://scripts/health/HealthGuidanceConfig.gd")
const Evaluator := preload("res://scripts/health/DietPatternEvaluator.gd")
const Evidence := preload("res://scripts/health/HealthEvidenceRegistry.gd")
const XmlStructure := preload("res://scripts/health/HealthXmlStructure.gd")
const DEFAULT_PATH := "res://data/health/guidance_copy.xml"
const IDS := ["MEAL_COMPOSITION_RECORDED", "MEAL_COMPOSITION_PARTIAL", "MEAL_COMPOSITION_UNKNOWN", "MEAL_SKIPPED_RECORD", "MEAL_LEGACY_UNKNOWN", "MEAL_DATA_UNAVAILABLE"]
const NUTRITION_IDS := ["MEAL_COMPOSITION_RECORDED", "MEAL_COMPOSITION_PARTIAL"]
const LABELS := {"grains_tubers": "主食", "vegetables": "蔬菜", "eggs": "蛋类", "soy_products": "豆制品", "poultry_livestock": "肉类", "fish_seafood": "鱼类", "fruits": "水果", "dairy": "奶类", "nuts_seeds": "坚果", "beverages": "饮品"}
const FALLBACK := "配料还在核对。"
const SAFE_COPIES := {
	"MEAL_COMPOSITION_UNKNOWN": FALLBACK,
	"MEAL_SKIPPED_RECORD": "这顿没吃。",
	"MEAL_LEGACY_UNKNOWN": "这顿没记配料。",
	"MEAL_DATA_UNAVAILABLE": "暂时查不到配料。",
}
const REQUIRED_CAPABILITIES := ["MEAL_DIVERSITY_EDUCATION", "PLAYER_GUIDANCE"]


static func load_catalog(path: String = DEFAULT_PATH) -> Dictionary:
	var catalog := {"valid": false, "errors": [], "schema_version": 0, "model_version": "", "rules_version": "", "locale": "", "copies": {}}
	if not FileAccess.file_exists(path):
		catalog["errors"].append("copy_file_missing")
		return catalog
	var data := FileAccess.get_file_as_bytes(path)
	var structure_error := XmlStructure.validate(data)
	if not structure_error.is_empty():
		catalog["errors"].append("copy_xml_invalid")
		return catalog
	var parser := XMLParser.new()
	if parser.open_buffer(data) != OK:
		catalog["errors"].append("copy_xml_invalid")
		return catalog
	var root_seen := false
	var current := {}
	var in_text := false
	var read_error := parser.read()
	while read_error == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var name := parser.get_node_name()
				var attrs := _attributes(parser)
				if not root_seen:
					root_seen = true
					if name != "guidance_copy" or attrs.get("schema_version") != "1":
						catalog["errors"].append("copy_root_or_schema_invalid")
					else:
						catalog["schema_version"] = 1
					catalog["model_version"] = attrs.get("model_version", "")
					catalog["rules_version"] = attrs.get("rules_version", "")
					catalog["locale"] = attrs.get("locale", "")
				elif name == "copy" and current.is_empty():
					current = attrs
					current["text"] = ""
					if parser.is_empty():
						catalog["errors"].append("copy_text_missing")
						current = {}
				elif name == "text" and not current.is_empty() and not in_text:
					in_text = true
				else:
					catalog["errors"].append("copy_element_unexpected")
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if in_text:
					current["text"] += parser.get_node_data()
				elif not parser.get_node_data().strip_edges().is_empty():
					catalog["errors"].append("copy_text_outside_template")
			XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() == "text":
					in_text = false
				elif parser.get_node_name() == "copy":
					var id := String(current.get("id", ""))
					if catalog["copies"].has(id):
						catalog["errors"].append("copy_id_duplicate")
					else:
						catalog["copies"][id] = current.duplicate(true)
					current = {}
		read_error = parser.read()
	if read_error != ERR_FILE_EOF or not root_seen:
		catalog["errors"].append("copy_xml_invalid")
	var checked := validate_catalog(catalog)
	catalog["errors"].append_array(checked["errors"])
	catalog["valid"] = catalog["errors"].is_empty()
	return catalog


static func validate_catalog(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not value is Dictionary or not value.get("copies") is Dictionary:
		return {"valid": false, "errors": ["copy_catalog_invalid"]}
	if typeof(value.get("schema_version")) != TYPE_INT or value["schema_version"] != 1:
		errors.append("copy_schema_unsupported")
	if not value.get("valid") is bool or not value.get("errors") is Array or not value["errors"].is_empty():
		errors.append("copy_catalog_has_errors")
	if value.get("model_version") != Config.MODEL_VERSION or value.get("rules_version") != Config.RULES_VERSION or value.get("locale") != "zh-CN":
		errors.append("copy_version_or_locale_unsupported")
	var copies: Dictionary = value["copies"]
	for id in IDS:
		if not copies.has(id):
			errors.append("required_copy_missing:" + id)
	for id in copies:
		var entry: Variant = copies[id]
		if not entry is Dictionary or not IDS.has(id) or entry.get("id") != id:
			errors.append("copy_id_invalid")
			continue
		var expected_type := "nutrition_observation" if NUTRITION_IDS.has(id) else ("record_fact" if id == "MEAL_SKIPPED_RECORD" else "boundary")
		if entry.get("type") != expected_type or entry.get("review_status") not in ["draft", "expert_reviewed", "needs_update"]:
			errors.append("copy_type_or_review_invalid")
		if not entry.get("text") is String or entry["text"].strip_edges().is_empty() or entry["text"].length() > 180:
			errors.append("copy_text_invalid")
			continue
		var variable_list := "food_groups_text" if NUTRITION_IDS.has(id) else ""
		if entry.get("variables") != variable_list:
			errors.append("copy_variable_list_invalid")
		var text: String = entry["text"]
		# Record/boundary templates have no clinical review requirement because
		# their narrow factual wording is fixed. Relabelling arbitrary prose as
		# a boundary must never bypass the nutrition-copy approval gate.
		if SAFE_COPIES.has(id) and text != SAFE_COPIES[id]:
			errors.append("safe_copy_text_changed")
		var remaining := text.replace("{food_groups_text}", "") if NUTRITION_IDS.has(id) else text
		if remaining.contains("{") or remaining.contains("}") or (NUTRITION_IDS.has(id) and text.count("{food_groups_text}") != 1):
			errors.append("copy_placeholder_invalid")
		if NUTRITION_IDS.has(id) and not Config.string_ids(Array(entry.get("evidence_refs", "").split(",", false)) if entry.get("evidence_refs") is String else []):
			errors.append("copy_evidence_missing")
	return {"valid": errors.is_empty(), "errors": errors}


static func compose_meal(snapshot: Variant, config: Variant, registry: Evidence, as_of_date: String, catalog: Variant) -> Dictionary:
	var evaluation := Evaluator.evaluate(snapshot, config, registry, as_of_date)
	var checked := validate_catalog(catalog)
	var result := {"valid": evaluation["valid"] and checked["valid"], "primary": {"id": "MEAL_COMPOSITION_UNKNOWN", "text": FALLBACK, "kind": "boundary"}, "primary_suggestion": null, "fallback_suggestion": null, "evaluation": evaluation, "copy_allowed": false, "reason_ids": [], "copy_evidence": {}}
	if not checked["valid"] or (catalog is Dictionary and not catalog.get("valid", true)):
		result["valid"] = false
		result["reason_ids"] = checked["errors"].duplicate()
		return result
	var id: String = evaluation["copy_id"]
	var entry: Dictionary = catalog["copies"][id]
	if NUTRITION_IDS.has(id):
		var approval_data := entry.duplicate(true)
		approval_data["evidence_refs"] = Array(String(entry["evidence_refs"]).split(",", false))
		var approval := Config.approval(approval_data, registry, as_of_date, REQUIRED_CAPABILITIES)
		result["copy_evidence"] = approval["evidence_check"]
		if not approval["allowed"]:
			result["reason_ids"] = approval["reason_ids"].duplicate()
			return result
	var text: String = entry["text"]
	if NUTRITION_IDS.has(id):
		var labels: Array[String] = []
		for group in LABELS:
			if evaluation["food_group_ids"].has(group):
				labels.append(LABELS[group])
		if labels.is_empty():
			result["valid"] = false
			result["reason_ids"] = ["copy_variables_unavailable"]
			return result
		text = text.replace("{food_groups_text}", "、".join(labels))
	result["primary"] = {"id": id, "text": text, "kind": entry["type"]}
	result["copy_allowed"] = true
	return result


static func _attributes(parser: XMLParser) -> Dictionary:
	var attributes := {}
	for index in range(parser.get_attribute_count()):
		attributes[parser.get_attribute_name(index)] = parser.get_attribute_value(index)
	return attributes
