extends BaseChampion
class_name Ironclad
## Ironclad - Tank/Initiator
## Role: Frontline tank with CC and engage tools
##
## Q - Shield Bash: Short dash forward, stunning the first enemy hit
## W - Iron Will: Gain a shield and damage reduction for a short duration
## E - Tremor: Ground slam that slows enemies in a cone
## R - Unstoppable Charge: Long range charge that knocks aside enemies, ending with a slam

const DASH_SPEED := 800.0


func _ready() -> void:
	champion_name = "Ironclad"

	# Tank stats
	base_health = 650.0
	base_mana = 250.0
	base_attack_damage = 62.0
	base_armor = 38.0
	base_magic_resist = 32.0
	base_move_speed = 340.0
	base_attack_range = 125.0
	base_attack_speed = 0.65

	# Growth
	health_per_level = 98.0
	mana_per_level = 35.0
	attack_damage_per_level = 3.5
	armor_per_level = 4.2
	magic_resist_per_level = 1.5

	# Abilities
	abilities = {
		"Q": {
			"name": "Shield Bash",
			"cooldown": 8.0,
			"mana_cost": 40.0,
			"current_cooldown": 0.0,
			"damage": 60.0,
			"damage_scaling": 0.5,  # +50% AD
			"stun_duration": 1.0,
			"dash_range": 350.0
		},
		"W": {
			"name": "Iron Will",
			"cooldown": 14.0,
			"mana_cost": 60.0,
			"current_cooldown": 0.0,
			"shield_amount": 80.0,
			"shield_scaling": 0.1,  # +10% max health
			"damage_reduction": 0.15,
			"duration": 3.0
		},
		"E": {
			"name": "Tremor",
			"cooldown": 10.0,
			"mana_cost": 50.0,
			"current_cooldown": 0.0,
			"damage": 70.0,
			"damage_scaling": 0.4,  # +40% AD
			"slow_percent": 0.40,
			"slow_duration": 2.0,
			"range": 400.0,
			"cone_angle": 60.0
		},
		"R": {
			"name": "Unstoppable Charge",
			"cooldown": 100.0,
			"mana_cost": 100.0,
			"current_cooldown": 0.0,
			"level_required": 6,
			"damage": 150.0,
			"damage_scaling": 0.8,  # +80% AD
			"charge_speed": 1200.0,
			"charge_range": 800.0,
			"knockback_force": 300.0,
			"slam_radius": 250.0
		}
	}

	super._ready()


# Buff state
var iron_will_active: bool = false
var iron_will_timer: float = 0.0
var iron_will_shield: float = 0.0

# Dash state
var is_dashing: bool = false
var dash_target: Vector2
var dash_ability: String = ""


func _physics_process(delta: float) -> void:
	if not is_alive:
		super._physics_process(delta)
		return

	# Handle Iron Will buff
	if iron_will_active:
		iron_will_timer -= delta
		if iron_will_timer <= 0:
			_end_iron_will()

	# Handle dashing
	if is_dashing:
		_process_dash(delta)
	else:
		super._physics_process(delta)


func _execute_ability(key: String, target_pos: Vector2, target_unit: Node2D) -> bool:
	match key:
		"Q":
			return _use_shield_bash(target_pos)
		"W":
			return _use_iron_will()
		"E":
			return _use_tremor(target_pos)
		"R":
			return _use_unstoppable_charge(target_pos)
	return false


func _use_shield_bash(target_pos: Vector2) -> bool:
	var ability = abilities["Q"]
	var direction = (target_pos - position).normalized()
	var dash_end = position + direction * ability["dash_range"]

	is_dashing = true
	dash_target = dash_end
	dash_ability = "Q"
	is_moving = false

	return true


func _use_iron_will() -> bool:
	var ability = abilities["W"]

	iron_will_active = true
	iron_will_timer = ability["duration"]

	# Calculate shield
	iron_will_shield = ability["shield_amount"] + (max_health * ability["shield_scaling"])

	print("[Ironclad] Iron Will activated - Shield: %.0f" % iron_will_shield)
	return true


