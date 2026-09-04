class_name HealthDataValidator
extends RefCounted

## Structural and governance checks for health-education data. The validator
## reports issues; it does not repair, infer, score, or mutate source profiles.

const SUPPORTED_SCHEMA_VERSION := 1

const PORTION_STATUSES := ["known", "estimated", "unknown"]
const PORTION_UNITS := ["g", "ml", "piece", "pack", "bowl", "serving"]
const PORTION_BANDS := ["small", "medium", "large", "unknown"]
const BASIS_TYPES := [
	"package_label",
	"menu_recipe",
	"standard_recipe_estimate",
	"visual_estimate",
	"generic_category",
	"unknown",
]
const CONFIDENCE_LEVELS := ["high", "medium", "low", "unknown"]
const REVIEW_STATUSES := ["draft", "expert_reviewed", "needs_update"]
const COMPOSITION_STATUSES := ["known", "estimated", "unknown"]
const FOOD_GROUPS := [
	"grains_tubers",
	"vegetables",
	"fruits",
	"eggs",
	"soy_products",
	"poultry_livestock",
	"fish_seafood",
	"dairy",
	"nuts_seeds",
	"beverages",
	"other",
	"unknown",
]
const CONTRIBUTION_BANDS := ["trace", "small", "material", "dominant", "unknown"]
const COMPONENT_AMOUNT_UNITS := ["g", "ml", "piece"]
const COOKING_METHODS := [
	"boiled",
	"steamed",
	"stir_fried",
	"deep_fried",
	"baked",
	"raw_ready_to_eat",
	"brewed",
	"mixed",
	"not_applicable",
	"unknown",
]
const FACTOR_IDS := ["added_sugar", "sodium", "saturated_fat", "deep_fried", "caffeine"]
const FACTOR_BANDS := ["none", "present", "low", "moderate", "high", "unknown"]
const CAFFEINE_STATUSES := ["known", "estimated", "unknown", "not_applicable"]
const CAFFEINE_BANDS := ["none", "low", "moderate", "high", "unknown"]
const SERVING_TIME_RELEVANCE := ["none", "evening_attention", "unknown"]
const DEFAULT_PENDING_EVIDENCE_IDS := ["PRODUCT-RECIPE-PENDING"]
const CAFFEINE_NAME_TERMS := ["咖啡", "茶", "coffee", "tea"]


static func validate(catalog: Dictionary, context: Dictionary = {}) -> Dictionary:
	var errors: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	if not _validate_catalog_envelope(catalog, errors):
		return _report(errors, warnings)

	_validate_required_root_fields(catalog, errors)
	var entries := _profile_entries(catalog)
	var seen_food_ids := {}
	var ingredient_groups := {}
	for entry_index in range(entries.size()):
		var entry: Variant = entries[entry_index]
		if not entry is Dictionary:
			_add_error(
				errors,
				"profile_not_dictionary",
				"",
				"profile_entries[%d]" % entry_index,
				"Profile entry must be a dictionary."
			)
			continue
		var profile := entry as Dictionary
		var food_id := String(profile.get("food_id", ""))
		if food_id.is_empty():
			_add_error(errors, "food_id_missing", "", "food_id", "Profile food_id is required.")
		elif seen_food_ids.has(food_id):
			_add_error(
				errors,
				"food_id_duplicate",
				food_id,
				"food_id",
				"Profile food_id must be unique."
			)
		else:
			seen_food_ids[food_id] = true

		if (
			not food_id.is_empty()
			and context.has("known_food_ids")
			and not _list_has(context["known_food_ids"], food_id)
		):
			_add_error(
				errors,
				"food_id_unknown",
				food_id,
				"food_id",
				"Profile food_id does not exist in the card catalog."
			)

		_validate_profile(profile, food_id, context, errors, warnings)
		_validate_ingredient_group_consistency(profile, food_id, ingredient_groups, errors)

	return _report(errors, warnings)


