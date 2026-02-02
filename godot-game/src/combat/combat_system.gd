extends Node
## Combat system singleton
## Handles damage calculation, projectiles, and combat events

signal damage_dealt(source: Node2D, target: Node2D, amount: float, damage_type: String)
signal unit_killed(unit: Node2D, killer: Node2D)
signal projectile_spawned(projectile: Node2D)

enum DamageType {
	PHYSICAL,
	MAGIC,
	TRUE  # Ignores resistances
}

# Active projectiles
var projectiles: Array = []

# Damage numbers (for UI)
var pending_damage_numbers: Array = []


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	_update_projectiles(delta)


func deal_damage(source: Node2D, target: Node2D, amount: float, damage_type: String = "physical") -> float:
	## Deal damage from source to target, returns actual damage dealt
	if not target or not is_instance_valid(target):
		return 0.0

	var actual_damage: float = amount

	# Apply resistances
	match damage_type:
		"physical":
			actual_damage = _apply_armor(target, amount)
		"magic":
			actual_damage = _apply_magic_resist(target, amount)
		"true":
			actual_damage = amount  # No reduction

	# Apply damage to target
	if target.has_method("take_damage"):
		actual_damage = target.take_damage(actual_damage, source, damage_type)
	elif target.has_meta("health"):
		var health = target.get_meta("health") - actual_damage
		target.set_meta("health", health)
		if health <= 0:
			_handle_death(target, source)

	damage_dealt.emit(source, target, actual_damage, damage_type)

	# Queue damage number for UI
	pending_damage_numbers.append({
		"position": target.position,
		"amount": actual_damage,
		"type": damage_type,
		"is_crit": false  # TODO: Implement crits
	})

	return actual_damage


func _apply_armor(target: Node2D, damage: float) -> float:
	var armor = 0.0
	if target.has_method("get"):
		armor = target.get("armor") if "armor" in target else 0.0
	elif target.has_meta("armor"):
		armor = target.get_meta("armor")

	var reduction = armor / (100.0 + armor)
	return damage * (1.0 - reduction)


func _apply_magic_resist(target: Node2D, damage: float) -> float:
	var mr = 0.0
	if target.has_method("get"):
		mr = target.get("magic_resist") if "magic_resist" in target else 0.0
	elif target.has_meta("magic_resist"):
		mr = target.get_meta("magic_resist")

	var reduction = mr / (100.0 + mr)
	return damage * (1.0 - reduction)


func _handle_death(unit: Node2D, killer: Node2D) -> void:
	unit_killed.emit(unit, killer)

	# Award rewards
	if killer:
		var gold_reward = 0
		var xp_reward = 0

		if unit.is_in_group("minions"):
			gold_reward = GameState.config["gold_per_minion_kill"]
			xp_reward = GameState.config["xp_per_minion_kill"]
		elif unit.is_in_group("champions"):
			gold_reward = GameState.config["gold_per_champion_kill"]
			xp_reward = GameState.config["xp_per_champion_kill"]

		if killer.has_method("add_gold"):
			killer.add_gold(gold_reward)
		if killer.has_method("add_xp"):
			killer.add_xp(xp_reward)

	# Remove minions
	if unit.is_in_group("minions"):
		unit.queue_free()


# === PROJECTILE SYSTEM ===

func spawn_projectile(config: Dictionary) -> Node2D:
	## Spawn a projectile with given configuration
	## config: {source, target_pos, target_unit, speed, damage, damage_type, on_hit, width, piercing}

	var projectile = Node2D.new()
	projectile.set_meta("source", config.get("source"))
	projectile.set_meta("target_pos", config.get("target_pos", Vector2.ZERO))
	projectile.set_meta("target_unit", config.get("target_unit"))
	projectile.set_meta("speed", config.get("speed", 1000.0))
	projectile.set_meta("damage", config.get("damage", 0.0))
	projectile.set_meta("damage_type", config.get("damage_type", "physical"))
	projectile.set_meta("width", config.get("width", 20.0))
	projectile.set_meta("piercing", config.get("piercing", false))
	projectile.set_meta("hit_units", [])
	projectile.set_meta("max_range", config.get("max_range", 1000.0))
	projectile.set_meta("traveled", 0.0)

	if config.has("on_hit"):
		projectile.set_meta("on_hit", config["on_hit"])

	# Set initial position
	var source = config.get("source")
	if source:
		projectile.position = source.position

	# Calculate direction
	var target_pos = config.get("target_pos", Vector2.ZERO)
	var target_unit = config.get("target_unit")
	if target_unit and is_instance_valid(target_unit):
		target_pos = target_unit.position

	var direction = (target_pos - projectile.position).normalized()
	projectile.set_meta("direction", direction)

	# Visual (placeholder)
	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderTexture2D.new()
	sprite.texture.size = Vector2(config.get("width", 20.0), 10.0)
	sprite.rotation = direction.angle()
	projectile.add_child(sprite)

	# Add to scene
	var arena = get_tree().get_first_node_in_group("arena")
	if arena and arena.has_node("Projectiles"):
		arena.get_node("Projectiles").add_child(projectile)
	else:
		get_tree().current_scene.add_child(projectile)

	projectiles.append(projectile)
	projectile_spawned.emit(projectile)

	return projectile


