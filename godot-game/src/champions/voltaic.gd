extends BaseChampion
class_name Voltaic
## Voltaic - Mage/Burst
## Role: High burst damage, poke, zone control
##
## Q - Arc Lightning: Fire a bolt that chains to nearby enemies
## W - Static Field: Create a zone that damages and slows enemies over time
## E - Overcharge: Empower next ability, adding bonus effects
## R - Thunderstorm: Channel a massive storm that strikes enemies in area


func _ready() -> void:
	champion_name = "Voltaic"

	# Mage stats
	base_health = 530.0
	base_mana = 420.0
	base_attack_damage = 52.0
	base_ability_power = 0.0
	base_armor = 22.0
	base_magic_resist = 30.0
	base_move_speed = 340.0
	base_attack_range = 525.0  # Ranged
	base_attack_speed = 0.625

	# Growth
	health_per_level = 82.0
	mana_per_level = 55.0
	attack_damage_per_level = 2.5
	armor_per_level = 3.0
	magic_resist_per_level = 1.25

	# Abilities
	abilities = {
		"Q": {
			"name": "Arc Lightning",
			"cooldown": 6.0,
			"mana_cost": 55.0,
			"current_cooldown": 0.0,
			"damage": 80.0,
			"ap_scaling": 0.65,
			"chain_count": 3,
			"chain_range": 300.0,
			"chain_damage_falloff": 0.75,
			"projectile_speed": 1400.0,
			"range": 700.0
		},
		"W": {
			"name": "Static Field",
			"cooldown": 12.0,
			"mana_cost": 70.0,
			"current_cooldown": 0.0,
			"damage_per_tick": 25.0,
			"ap_scaling": 0.15,
			"tick_rate": 0.5,
			"duration": 4.0,
			"radius": 250.0,
			"slow_percent": 0.25,
			"range": 800.0
		},
		"E": {
			"name": "Overcharge",
			"cooldown": 18.0,
			"mana_cost": 50.0,
			"current_cooldown": 0.0,
			"duration": 5.0,
			"bonus_damage_percent": 0.30,
			"mana_refund": 0.50
		},
		"R": {
			"name": "Thunderstorm",
			"cooldown": 120.0,
			"mana_cost": 150.0,
			"current_cooldown": 0.0,
			"level_required": 6,
			"damage_per_strike": 100.0,
			"ap_scaling": 0.25,
			"strike_count": 8,
			"strike_interval": 0.4,
			"radius": 450.0,
			"channel_duration": 3.2
		}
	}

	super._ready()


# Buff state
var overcharge_active: bool = false
var overcharge_timer: float = 0.0

# Channel state
var is_channeling: bool = false
var channel_ability: String = ""
var channel_timer: float = 0.0
var channel_target_pos: Vector2

# Active zones
var static_fields: Array = []

# Thunderstorm state
var storm_strikes_remaining: int = 0
var storm_strike_timer: float = 0.0
var storm_center: Vector2


func _physics_process(delta: float) -> void:
	if not is_alive:
		super._physics_process(delta)
		return

	# Handle Overcharge buff
	if overcharge_active:
		overcharge_timer -= delta
		if overcharge_timer <= 0:
			_end_overcharge()

	# Handle channeling
	if is_channeling:
		_process_channel(delta)
		return  # Can't move while channeling

	# Update static fields
	_update_static_fields(delta)

	super._physics_process(delta)


func _execute_ability(key: String, target_pos: Vector2, target_unit: Node2D) -> bool:
	match key:
		"Q":
			return _use_arc_lightning(target_pos, target_unit)
		"W":
			return _use_static_field(target_pos)
		"E":
			return _use_overcharge()
		"R":
			return _use_thunderstorm(target_pos)
	return false


func _use_arc_lightning(target_pos: Vector2, target_unit: Node2D) -> bool:
	var ability = abilities["Q"]

	# Calculate damage
	var base_damage = ability["damage"] + (ability_power * ability["ap_scaling"])
	if overcharge_active:
		base_damage *= (1.0 + abilities["E"]["bonus_damage_percent"])
		_consume_overcharge()

	# Spawn projectile
	var projectile_config = {
		"source": self,
		"target_pos": target_pos,
		"target_unit": target_unit,
		"speed": ability["projectile_speed"],
		"damage": base_damage,
		"damage_type": "magic",
		"max_range": ability["range"],
		"width": 30.0,
		"on_hit": func(hit_target): _chain_lightning(hit_target, base_damage, ability["chain_count"])
	}

	CombatSystem.spawn_projectile(projectile_config)
	print("[Voltaic] Arc Lightning fired")
	return true