static func _validate_catalog_envelope(catalog: Dictionary, errors: Array[Dictionary]) -> bool:
	var schema_version := int(catalog.get("schema_version", -1))
	if schema_version < 0:
		_add_error(
			errors,
			"schema_version_invalid",
			"",
			"schema_version",
			"Catalog schema_version must be a non-negative integer."
		)
		return false
	if schema_version > SUPPORTED_SCHEMA_VERSION:
		_add_error(
			errors,
			"schema_version_future",
			"",
			"schema_version",
			"Catalog schema is newer than this validator supports."
		)
		return false
	if schema_version >= 0 and schema_version < SUPPORTED_SCHEMA_VERSION:
		_add_error(
			errors,
			"schema_version_legacy_unsupported",
			"",
			"schema_version",
			"Catalog schema requires an explicit migration before validation."
		)
		return false
	if not bool(catalog.get("available", false)):
		_add_error(
			errors,
			"catalog_unavailable",
			"",
			"status",
			"Catalog is unavailable: %s" % String(catalog.get("status", "unknown"))
		)
		return false
	return true


static func _validate_required_root_fields(
	catalog: Dictionary,
	errors: Array[Dictionary]
) -> void:
	for field_name in ["model_version", "locale", "reviewed_at"]:
		if String(catalog.get(field_name, "")).strip_edges().is_empty():
			_add_error(
				errors,
				"root_field_missing",
				"",
				field_name,
				"Catalog root field '%s' is required." % field_name
			)