func _update_projectiles(delta: float) -> void:
	var to_remove: Array = []

	for projectile in projectiles:
		if not is_instance_valid(projectile):
			to_remove.append(projectile)
			continue

		var speed = projectile.get_meta("speed")
		var direction = projectile.get_meta("direction")
		var max_range = projectile.get_meta("max_range")
		var traveled = projectile.get_meta("traveled")

		# Move projectile
		var movement = direction * speed * delta
		projectile.position += movement
		traveled += movement.length()
		projectile.set_meta("traveled", traveled)

		# Check for homing
		var target_unit = projectile.get_meta("target_unit")
		if target_unit and is_instance_valid(target_unit):
			direction = (target_unit.position - projectile.position).normalized()
			projectile.set_meta("direction", direction)

		# Check collisions
		_check_projectile_collisions(projectile)

		# Check range
		if traveled >= max_range:
			to_remove.append(projectile)
			projectile.queue_free()

	# Remove dead projectiles
	for proj in to_remove:
		projectiles.erase(proj)


func _check_projectile_collisions(projectile: Node2D) -> void:
	var source = projectile.get_meta("source")
	var source_team = source.get_meta("team", -1) if source else -1
	var width = projectile.get_meta("width")
	var piercing = projectile.get_meta("piercing")
	var hit_units = projectile.get_meta("hit_units")

	# Check champions
	for champion in get_tree().get_nodes_in_group("champions"):
		if champion == source:
			continue
		if champion.get_meta("team", -1) == source_team:
			continue
		if champion in hit_units:
			continue

		var dist = projectile.position.distance_to(champion.position)
		if dist <= width + 25:  # 25 = champion collision radius
			_on_projectile_hit(projectile, champion)
			hit_units.append(champion)
			if not piercing:
				projectile.queue_free()
				projectiles.erase(projectile)
				return

	# Check minions
	for minion in get_tree().get_nodes_in_group("minions"):
		if minion.get_meta("team", -1) == source_team:
			continue
		if minion in hit_units:
			continue

		var dist = projectile.position.distance_to(minion.position)
		if dist <= width + 15:  # 15 = minion collision radius
			_on_projectile_hit(projectile, minion)
			hit_units.append(minion)
			if not piercing:
				projectile.queue_free()
				projectiles.erase(projectile)
				return


func _on_projectile_hit(projectile: Node2D, target: Node2D) -> void:
	var source = projectile.get_meta("source")
	var damage = projectile.get_meta("damage")
	var damage_type = projectile.get_meta("damage_type")

	deal_damage(source, target, damage, damage_type)

	# Call on_hit callback if present
	if projectile.has_meta("on_hit"):
		var callback = projectile.get_meta("on_hit")
		if callback is Callable:
			callback.call(target)


# === AREA OF EFFECT ===

func deal_aoe_damage(center: Vector2, radius: float, source: Node2D, damage: float, damage_type: String = "magic", hit_allies: bool = false) -> Array:
	## Deal damage to all units in radius, returns hit units
	var source_team = source.get_meta("team", -1) if source else -1
	var hit_units: Array = []

	# Check champions
	for champion in get_tree().get_nodes_in_group("champions"):
		if champion == source:
			continue
		if not hit_allies and champion.get_meta("team", -1) == source_team:
			continue

		var dist = center.distance_to(champion.position)
		if dist <= radius:
			deal_damage(source, champion, damage, damage_type)
			hit_units.append(champion)

	# Check minions
	for minion in get_tree().get_nodes_in_group("minions"):
		if not hit_allies and minion.get_meta("team", -1) == source_team:
			continue

		var dist = center.distance_to(minion.position)
		if dist <= radius:
			deal_damage(source, minion, damage, damage_type)
			hit_units.append(minion)

	return hit_units


# === UTILITY ===

func get_units_in_range(center: Vector2, radius: float, filter_team: int = -1, include_dead: bool = false) -> Array:
	## Get all units within radius
	var units: Array = []

	for champion in get_tree().get_nodes_in_group("champions"):
		if filter_team != -1 and champion.get_meta("team", -1) == filter_team:
			continue
		if not include_dead and champion.has_method("get") and not champion.is_alive:
			continue

		var dist = center.distance_to(champion.position)
		if dist <= radius:
			units.append(champion)

	for minion in get_tree().get_nodes_in_group("minions"):
		if filter_team != -1 and minion.get_meta("team", -1) == filter_team:
			continue

		var dist = center.distance_to(minion.position)
		if dist <= radius:
			units.append(minion)

	return units


func get_nearest_enemy(pos: Vector2, team: int, max_range: float = 9999.0) -> Node2D:
	## Find nearest enemy unit to position
	var nearest: Node2D = null
	var nearest_dist: float = max_range

	var enemy_team = GameState.get_enemy_team(team)

	for champion in get_tree().get_nodes_in_group("champions"):
		if champion.get_meta("team", -1) != enemy_team:
			continue
		var dist = pos.distance_to(champion.position)
		if dist < nearest_dist:
			nearest = champion
			nearest_dist = dist

	for minion in get_tree().get_nodes_in_group("minions"):
		if minion.get_meta("team", -1) != enemy_team:
			continue
		var dist = pos.distance_to(minion.position)
		if dist < nearest_dist:
			nearest = minion
			nearest_dist = dist

	return nearest


func pop_damage_numbers() -> Array:
	## Get and clear pending damage numbers for UI rendering
	var numbers = pending_damage_numbers.duplicate()
	pending_damage_numbers.clear()
	return numbers
