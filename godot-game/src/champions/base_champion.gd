extends CharacterBody2D
class_name BaseChampion
## Base class for all champions in League of Molts

signal health_changed(current: float, max_val: float)
signal mana_changed(current: float, max_val: float)
signal died(killer: Node2D)
signal respawned
signal level_up(new_level: int)
signal ability_used(ability_key: String)
signal gold_changed(amount: int, total: int)

# Identity
@export var champion_name: String = "BaseChampion"
@export var agent_id: String = ""
@export var team: int = 0

# Base Stats (level 1)
@export_group("Base Stats")
@export var base_health: float = 600.0
@export var base_mana: float = 300.0
@export var base_attack_damage: float = 60.0
@export var base_ability_power: float = 0.0
@export var base_armor: float = 30.0
@export var base_magic_resist: float = 25.0
@export var base_move_speed: float = 350.0
@export var base_attack_range: float = 125.0
@export var base_attack_speed: float = 0.7  # attacks per second

# Stat growth per level
@export_group("Stat Growth")
@export var health_per_level: float = 90.0
@export var mana_per_level: float = 40.0
@export var attack_damage_per_level: float = 3.0
@export var armor_per_level: float = 3.5
@export var magic_resist_per_level: float = 1.25

# Current stats
var health: float
var max_health: float
var mana: float
var max_mana: float
var attack_damage: float
var ability_power: float
var armor: float
var magic_resist: float
var move_speed: float
var attack_range: float
var attack_speed: float

# Progression
var level: int = 1
var xp: int = 0
var gold: int = 500

# XP thresholds per level
const XP_PER_LEVEL := [0, 280, 380, 480, 580, 680, 780, 880, 980, 1080, 1180, 1280, 1380, 1480, 1580, 1680, 1780, 1880]
const MAX_LEVEL := 18

# State
var is_alive: bool = true
var is_moving: bool = false
var target_position: Vector2
var current_target: Node2D = null
var respawn_timer: float = 0.0
var attack_cooldown: float = 0.0

# Abilities (override in subclasses)
var abilities: Dictionary = {
	"Q": {"name": "Basic Q", "cooldown": 5.0, "mana_cost": 50.0, "current_cooldown": 0.0},
	"W": {"name": "Basic W", "cooldown": 8.0, "mana_cost": 60.0, "current_cooldown": 0.0},
	"E": {"name": "Basic E", "cooldown": 10.0, "mana_cost": 70.0, "current_cooldown": 0.0},
	"R": {"name": "Ultimate", "cooldown": 60.0, "mana_cost": 100.0, "current_cooldown": 0.0, "level_required": 6}
}

# Items
var items: Array = []
const MAX_ITEMS := 6

# Components
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = $HealthBar if has_node("HealthBar") else null


func _ready() -> void:
	_calculate_stats()
	health = max_health
	mana = max_mana
	target_position = position
	add_to_group("champions")
	add_to_group("team_" + str(team))


func _physics_process(delta: float) -> void:
	if not is_alive:
		_handle_respawn(delta)
		return

	_update_cooldowns(delta)
	_handle_movement(delta)
	_handle_auto_attack(delta)


func _calculate_stats() -> void:
	## Recalculate all stats based on level and items
	var lvl_bonus = level - 1

	max_health = base_health + (health_per_level * lvl_bonus)
	max_mana = base_mana + (mana_per_level * lvl_bonus)
	attack_damage = base_attack_damage + (attack_damage_per_level * lvl_bonus)
	ability_power = base_ability_power
	armor = base_armor + (armor_per_level * lvl_bonus)
	magic_resist = base_magic_resist + (magic_resist_per_level * lvl_bonus)
	move_speed = base_move_speed
	attack_range = base_attack_range
	attack_speed = base_attack_speed

	# Apply item bonuses
	for item in items:
		if item.has("health"):
			max_health += item["health"]
		if item.has("mana"):
			max_mana += item["mana"]
		if item.has("attack_damage"):
			attack_damage += item["attack_damage"]
		if item.has("ability_power"):
			ability_power += item["ability_power"]
		if item.has("armor"):
			armor += item["armor"]
		if item.has("magic_resist"):
			magic_resist += item["magic_resist"]
		if item.has("move_speed"):
			move_speed += item["move_speed"]