static func _validate_profile(
	profile: Dictionary,
	food_id: String,
	context: Dictionary,
	errors: Array[Dictionary],
	warnings: Array[Dictionary]
) -> void:
	_validate_positive_integer(profile.get("profile_version", ""), errors, food_id, "profile_version")
	_validate_enum(
		String(profile.get("basis_type", "")),
		BASIS_TYPES,
		errors,
		food_id,
		"basis_type"
	)
	_validate_enum(
		String(profile.get("composition_status", "")),
		COMPOSITION_STATUSES,
		errors,
		food_id,
		"composition_status"
	)
	_validate_enum(
		String(profile.get("confidence", "")),
		CONFIDENCE_LEVELS,
		errors,
		food_id,
		"confidence"
	)
	_validate_enum(
		String(profile.get("review_status", "")),
		REVIEW_STATUSES,
		errors,
		food_id,
		"review_status"
	)

	var portion := _dictionary_field(profile, "portion", errors, food_id)
	_validate_enum(
		String(portion.get("status", "")),
		PORTION_STATUSES,
		errors,
		food_id,
		"portion.status"
	)
	_validate_enum(
		String(portion.get("band", "")),
		PORTION_BANDS,
		errors,
		food_id,
		"portion.band"
	)
	if String(portion.get("label", "")).strip_edges().is_empty():
		_add_error(
			errors,
			"portion_label_missing",
			food_id,
			"portion.label",
			"A player-readable display basis is required."
		)
	_validate_optional_amount_pair(
		portion,
		"value",
		"unit",
		PORTION_UNITS,
		errors,
		food_id,
		"portion"
	)

	var evidence_refs := _string_array(profile.get("evidence_refs", []))
	var review_status := String(profile.get("review_status", ""))
	if review_status == "expert_reviewed":
		if evidence_refs.is_empty():
			_add_error(
				errors,
				"expert_review_evidence_missing",
				food_id,
				"evidence_refs",
				"Expert-reviewed profiles require evidence references."
			)
		if String(profile.get("reviewed_at", "")).strip_edges().is_empty():
			_add_error(
				errors,
				"expert_review_date_missing",
				food_id,
				"reviewed_at",
				"Expert-reviewed profiles require a review date."
			)
		if String(profile.get("reviewed_by", "")).strip_edges().is_empty():
			_add_error(
				errors,
				"expert_reviewer_missing",
				food_id,
				"reviewed_by",
				"Expert-reviewed profiles require a reviewer role or code."
			)
	elif evidence_refs.is_empty():
		_add_error(
			errors,
			"profile_evidence_missing",
			food_id,
			"evidence_refs",
			"Profile evidence_refs must contain evidence or an explicit pending record."
		)

	var components := _array_field(profile, "components", errors, food_id)
	for component_index in range(components.size()):
		if not components[component_index] is Dictionary:
			_add_error(
				errors,
				"field_type_invalid",
				food_id,
				"components[%d]" % component_index,
				"Component entry must be a dictionary."
			)
			continue
		var component := components[component_index] as Dictionary
		_validate_component(component, component_index, food_id, errors, warnings)
	_validate_known_component_total(profile, portion, components, food_id, errors)
	var is_composite := _list_has(context.get("composite_food_ids", []), food_id)
	if (
		is_composite
		and components.is_empty()
		and String(profile.get("composition_status", "")) != "unknown"
	):
		_add_error(
			errors,
			"composite_components_missing",
			food_id,
			"components",
			"Composite food requires components or composition_status='unknown'."
		)
	if is_composite and _all_components_unknown(components):
		_add_warning(
			warnings,
			"composite_components_all_unknown",
			food_id,
			"components",
			"Every component is unknown; no composition claim should be generated."
		)

	var factors := _array_field(profile, "factors", errors, food_id)
	for factor_index in range(factors.size()):
		if not factors[factor_index] is Dictionary:
			_add_error(
				errors,
				"field_type_invalid",
				food_id,
				"factors[%d]" % factor_index,
				"Factor entry must be a dictionary."
			)
			continue
		var factor := factors[factor_index] as Dictionary
		_validate_factor(factor, factor_index, food_id, errors, warnings)

	var cooking_methods := _array_field(profile, "cooking_methods", errors, food_id)
	for method_index in range(cooking_methods.size()):
		_validate_enum(
			String(cooking_methods[method_index]),
			COOKING_METHODS,
			errors,
			food_id,
			"cooking_methods[%d]" % method_index
		)
	if cooking_methods.has("not_applicable") and cooking_methods.size() > 1:
		_add_error(
			errors,
			"not_applicable_method_conflict",
			food_id,
			"cooking_methods",
			"not_applicable must be the only cooking method for a profile."
		)
	if cooking_methods.has("deep_fried") and not _has_factor_band(
		factors,
		"deep_fried",
		"present"
	):
		_add_error(
			errors,
			"deep_fried_factor_missing",
			food_id,
			"factors",
			"deep_fried cooking method requires a matching factor with band='present'."
		)
	if _has_factor_band(factors, "deep_fried", "present") and not cooking_methods.has(
		"deep_fried"
	):
		_add_error(
			errors,
			"deep_fried_method_missing",
			food_id,
			"cooking_methods",
			"A present deep_fried factor requires the matching cooking method."
		)

	_validate_caffeine(profile, food_id, context, errors, warnings)
	_validate_profile_warnings(profile, food_id, context, factors, warnings)


static func _validate_component(
	component: Dictionary,
	component_index: int,
	food_id: String,
	errors: Array[Dictionary],
	warnings: Array[Dictionary]
) -> void:
	var prefix := "components[%d]" % component_index
	for field_name in ["ingredient_id", "name"]:
		if String(component.get(field_name, "")).strip_edges().is_empty():
			_add_error(
				errors,
				"component_field_missing",
				food_id,
				"%s.%s" % [prefix, field_name],
				"Component field '%s' is required." % field_name
			)
	_validate_enum(
		String(component.get("food_group", "")),
		FOOD_GROUPS,
		errors,
		food_id,
		"%s.food_group" % prefix
	)
	_validate_enum(
		String(component.get("contribution_band", "")),
		CONTRIBUTION_BANDS,
		errors,
		food_id,
		"%s.contribution_band" % prefix
	)
	_validate_enum(
		String(component.get("basis_type", "")),
		BASIS_TYPES,
		errors,
		food_id,
		"%s.basis_type" % prefix
	)
	var confidence := String(component.get("confidence", ""))
	_validate_enum(
		confidence,
		CONFIDENCE_LEVELS,
		errors,
		food_id,
		"%s.confidence" % prefix
	)
	_validate_optional_amount_pair(
		component,
		"amount_value",
		"amount_unit",
		COMPONENT_AMOUNT_UNITS,
		errors,
		food_id,
		prefix
	)
	if confidence in ["low", "unknown"]:
		_add_warning(
			warnings,
			"confidence_limited",
			food_id,
			"%s.confidence" % prefix,
			"Component confidence is %s." % confidence
		)


