class_name MealDeckService
extends RefCounted

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	set_seed(seed_value)


func set_seed(seed_value: int = -1) -> void:
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value


func build_hand(
	candidate_ids: Array[String],
	hand_size: int,
	inventory: Dictionary = {},
	uses_inventory: bool = false
) -> Array[String]:
	var pool: Array[String] = []
	for id in candidate_ids:
		if pool.has(id):
			continue
		if uses_inventory and int(inventory.get(id, 0)) <= 0:
			continue
		pool.append(id)

	_shuffle(pool)
	var result: Array[String] = []
	for index in range(min(hand_size, pool.size())):
		result.append(pool[index])
	return result


func _shuffle(values: Array[String]) -> void:
	if values.size() < 2:
		return
	for index in range(values.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var previous := values[index]
		values[index] = values[swap_index]
		values[swap_index] = previous