func _handle_movement(delta: float) -> void:
	if not is_moving:
		return

	var direction = (target_position - position).normalized()
	var distance = position.distance_to(target_position)

	if distance < 10:
		is_moving = false
		velocity = Vector2.ZERO
	else:
		velocity = direction * move_speed

	move_and_slide()


func _handle_auto_attack(delta: float) -> void:
	attack_cooldown -= delta

	if current_target and is_instance_valid(current_target):
		var distance = position.distance_to(current_target.position)
		if distance <= attack_range and attack_cooldown <= 0:
			_perform_auto_attack()
			attack_cooldown = 1.0 / attack_speed


func _perform_auto_attack() -> void:
	if not current_target or not is_instance_valid(current_target):
		return

	var damage = calculate_physical_damage(attack_damage)
	if current_target.has_method("take_damage"):
		current_target.take_damage(damage, self, "physical")


func _update_cooldowns(delta: float) -> void:
	for key in abilities:
		if abilities[key]["current_cooldown"] > 0:
			abilities[key]["current_cooldown"] -= delta


func _handle_respawn(delta: float) -> void:
	respawn_timer -= delta
	if respawn_timer <= 0:
		_respawn()


# === PUBLIC API ===

func move_to(pos: Vector2) -> void:
	## Move champion to target position
	target_position = pos
	is_moving = true
	current_target = null  # Cancel auto attack when moving


func stop() -> void:
	## Stop all movement
	is_moving = false
	velocity = Vector2.ZERO


func attack_target(target: Node2D) -> void:
	## Set auto attack target
	if target and is_instance_valid(target):
		current_target = target
		# Move into range if needed
		var distance = position.distance_to(target.position)
		if distance > attack_range:
			move_to(target.position)


func use_ability(key: String, target_pos: Vector2 = Vector2.ZERO, target_unit: Node2D = null) -> bool:
	## Use an ability. Override in subclasses for specific behavior
	if not abilities.has(key):
		return false

	var ability = abilities[key]

	# Check level requirement
	if ability.has("level_required") and level < ability["level_required"]:
		return false

	# Check cooldown
	if ability["current_cooldown"] > 0:
		return false

	# Check mana
	if mana < ability["mana_cost"]:
		return false

	# Execute ability (override _execute_ability in subclass)
	if _execute_ability(key, target_pos, target_unit):
		mana -= ability["mana_cost"]
		ability["current_cooldown"] = ability["cooldown"]
		mana_changed.emit(mana, max_mana)
		ability_used.emit(key)
		return true

	return false


func _execute_ability(key: String, target_pos: Vector2, target_unit: Node2D) -> bool:
	## Override in subclass to implement ability logic
	print("[%s] Used ability %s" % [champion_name, key])
	return true


func take_damage(amount: float, source: Node2D, damage_type: String = "physical") -> float:
	## Take damage and return actual damage dealt
	if not is_alive:
		return 0.0

	var actual_damage = amount
	if damage_type == "physical":
		actual_damage = calculate_physical_damage_taken(amount)
	elif damage_type == "magic":
		actual_damage = calculate_magic_damage_taken(amount)

	health -= actual_damage
	health_changed.emit(health, max_health)

	if health <= 0:
		_die(source)

	return actual_damage


func heal(amount: float) -> float:
	## Heal and return actual healing done
	var actual_heal = min(amount, max_health - health)
	health += actual_heal
	health_changed.emit(health, max_health)
	return actual_heal


func restore_mana(amount: float) -> float:
	var actual_restore = min(amount, max_mana - mana)
	mana += actual_restore
	mana_changed.emit(mana, max_mana)
	return actual_restore


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(amount, gold)
	GameState.gold_changed.emit(agent_id, gold)