func _chain_lightning(initial_target: Node2D, damage: float, chains_left: int) -> void:
	if chains_left <= 0:
		return

	var ability = abilities["Q"]
	var chain_damage = damage * ability["chain_damage_falloff"]

	# Find next target
	var checked = [initial_target]
	var next_target: Node2D = null
	var min_dist = ability["chain_range"]

	for enemy in CombatSystem.get_units_in_range(initial_target.position, ability["chain_range"], team):
		if enemy in checked:
			continue
		var dist = initial_target.position.distance_to(enemy.position)
		if dist < min_dist:
			min_dist = dist
			next_target = enemy

	if next_target:
		CombatSystem.deal_damage(self, next_target, chain_damage, "magic")
		print("[Voltaic] Arc chained to ", next_target.name if next_target.has_method("get") else "unit")
		# Recursively chain
		_chain_lightning(next_target, chain_damage, chains_left - 1)


func _use_static_field(target_pos: Vector2) -> bool:
	var ability = abilities["W"]

	# Check range
	if position.distance_to(target_pos) > ability["range"]:
		target_pos = position + (target_pos - position).normalized() * ability["range"]

	var damage_per_tick = ability["damage_per_tick"] + (ability_power * ability["ap_scaling"])
	if overcharge_active:
		damage_per_tick *= (1.0 + abilities["E"]["bonus_damage_percent"])
		_consume_overcharge()

	var field = {
		"position": target_pos,
		"radius": ability["radius"],
		"damage": damage_per_tick,
		"slow": ability["slow_percent"],
		"duration": ability["duration"],
		"tick_rate": ability["tick_rate"],
		"tick_timer": 0.0
	}

	static_fields.append(field)
	print("[Voltaic] Static Field created at ", target_pos)
	return true


func _update_static_fields(delta: float) -> void:
	var to_remove: Array = []

	for field in static_fields:
		field["duration"] -= delta
		field["tick_timer"] += delta

		# Apply damage on tick
		if field["tick_timer"] >= field["tick_rate"]:
			field["tick_timer"] = 0.0
			_apply_field_damage(field)

		if field["duration"] <= 0:
			to_remove.append(field)

	for field in to_remove:
		static_fields.erase(field)


func _apply_field_damage(field: Dictionary) -> void:
	var hit_units = CombatSystem.get_units_in_range(field["position"], field["radius"], team)
	for unit in hit_units:
		CombatSystem.deal_damage(self, unit, field["damage"], "magic")
		# TODO: Apply slow


func _use_overcharge() -> bool:
	overcharge_active = true
	overcharge_timer = abilities["E"]["duration"]
	print("[Voltaic] Overcharge activated - next ability empowered!")
	return true


func _consume_overcharge() -> void:
	if overcharge_active:
		# Refund some mana
		var refund = abilities["E"]["mana_cost"] * abilities["E"]["mana_refund"]
		restore_mana(refund)
		overcharge_active = false
		overcharge_timer = 0.0


func _end_overcharge() -> void:
	overcharge_active = false
	print("[Voltaic] Overcharge expired")


func _use_thunderstorm(target_pos: Vector2) -> bool:
	var ability = abilities["R"]

	is_channeling = true
	channel_ability = "R"
	channel_timer = ability["channel_duration"]
	channel_target_pos = target_pos

	storm_center = target_pos
	storm_strikes_remaining = ability["strike_count"]
	storm_strike_timer = 0.0

	is_moving = false
	velocity = Vector2.ZERO

	print("[Voltaic] THUNDERSTORM channeling!")
	return true


func _process_channel(delta: float) -> void:
	channel_timer -= delta

	if channel_ability == "R":
		_process_thunderstorm(delta)

	if channel_timer <= 0:
		_end_channel()


func _process_thunderstorm(delta: float) -> void:
	var ability = abilities["R"]

	storm_strike_timer += delta
	if storm_strike_timer >= ability["strike_interval"] and storm_strikes_remaining > 0:
		storm_strike_timer = 0.0
		storm_strikes_remaining -= 1

		# Random position within radius
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf() * ability["radius"]
		var strike_pos = storm_center + offset

		var damage = ability["damage_per_strike"] + (ability_power * ability["ap_scaling"])
		if overcharge_active and storm_strikes_remaining == ability["strike_count"] - 1:
			# First strike is empowered
			damage *= (1.0 + abilities["E"]["bonus_damage_percent"])
			_consume_overcharge()

		# Deal damage at strike position
		var strike_radius = 100.0
		CombatSystem.deal_aoe_damage(strike_pos, strike_radius, self, damage, "magic")


func _end_channel() -> void:
	is_channeling = false
	channel_ability = ""
	print("[Voltaic] Channel complete")


func take_damage(amount: float, source: Node2D, damage_type: String = "physical") -> float:
	# Interrupt channel if hit
	if is_channeling:
		_end_channel()
		print("[Voltaic] Channel interrupted!")

	return super.take_damage(amount, source, damage_type)


func get_observation() -> Dictionary:
	var obs = super.get_observation()
	obs["buffs"] = {
		"overcharge": {
			"active": overcharge_active,
			"remaining": overcharge_timer
		}
	}
	obs["is_channeling"] = is_channeling
	obs["static_fields"] = static_fields.map(func(f): return {"position": {"x": f["position"].x, "y": f["position"].y}, "radius": f["radius"], "duration": f["duration"]})
	return obs