static func _validate_factor(
	factor: Dictionary,
	factor_index: int,
	food_id: String,
	errors: Array[Dictionary],
	warnings: Array[Dictionary]
) -> void:
	var prefix := "factors[%d]" % factor_index
	var factor_id := String(factor.get("factor_id", ""))
	_validate_enum(
		factor_id,
		FACTOR_IDS,
		errors,
		food_id,
		"%s.factor_id" % prefix
	)
	var band := String(factor.get("band", ""))
	_validate_enum(band, FACTOR_BANDS, errors, food_id, "%s.band" % prefix)
	if factor_id == "deep_fried" and band not in ["none", "present", "unknown"]:
		_add_error(
			errors,
			"deep_fried_band_invalid",
			food_id,
			"%s.band" % prefix,
			"Binary deep_fried facts only accept 'none', 'present', or 'unknown'."
		)
	if band == "present" and factor_id != "deep_fried":
		_add_error(
			errors,
			"factor_present_not_applicable",
			food_id,
			"%s.band" % prefix,
			"Factor band 'present' is reserved for binary cooking-method facts."
		)
	_validate_enum(
		String(factor.get("basis_type", "")),
		BASIS_TYPES,
		errors,
		food_id,
		"%s.basis_type" % prefix
	)
	var confidence := String(factor.get("confidence", ""))
	_validate_enum(
		confidence,
		CONFIDENCE_LEVELS,
		errors,
		food_id,
		"%s.confidence" % prefix
	)
	var evidence_refs := _string_array(factor.get("evidence_refs", []))
	if band in ["none", "high"] and evidence_refs.is_empty():
		_add_error(
			errors,
			"factor_band_evidence_missing",
			food_id,
			"%s.evidence_refs" % prefix,
			"Factor bands 'none' and 'high' require explicit evidence."
		)
	elif evidence_refs.is_empty():
		_add_error(
			errors,
			"factor_evidence_missing",
			food_id,
			"%s.evidence_refs" % prefix,
			"Factor evidence_refs is required."
		)
	if confidence in ["low", "unknown"]:
		_add_warning(
			warnings,
			"confidence_limited",
			food_id,
			"%s.confidence" % prefix,
			"Factor confidence is %s." % confidence
		)


static func _validate_known_component_total(
	profile: Dictionary,
	portion: Dictionary,
	components: Array,
	food_id: String,
	errors: Array[Dictionary]
) -> void:
	if String(profile.get("composition_status", "")) != "known":
		return
	if components.is_empty():
		_add_error(
			errors, "known_components_missing", food_id, "components",
			"Known composition requires at least one component."
		)
		return
	if (
		String(portion.get("status", "")) != "known"
		or not portion.has("value")
		or not portion.has("unit")
	):
		return
	var portion_unit := String(portion.get("unit", ""))
	if portion_unit not in COMPONENT_AMOUNT_UNITS:
		return
	var component_total := 0.0
	for component_value in components:
		if not component_value is Dictionary:
			return
		var component := component_value as Dictionary
		if (
			not component.has("amount_value")
			or String(component.get("amount_unit", "")) != portion_unit
			or typeof(component["amount_value"]) not in [TYPE_INT, TYPE_FLOAT]
		):
			return
		component_total += float(component["amount_value"])
	if typeof(portion["value"]) not in [TYPE_INT, TYPE_FLOAT]:
		return
	if absf(component_total - float(portion["value"])) > 0.01:
		_add_error(
			errors,
			"known_component_total_mismatch",
			food_id,
			"components",
			(
				"Known same-unit component total %.2f %s must match portion %.2f %s."
				% [component_total, portion_unit, float(portion["value"]), portion_unit]
			)
		)