func _end_iron_will() -> void:
	iron_will_active = false
	iron_will_shield = 0.0
	print("[Ironclad] Iron Will expired")


func _use_tremor(target_pos: Vector2) -> bool:
	var ability = abilities["E"]

	# Get direction to target
	var direction = (target_pos - position).normalized()
	var damage = ability["damage"] + (attack_damage * ability["damage_scaling"])

	# Find enemies in cone
	var enemies_hit: Array = []
	var enemy_team = GameState.get_enemy_team(team)

	for enemy in CombatSystem.get_units_in_range(position, ability["range"], team):
		var to_enemy = (enemy.position - position).normalized()
		var angle = rad_to_deg(direction.angle_to(to_enemy))

		if abs(angle) <= ability["cone_angle"] / 2.0:
			enemies_hit.append(enemy)

	# Apply damage and slow
	for enemy in enemies_hit:
		CombatSystem.deal_damage(self, enemy, damage, "physical")
		# TODO: Apply slow debuff
		print("[Ironclad] Tremor hit: ", enemy.name if enemy.has_method("get") else "unit")

	return true


func _use_unstoppable_charge(target_pos: Vector2) -> bool:
	var ability = abilities["R"]
	var direction = (target_pos - position).normalized()
	var charge_end = position + direction * ability["charge_range"]

	is_dashing = true
	dash_target = charge_end
	dash_ability = "R"
	is_moving = false

	print("[Ironclad] UNSTOPPABLE CHARGE!")
	return true


func _process_dash(delta: float) -> void:
	var speed = DASH_SPEED
	if dash_ability == "R":
		speed = abilities["R"]["charge_speed"]

	var direction = (dash_target - position).normalized()
	var distance = position.distance_to(dash_target)
	var move_dist = speed * delta

	if distance <= move_dist:
		position = dash_target
		_end_dash()
	else:
		position += direction * move_dist
		_check_dash_collision()


func _check_dash_collision() -> void:
	var ability = abilities[dash_ability]
	var enemy_team = GameState.get_enemy_team(team)
	var hit_range = 50.0 if dash_ability == "Q" else 75.0

	for enemy in CombatSystem.get_units_in_range(position, hit_range, team):
		if dash_ability == "Q":
			# Shield Bash - stun first target and stop
			var damage = ability["damage"] + (attack_damage * ability["damage_scaling"])
			CombatSystem.deal_damage(self, enemy, damage, "physical")
			# TODO: Apply stun
			print("[Ironclad] Shield Bash stunned: ", enemy.name if enemy.has_method("get") else "unit")
			_end_dash()
			return
		elif dash_ability == "R":
			# Unstoppable Charge - knock aside and continue
			var damage = ability["damage"] * 0.5  # Half damage to passed-through enemies
			CombatSystem.deal_damage(self, enemy, damage, "physical")
			# TODO: Apply knockback


func _end_dash() -> void:
	is_dashing = false

	if dash_ability == "R":
		# Slam at end of charge
		var ability = abilities["R"]
		var damage = ability["damage"] + (attack_damage * ability["damage_scaling"])
		var hit_units = CombatSystem.deal_aoe_damage(position, ability["slam_radius"], self, damage, "physical")
		print("[Ironclad] Charge slam hit %d enemies" % hit_units.size())

	dash_ability = ""


func take_damage(amount: float, source: Node2D, damage_type: String = "physical") -> float:
	var actual_damage = amount

	# Apply Iron Will damage reduction
	if iron_will_active:
		actual_damage *= (1.0 - abilities["W"]["damage_reduction"])

	# Absorb with shield first
	if iron_will_shield > 0:
		if iron_will_shield >= actual_damage:
			iron_will_shield -= actual_damage
			return 0.0
		else:
			actual_damage -= iron_will_shield
			iron_will_shield = 0.0

	return super.take_damage(actual_damage, source, damage_type)