func add_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return

	xp += amount

	# Check for level up
	while level < MAX_LEVEL and xp >= XP_PER_LEVEL[level]:
		xp -= XP_PER_LEVEL[level]
		_level_up()


func buy_item(item: Dictionary) -> bool:
	## Purchase an item from the shop
	if items.size() >= MAX_ITEMS:
		return false
	if gold < item.get("cost", 0):
		return false

	gold -= item["cost"]
	items.append(item)
	_calculate_stats()
	gold_changed.emit(-item["cost"], gold)
	return true


func calculate_physical_damage(base_damage: float) -> float:
	## Calculate outgoing physical damage
	return base_damage


func calculate_physical_damage_taken(damage: float) -> float:
	## Calculate damage reduction from armor
	var reduction = armor / (100.0 + armor)
	return damage * (1.0 - reduction)


func calculate_magic_damage_taken(damage: float) -> float:
	## Calculate damage reduction from magic resist
	var reduction = magic_resist / (100.0 + magic_resist)
	return damage * (1.0 - reduction)


func _die(killer: Node2D) -> void:
	is_alive = false
	is_moving = false
	velocity = Vector2.ZERO
	visible = false

	# Calculate respawn time
	respawn_timer = GameState.RESPAWN_TIME_BASE + (level * GameState.RESPAWN_TIME_PER_LEVEL)

	died.emit(killer)
	GameState.on_champion_death(self, killer)

	# Award gold/xp to killer
	if killer and killer.has_method("add_gold"):
		killer.add_gold(GameState.config["gold_per_champion_kill"])
	if killer and killer.has_method("add_xp"):
		killer.add_xp(GameState.config["xp_per_champion_kill"])


func _respawn() -> void:
	is_alive = true
	visible = true

	# Reset to spawn position
	var arena = get_tree().get_first_node_in_group("arena") as Arena
	if arena:
		position = arena.get_spawn_position(team)
	else:
		position = Vector2(800, 2000) if team == GameState.Team.BLUE else Vector2(7200, 2000)

	# Reset health/mana
	health = max_health
	mana = max_mana
	health_changed.emit(health, max_health)
	mana_changed.emit(mana, max_mana)

	respawned.emit()


func _level_up() -> void:
	level += 1
	_calculate_stats()

	# Heal percentage on level up
	health = min(health + max_health * 0.1, max_health)
	mana = min(mana + max_mana * 0.1, max_mana)

	level_up.emit(level)
	print("[%s] Leveled up to %d" % [champion_name, level])


# === SERIALIZATION ===

func get_observation() -> Dictionary:
	## Get observation data for agent API
	return {
		"id": agent_id,
		"champion": champion_name,
		"position": {"x": position.x, "y": position.y},
		"health": health,
		"max_health": max_health,
		"mana": mana,
		"max_mana": max_mana,
		"level": level,
		"xp": xp,
		"gold": gold,
		"is_alive": is_alive,
		"abilities": _get_ability_states(),
		"items": items,
		"stats": {
			"attack_damage": attack_damage,
			"ability_power": ability_power,
			"armor": armor,
			"magic_resist": magic_resist,
			"move_speed": move_speed,
			"attack_range": attack_range,
			"attack_speed": attack_speed
		}
	}


func _get_ability_states() -> Dictionary:
	var states = {}
	for key in abilities:
		var ability = abilities[key]
		states[key] = {
			"name": ability["name"],
			"ready": ability["current_cooldown"] <= 0 and mana >= ability["mana_cost"],
			"cooldown_remaining": ability["current_cooldown"],
			"mana_cost": ability["mana_cost"]
		}
		if ability.has("level_required"):
			states[key]["level_required"] = ability["level_required"]
			states[key]["unlocked"] = level >= ability["level_required"]
	return states


func get_visible_position(observer_team: int) -> Dictionary:
	## Get position data visible to enemy team (for fog of war)
	# For now, always visible - fog of war implemented later
	return {
		"id": agent_id,
		"champion": champion_name,
		"position": {"x": position.x, "y": position.y},
		"health": health,
		"max_health": max_health,
		"level": level,
		"is_alive": is_alive
	}