static func _validate_ingredient_group_consistency(
	profile: Dictionary,
	food_id: String,
	ingredient_groups: Dictionary,
	errors: Array[Dictionary]
) -> void:
	var components_value: Variant = profile.get("components", [])
	if not components_value is Array:
		return
	var components := components_value as Array
	for component_index in range(components.size()):
		if not components[component_index] is Dictionary:
			continue
		var component := components[component_index] as Dictionary
		var ingredient_id := String(component.get("ingredient_id", "")).strip_edges()
		var food_group := String(component.get("food_group", ""))
		if ingredient_id.is_empty() or food_group not in FOOD_GROUPS or food_group == "unknown":
			continue
		if not ingredient_groups.has(ingredient_id):
			ingredient_groups[ingredient_id] = {
				"food_group": food_group,
				"food_id": food_id,
			}
			continue
		var first := ingredient_groups[ingredient_id] as Dictionary
		if String(first.get("food_group", "")) == food_group:
			continue
		_add_error(
			errors,
			"ingredient_food_group_conflict",
			food_id,
			"components[%d].food_group" % component_index,
			(
				"Ingredient '%s' uses food_group '%s' here but '%s' in profile '%s'."
				% [
					ingredient_id,
					food_group,
					String(first.get("food_group", "")),
					String(first.get("food_id", "")),
				]
			)
		)


static func _validate_caffeine(
	profile: Dictionary,
	food_id: String,
	context: Dictionary,
	errors: Array[Dictionary],
	warnings: Array[Dictionary]
) -> void:
	var caffeine := _dictionary_field(profile, "caffeine", errors, food_id)
	var status := String(caffeine.get("status", ""))
	var band := String(caffeine.get("band", ""))
	var time_relevance := String(caffeine.get("serving_time_relevance", ""))
	if not status.is_empty():
		_validate_enum(status, CAFFEINE_STATUSES, errors, food_id, "caffeine.status")
	if not band.is_empty():
		_validate_enum(band, CAFFEINE_BANDS, errors, food_id, "caffeine.band")
	if not time_relevance.is_empty():
		_validate_enum(
			time_relevance,
			SERVING_TIME_RELEVANCE,
			errors,
			food_id,
			"caffeine.serving_time_relevance"
		)
	if caffeine.has("mg"):
		_validate_positive_number(caffeine["mg"], errors, food_id, "caffeine.mg")
	if status == "not_applicable":
		if caffeine.has("mg"):
			_add_error(
				errors,
				"caffeine_not_applicable_mg_present",
				food_id,
				"caffeine.mg",
				"Caffeine dose must be absent when caffeine status is not_applicable."
			)
		if band != "none":
			_add_error(
				errors,
				"caffeine_not_applicable_band_mismatch",
				food_id,
				"caffeine.band",
				"Caffeine band must be none when caffeine status is not_applicable."
			)
		if time_relevance != "none":
			_add_error(
				errors,
				"caffeine_not_applicable_time_mismatch",
				food_id,
				"caffeine.serving_time_relevance",
				(
					"Serving-time relevance must be none when caffeine status is "
					+ "not_applicable."
				)
			)

	var display_names: Dictionary = context.get("display_names", {})
	var search_text := "%s %s" % [food_id, String(display_names.get(food_id, ""))]
	if _contains_any_term(search_text, CAFFEINE_NAME_TERMS) and status.is_empty():
		_add_warning(
			warnings,
			"caffeine_status_missing",
			food_id,
			"caffeine.status",
			"Food name suggests coffee or tea but caffeine status is not recorded."
		)


