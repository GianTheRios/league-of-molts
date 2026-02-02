extends BaseChampion
class_name Shadebow
## Shadebow - Marksman/DPS
## Role: Sustained damage, kiting, trap placement
##
## Q - Shadow Arrow: Fire a piercing arrow that reveals and marks enemies
## W - Phantom Trap: Place an invisible trap that roots and damages
## E - Fade Step: Short dash that grants invisibility briefly
## R - Umbral Barrage: Rapid-fire a volley of shadow arrows at target area


func _ready() -> void:
	champion_name = "Shadebow"

	# Marksman stats
	base_health = 520.0
	base_mana = 280.0
	base_attack_damage = 58.0
	base_ability_power = 0.0
	base_armor = 24.0
	base_magic_resist = 28.0
	base_move_speed = 355.0
	base_attack_range = 575.0  # Long ranged
	base_attack_speed = 0.70

	# Growth
	health_per_level = 88.0
	mana_per_level = 35.0
	attack_damage_per_level = 3.8
	armor_per_level = 3.2
	magic_resist_per_level = 1.25

	# Abilities
	abilities = {
		"Q": {
			"name": "Shadow Arrow",
			"cooldown": 7.0,
			"mana_cost": 45.0,
			"current_cooldown": 0.0,
			"damage": 50.0,
			"ad_scaling": 1.1,
			"mark_duration": 4.0,
			"mark_bonus_damage": 0.10,  # +10% damage to marked targets
			"projectile_speed": 1800.0,
			"range": 1000.0,
			"piercing": true
		},
		"W": {
			"name": "Phantom Trap",
			"cooldown": 16.0,
			"mana_cost": 55.0,
			"current_cooldown": 0.0,
			"damage": 80.0,
			"ad_scaling": 0.6,
			"root_duration": 1.5,
			"arm_time": 1.0,
			"duration": 60.0,
			"max_traps": 3,
			"trigger_radius": 100.0
		},
		"E": {
			"name": "Fade Step",
			"cooldown": 14.0,
			"mana_cost": 60.0,
			"current_cooldown": 0.0,
			"dash_range": 350.0,
			"stealth_duration": 1.5,
			"attack_speed_bonus": 0.40,
			"buff_duration": 3.0
		},
		"R": {
			"name": "Umbral Barrage",
			"cooldown": 90.0,
			"mana_cost": 120.0,
			"current_cooldown": 0.0,
			"level_required": 6,
			"damage_per_arrow": 40.0,
			"ad_scaling": 0.30,
			"arrow_count": 8,
			"fire_rate": 0.15,
			"spread_radius": 300.0,
			"range": 900.0
		}
	}

	super._ready()


# State
var is_stealthed: bool = false
var stealth_timer: float = 0.0
var attack_speed_buff: bool = false
var attack_speed_buff_timer: float = 0.0

var is_dashing: bool = false
var dash_target: Vector2

var traps: Array = []
var marked_targets: Dictionary = {}  # unit -> mark_timer

# Barrage state
var is_barraging: bool = false
var barrage_target_pos: Vector2
var barrage_arrows_remaining: int = 0
var barrage_fire_timer: float = 0.0


func _physics_process(delta: float) -> void:
	if not is_alive:
		super._physics_process(delta)
		return

	# Update stealth
	if is_stealthed:
		stealth_timer -= delta
		if stealth_timer <= 0:
			_end_stealth()

	# Update attack speed buff
	if attack_speed_buff:
		attack_speed_buff_timer -= delta
		if attack_speed_buff_timer <= 0:
			_end_attack_speed_buff()

	# Update marks
	_update_marks(delta)

	# Update traps
	_update_traps(delta)

	# Handle dashing
	if is_dashing:
		_process_dash(delta)
		return

	# Handle barrage
	if is_barraging:
		_process_barrage(delta)
		return

	super._physics_process(delta)


func _execute_ability(key: String, target_pos: Vector2, target_unit: Node2D) -> bool:
	match key:
		"Q":
			return _use_shadow_arrow(target_pos, target_unit)
		"W":
			return _use_phantom_trap(target_pos)
		"E":
			return _use_fade_step(target_pos)
		"R":
			return _use_umbral_barrage(target_pos)
	return false


func _use_shadow_arrow(target_pos: Vector2, target_unit: Node2D) -> bool:
	var ability = abilities["Q"]

	var damage = ability["damage"] + (attack_damage * ability["ad_scaling"])

	# Spawn piercing projectile
	var projectile_config = {
		"source": self,
		"target_pos": target_pos,
		"speed": ability["projectile_speed"],
		"damage": damage,
		"damage_type": "physical",
		"max_range": ability["range"],
		"width": 25.0,
		"piercing": ability["piercing"],
		"on_hit": func(hit_target): _apply_shadow_mark(hit_target)
	}

	CombatSystem.spawn_projectile(projectile_config)

	# Break stealth
	if is_stealthed:
		_end_stealth()

	print("[Shadebow] Shadow Arrow fired")
	return true


func _apply_shadow_mark(target: Node2D) -> void:
	var ability = abilities["Q"]
	marked_targets[target] = ability["mark_duration"]
	print("[Shadebow] Marked: ", target.name if target.has_method("get") else "unit")


func _update_marks(delta: float) -> void:
	var to_remove: Array = []
	for target in marked_targets:
		marked_targets[target] -= delta
		if marked_targets[target] <= 0 or not is_instance_valid(target):
			to_remove.append(target)
	for target in to_remove:
		marked_targets.erase(target)


func _use_phantom_trap(target_pos: Vector2) -> bool:
	var ability = abilities["W"]

	# Limit traps
	while traps.size() >= ability["max_traps"]:
		var oldest = traps.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var trap = {
		"position": target_pos,
		"damage": ability["damage"] + (attack_damage * ability["ad_scaling"]),
		"root_duration": ability["root_duration"],
		"arm_timer": ability["arm_time"],
		"armed": false,
		"duration": ability["duration"],
		"trigger_radius": ability["trigger_radius"]
	}

	traps.append(trap)
	print("[Shadebow] Phantom Trap placed at ", target_pos)
	return true


func _update_traps(delta: float) -> void:
	var to_remove: Array = []

	for trap in traps:
		# Arm timer
		if not trap["armed"]:
			trap["arm_timer"] -= delta
			if trap["arm_timer"] <= 0:
				trap["armed"] = true

		# Duration
		trap["duration"] -= delta
		if trap["duration"] <= 0:
			to_remove.append(trap)
			continue

		# Check for triggers
		if trap["armed"]:
			for enemy in CombatSystem.get_units_in_range(trap["position"], trap["trigger_radius"], team):
				_trigger_trap(trap, enemy)
				to_remove.append(trap)
				break

	for trap in to_remove:
		traps.erase(trap)


func _trigger_trap(trap: Dictionary, target: Node2D) -> void:
	CombatSystem.deal_damage(self, target, trap["damage"], "physical")
	# TODO: Apply root
	print("[Shadebow] Trap triggered on: ", target.name if target.has_method("get") else "unit")


func _use_fade_step(target_pos: Vector2) -> bool:
	var ability = abilities["E"]

	var direction = (target_pos - position).normalized()
	dash_target = position + direction * ability["dash_range"]
	is_dashing = true
	is_moving = false

	print("[Shadebow] Fade Step!")
	return true


func _process_dash(delta: float) -> void:
	var dash_speed = 1200.0
	var direction = (dash_target - position).normalized()
	var distance = position.distance_to(dash_target)
	var move_dist = dash_speed * delta

	if distance <= move_dist:
		position = dash_target
		_end_dash()
	else:
		position += direction * move_dist


func _end_dash() -> void:
	is_dashing = false

	# Grant stealth and attack speed buff
	var ability = abilities["E"]

	is_stealthed = true
	stealth_timer = ability["stealth_duration"]

	attack_speed_buff = true
	attack_speed_buff_timer = ability["buff_duration"]
	attack_speed = base_attack_speed * (1.0 + ability["attack_speed_bonus"])

	print("[Shadebow] Stealthed and empowered!")


func _end_stealth() -> void:
	is_stealthed = false
	print("[Shadebow] Stealth ended")


func _end_attack_speed_buff() -> void:
	attack_speed_buff = false
	attack_speed = base_attack_speed
	_calculate_stats()


func _use_umbral_barrage(target_pos: Vector2) -> bool:
	var ability = abilities["R"]

	# Check range
	if position.distance_to(target_pos) > ability["range"]:
		target_pos = position + (target_pos - position).normalized() * ability["range"]

	is_barraging = true
	is_moving = false
	barrage_target_pos = target_pos
	barrage_arrows_remaining = ability["arrow_count"]
	barrage_fire_timer = 0.0

	# Break stealth
	if is_stealthed:
		_end_stealth()

	print("[Shadebow] UMBRAL BARRAGE!")
	return true


func _process_barrage(delta: float) -> void:
	if barrage_arrows_remaining <= 0:
		is_barraging = false
		return

	var ability = abilities["R"]
	barrage_fire_timer += delta

	if barrage_fire_timer >= ability["fire_rate"]:
		barrage_fire_timer = 0.0
		barrage_arrows_remaining -= 1

		# Fire arrow at random position in spread
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf() * ability["spread_radius"]
		var arrow_target = barrage_target_pos + offset

		var damage = ability["damage_per_arrow"] + (attack_damage * ability["ad_scaling"])

		# Check for marked target bonus
		for target in CombatSystem.get_units_in_range(arrow_target, 50.0, team):
			if target in marked_targets:
				damage *= (1.0 + abilities["Q"]["mark_bonus_damage"])
			CombatSystem.deal_damage(self, target, damage, "physical")


func _perform_auto_attack() -> void:
	# Break stealth on attack
	if is_stealthed:
		_end_stealth()

	# Check for mark bonus
	if current_target and current_target in marked_targets:
		var bonus_damage = attack_damage * abilities["Q"]["mark_bonus_damage"]
		var total_damage = calculate_physical_damage(attack_damage + bonus_damage)
		if current_target.has_method("take_damage"):
			current_target.take_damage(total_damage, self, "physical")
	else:
		super._perform_auto_attack()


func get_observation() -> Dictionary:
	var obs = super.get_observation()
	obs["buffs"] = {
		"stealth": {
			"active": is_stealthed,
			"remaining": stealth_timer
		},
		"attack_speed_buff": {
			"active": attack_speed_buff,
			"remaining": attack_speed_buff_timer
		}
	}
	obs["traps"] = traps.map(func(t): return {"position": {"x": t["position"].x, "y": t["position"].y}, "armed": t["armed"]})
	obs["marked_targets"] = marked_targets.keys().map(func(t): return t.get_meta("agent_id", str(t.get_instance_id())) if is_instance_valid(t) else "")
	return obs


func get_visible_position(observer_team: int) -> Dictionary:
	# Invisible when stealthed (enemy can't see)
	if is_stealthed and observer_team != team:
		return {}  # Empty = not visible
	return super.get_visible_position(observer_team)