static func _validate_profile_warnings(
	profile: Dictionary,
	food_id: String,
	context: Dictionary,
	factors: Array,
	warnings: Array[Dictionary]
) -> void:
	var review_status := String(profile.get("review_status", ""))
	if review_status == "draft":
		_add_warning(
			warnings,
			"profile_draft",
			food_id,
			"review_status",
			"Draft profiles cannot generate affirmative guidance."
		)
	var confidence := String(profile.get("confidence", ""))
	if confidence in ["low", "unknown"]:
		_add_warning(
			warnings,
			"confidence_limited",
			food_id,
			"confidence",
			"Profile confidence is %s." % confidence
		)

	var evidence_refs := _string_array(profile.get("evidence_refs", []))
	if _list_has(context.get("product_food_ids", []), food_id):
		var basis_type := String(profile.get("basis_type", ""))
		var has_pending_record := _arrays_intersect(
			evidence_refs,
			_string_array(context.get("pending_evidence_ids", DEFAULT_PENDING_EVIDENCE_IDS))
		)
		if basis_type not in ["package_label", "menu_recipe"] and not has_pending_record:
			_add_warning(
				warnings,
				"product_label_or_recipe_pending_missing",
				food_id,
				"evidence_refs",
				"Product profile needs a label/recipe basis or an explicit pending record."
			)

	var all_evidence_refs := evidence_refs.duplicate()
	for factor_value in factors:
		if factor_value is Dictionary:
			all_evidence_refs.append_array(
				_string_array((factor_value as Dictionary).get("evidence_refs", []))
			)
	var deprecated_ids := _string_array(context.get("deprecated_evidence_ids", []))
	var warned_ids := {}
	for evidence_id in all_evidence_refs:
		if deprecated_ids.has(evidence_id) and not warned_ids.has(evidence_id):
			warned_ids[evidence_id] = true
			_add_warning(
				warnings,
				"deprecated_evidence_reference",
				food_id,
				"evidence_refs",
				"Profile references deprecated evidence '%s'." % evidence_id
			)


static func _validate_optional_amount_pair(
	data: Dictionary,
	value_key: String,
	unit_key: String,
	allowed_units: Array,
	errors: Array[Dictionary],
	food_id: String,
	prefix: String
) -> void:
	var has_value := data.has(value_key)
	var has_unit := data.has(unit_key) and not String(data.get(unit_key, "")).is_empty()
	if has_value and not has_unit:
		_add_error(
			errors,
			"amount_unit_missing",
			food_id,
			"%s.%s" % [prefix, unit_key],
			"Amount value requires its unit."
		)
	elif has_unit and not has_value:
		_add_error(
			errors,
			"amount_value_missing",
			food_id,
			"%s.%s" % [prefix, value_key],
			"Amount unit requires its value."
		)
	if has_value:
		_validate_positive_number(data[value_key], errors, food_id, "%s.%s" % [prefix, value_key])
	if has_unit:
		_validate_enum(
			String(data[unit_key]),
			allowed_units,
			errors,
			food_id,
			"%s.%s" % [prefix, unit_key]
		)


static func _validate_positive_integer(
	value: Variant,
	errors: Array[Dictionary],
	food_id: String,
	field: String
) -> void:
	if typeof(value) != TYPE_INT or int(value) <= 0:
		_add_error(
			errors,
			"positive_integer_required",
			food_id,
			field,
			"Field must be a positive integer."
		)


static func _validate_positive_number(
	value: Variant,
	errors: Array[Dictionary],
	food_id: String,
	field: String
) -> void:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		_add_error(errors, "number_required", food_id, field, "Field must be numeric.")
	elif float(value) <= 0.0:
		_add_error(
			errors,
			"positive_number_required",
			food_id,
			field,
			"Amount must be greater than zero."
		)


static func _validate_enum(
	value: String,
	allowed: Array,
	errors: Array[Dictionary],
	food_id: String,
	field: String
) -> void:
	if not allowed.has(value):
		_add_error(
			errors,
			"invalid_enum",
			food_id,
			field,
			"Unsupported value '%s'." % value
		)


static func _profile_entries(catalog: Dictionary) -> Array:
	var entries: Variant = catalog.get("profile_entries", null)
	if entries is Array:
		return (entries as Array).duplicate(true)
	var fallback: Array = []
	var profiles: Dictionary = catalog.get("profiles", {})
	for profile in profiles.values():
		fallback.append((profile as Dictionary).duplicate(true))
	return fallback


static func _dictionary_field(
	data: Dictionary,
	field: String,
	errors: Array[Dictionary],
	food_id: String
) -> Dictionary:
	var value: Variant = data.get(field, {})
	if value is Dictionary:
		return value as Dictionary
	_add_error(
		errors,
		"field_type_invalid",
		food_id,
		field,
		"Field '%s' must be a dictionary." % field
	)
	return {}


static func _array_field(
	data: Dictionary,
	field: String,
	errors: Array[Dictionary],
	food_id: String
) -> Array:
	var value: Variant = data.get(field, [])
	if value is Array:
		return value as Array
	_add_error(
		errors,
		"field_type_invalid",
		food_id,
		field,
		"Field '%s' must be an array." % field
	)
	return []


static func _all_components_unknown(components: Array) -> bool:
	if components.is_empty():
		return false
	for component_value in components:
		if not component_value is Dictionary:
			return false
		var component := component_value as Dictionary
		if (
			String(component.get("food_group", "")) != "unknown"
			or String(component.get("contribution_band", "")) != "unknown"
		):
			return false
	return true


static func _has_factor_band(factors: Array, factor_id: String, band: String) -> bool:
	for factor_value in factors:
		if not factor_value is Dictionary:
			continue
		var factor := factor_value as Dictionary
		if (
			String(factor.get("factor_id", "")) == factor_id
			and String(factor.get("band", "")) == band
		):
			return true
	return false


static func _contains_any_term(value: String, terms: Array) -> bool:
	var normalized := value.to_lower()
	for term in terms:
		if normalized.contains(String(term).to_lower()):
			return true
	return false


static func _arrays_intersect(left: Array[String], right: Array[String]) -> bool:
	for value in left:
		if right.has(value):
			return true
	return false


static func _list_has(values: Variant, value: String) -> bool:
	var value_type := typeof(values)
	if value_type == TYPE_ARRAY or value_type == TYPE_PACKED_STRING_ARRAY:
		return values.has(value)
	return false


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	var value_type := typeof(value)
	if value_type == TYPE_ARRAY or value_type == TYPE_PACKED_STRING_ARRAY:
		for item in value:
			var text := String(item).strip_edges()
			if not text.is_empty():
				result.append(text)
	elif value_type == TYPE_STRING:
		for item in String(value).split(",", false):
			var text := String(item).strip_edges()
			if not text.is_empty():
				result.append(text)
	return result


static func _report(
	errors: Array[Dictionary],
	warnings: Array[Dictionary]
) -> Dictionary:
	return {
		"valid": errors.is_empty(),
		"error_count": errors.size(),
		"warning_count": warnings.size(),
		"errors": errors.duplicate(true),
		"warnings": warnings.duplicate(true),
	}


static func _add_error(
	errors: Array[Dictionary],
	code: String,
	food_id: String,
	field: String,
	message: String
) -> void:
	errors.append(_issue("error", code, food_id, field, message))


static func _add_warning(
	warnings: Array[Dictionary],
	code: String,
	food_id: String,
	field: String,
	message: String
) -> void:
	warnings.append(_issue("warning", code, food_id, field, message))


static func _issue(
	severity: String,
	code: String,
	food_id: String,
	field: String,
	message: String
) -> Dictionary:
	return {
		"severity": severity,
		"code": code,
		"food_id": food_id,
		"field": field,
		"path": field if food_id.is_empty() else "profile[%s].%s" % [food_id, field],
		"message": message,
	}
