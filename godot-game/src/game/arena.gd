extends Node2D
## Main arena scene - manages the game map and entities
class_name Arena

signal minion_wave_spawned(team: int, minions: Array)

# Lane configuration
const LANE_LENGTH := 8000.0  # pixels from nexus to nexus
const LANE_WIDTH := 400.0

# Spawn positions
const BLUE_NEXUS_POS := Vector2(500, 2000)
const RED_NEXUS_POS := Vector2(7500, 2000)
const BLUE_SPAWN_POS := Vector2(800, 2000)
const RED_SPAWN_POS := Vector2(7200, 2000)

# Tower positions (2 per team)
const BLUE_TOWER_POSITIONS := [
	Vector2(1500, 2000),  # Outer tower
	Vector2(2500, 2000)   # Inner tower
]
const RED_TOWER_POSITIONS := [
	Vector2(6500, 2000),  # Outer tower
	Vector2(5500, 2000)   # Inner tower
]

# Minion spawn
const MINION_SPAWN_INTERVAL := 30.0
const MINIONS_PER_WAVE := 6
const MELEE_MINIONS := 3
const CASTER_MINIONS := 3

var minion_spawn_timer: float = 0.0
var minion_wave_count: int = 0

# Scene references
@onready var champions_container: Node2D = $Champions
@onready var minions_container: Node2D = $Minions
@onready var towers_container: Node2D = $Towers
@onready var projectiles_container: Node2D = $Projectiles

# Preloaded scenes
var tower_scene: PackedScene
var minion_scene: PackedScene
var nexus_scene: PackedScene

# Entity references
var towers: Dictionary = {
	GameState.Team.BLUE: [],
	GameState.Team.RED: []
}
var nexuses: Dictionary = {}


func _ready() -> void:
	_setup_containers()
	_load_scenes()
	_spawn_structures()

	# Connect to game state
	GameState.match_started.connect(_on_match_started)
	GameState.match_ended.connect(_on_match_ended)


func _setup_containers() -> void:
	# Create containers if they don't exist
	if not has_node("Champions"):
		champions_container = Node2D.new()
		champions_container.name = "Champions"
		add_child(champions_container)

	if not has_node("Minions"):
		minions_container = Node2D.new()
		minions_container.name = "Minions"
		add_child(minions_container)

	if not has_node("Towers"):
		towers_container = Node2D.new()
		towers_container.name = "Towers"
		add_child(towers_container)

	if not has_node("Projectiles"):
		projectiles_container = Node2D.new()
		projectiles_container.name = "Projectiles"
		add_child(projectiles_container)


func _load_scenes() -> void:
	# Load scene files (will be created later)
	if ResourceLoader.exists("res://src/game/tower.tscn"):
		tower_scene = load("res://src/game/tower.tscn")
	if ResourceLoader.exists("res://src/units/minion.tscn"):
		minion_scene = load("res://src/units/minion.tscn")
	if ResourceLoader.exists("res://src/game/nexus.tscn"):
		nexus_scene = load("res://src/game/nexus.tscn")


func _spawn_structures() -> void:
	# Spawn towers for both teams
	for i in range(BLUE_TOWER_POSITIONS.size()):
		_spawn_tower(BLUE_TOWER_POSITIONS[i], GameState.Team.BLUE, i)

	for i in range(RED_TOWER_POSITIONS.size()):
		_spawn_tower(RED_TOWER_POSITIONS[i], GameState.Team.RED, i)

	# Spawn nexuses
	_spawn_nexus(BLUE_NEXUS_POS, GameState.Team.BLUE)
	_spawn_nexus(RED_NEXUS_POS, GameState.Team.RED)


func _spawn_tower(pos: Vector2, team: int, index: int) -> void:
	if tower_scene:
		var tower = tower_scene.instantiate()
		tower.position = pos
		tower.team = team
		tower.tower_index = index
		towers_container.add_child(tower)
		towers[team].append(tower)
	else:
		# Create placeholder
		var placeholder = _create_tower_placeholder(pos, team)
		towers_container.add_child(placeholder)
		towers[team].append(placeholder)


func _create_tower_placeholder(pos: Vector2, team: int) -> Node2D:
	var tower = Node2D.new()
	tower.position = pos
	tower.set_meta("team", team)
	tower.set_meta("health", 3000.0)
	tower.set_meta("max_health", 3000.0)
	tower.set_meta("attack_damage", 150.0)
	tower.set_meta("attack_range", 600.0)

	# Visual placeholder
	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderTexture2D.new()
	sprite.texture.size = Vector2(80, 120)
	sprite.modulate = Color.CORNFLOWER_BLUE if team == GameState.Team.BLUE else Color.INDIAN_RED
	tower.add_child(sprite)

	return tower


func _spawn_nexus(pos: Vector2, team: int) -> void:
	if nexus_scene:
		var nexus = nexus_scene.instantiate()
		nexus.position = pos
		nexus.team = team
		add_child(nexus)
		nexuses[team] = nexus
	else:
		# Create placeholder
		var placeholder = _create_nexus_placeholder(pos, team)
		add_child(placeholder)
		nexuses[team] = placeholder


func _create_nexus_placeholder(pos: Vector2, team: int) -> Node2D:
	var nexus = Node2D.new()
	nexus.position = pos
	nexus.set_meta("team", team)

	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderTexture2D.new()
	sprite.texture.size = Vector2(150, 150)
	sprite.modulate = Color.BLUE if team == GameState.Team.BLUE else Color.RED
	nexus.add_child(sprite)

	return nexus


func _process(delta: float) -> void:
	if GameState.match_state != GameState.MatchState.PLAYING:
		return

	# Minion spawning
	minion_spawn_timer += delta
	if minion_spawn_timer >= MINION_SPAWN_INTERVAL:
		minion_spawn_timer = 0.0
		_spawn_minion_wave(GameState.Team.BLUE)
		_spawn_minion_wave(GameState.Team.RED)
		minion_wave_count += 1


func _spawn_minion_wave(team: int) -> void:
	var spawn_pos = BLUE_SPAWN_POS if team == GameState.Team.BLUE else RED_SPAWN_POS
	var spawned_minions: Array = []

	for i in range(MINIONS_PER_WAVE):
		var minion = _create_minion(team, i < MELEE_MINIONS)
		# Stagger spawn positions slightly
		var offset = Vector2(0, (i - MINIONS_PER_WAVE / 2.0) * 40)
		minion.position = spawn_pos + offset
		minions_container.add_child(minion)
		spawned_minions.append(minion)

	minion_wave_spawned.emit(team, spawned_minions)
	print("[Arena] Spawned wave ", minion_wave_count, " for team ", team)


func _create_minion(team: int, is_melee: bool) -> Node2D:
	if minion_scene:
		var minion = minion_scene.instantiate()
		minion.team = team
		minion.is_melee = is_melee
		return minion
	else:
		# Create placeholder minion
		return _create_minion_placeholder(team, is_melee)


func _create_minion_placeholder(team: int, is_melee: bool) -> Node2D:
	var minion = CharacterBody2D.new()
	minion.set_meta("team", team)
	minion.set_meta("is_melee", is_melee)
	minion.set_meta("health", 300.0 if is_melee else 200.0)
	minion.set_meta("max_health", 300.0 if is_melee else 200.0)
	minion.set_meta("attack_damage", 20.0 if is_melee else 30.0)
	minion.set_meta("attack_range", 100.0 if is_melee else 400.0)
	minion.set_meta("move_speed", 250.0)

	# Visual
	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderTexture2D.new()
	sprite.texture.size = Vector2(30, 30) if is_melee else Vector2(25, 25)
	sprite.modulate = Color.LIGHT_BLUE if team == GameState.Team.BLUE else Color.LIGHT_CORAL
	minion.add_child(sprite)

	# Collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15.0
	collision.shape = shape
	minion.add_child(collision)

	# Add minion script behavior
	var script = GDScript.new()
	script.source_code = """
extends CharacterBody2D

var target_position: Vector2
var team: int

func _ready():
	team = get_meta("team")
	# Set target to enemy nexus
	target_position = Vector2(7500, 2000) if team == 0 else Vector2(500, 2000)

func _physics_process(delta):
	var direction = (target_position - position).normalized()
	velocity = direction * get_meta("move_speed")
	move_and_slide()
"""
	minion.set_script(script)

	return minion


func spawn_champion(agent_id: String, champion_type: String, team: int) -> Node2D:
	var spawn_pos = BLUE_SPAWN_POS if team == GameState.Team.BLUE else RED_SPAWN_POS

	# Try to load champion scene
	var champion_path = "res://src/champions/" + champion_type.to_lower() + ".tscn"
	var champion: Node2D

	if ResourceLoader.exists(champion_path):
		champion = load(champion_path).instantiate()
	else:
		# Use base champion
		champion = _create_base_champion(agent_id, team)

	champion.position = spawn_pos
	champion.set_meta("agent_id", agent_id)
	champion.set_meta("team", team)
	champions_container.add_child(champion)

	GameState.assign_champion(agent_id, champion)
	return champion


func _create_base_champion(agent_id: String, team: int) -> Node2D:
	var champion = CharacterBody2D.new()
	champion.name = "Champion_" + agent_id

	# Stats
	champion.set_meta("agent_id", agent_id)
	champion.set_meta("team", team)
	champion.set_meta("health", 600.0)
	champion.set_meta("max_health", 600.0)
	champion.set_meta("mana", 300.0)
	champion.set_meta("max_mana", 300.0)
	champion.set_meta("attack_damage", 60.0)
	champion.set_meta("ability_power", 0.0)
	champion.set_meta("armor", 30.0)
	champion.set_meta("magic_resist", 25.0)
	champion.set_meta("move_speed", 350.0)
	champion.set_meta("attack_range", 125.0)
	champion.set_meta("level", 1)
	champion.set_meta("xp", 0)
	champion.set_meta("gold", 500)

	# Visual
	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderTexture2D.new()
	sprite.texture.size = Vector2(50, 50)
	sprite.modulate = Color.DODGER_BLUE if team == GameState.Team.BLUE else Color.CRIMSON
	champion.add_child(sprite)

	# Collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 25.0
	collision.shape = shape
	champion.add_child(collision)

	return champion


func get_spawn_position(team: int) -> Vector2:
	return BLUE_SPAWN_POS if team == GameState.Team.BLUE else RED_SPAWN_POS


func get_entities_in_range(pos: Vector2, range_val: float, filter_team: int = -1) -> Array:
	var entities: Array = []

	# Check champions
	for champion in champions_container.get_children():
		if filter_team != -1 and champion.get_meta("team") == filter_team:
			continue
		if pos.distance_to(champion.position) <= range_val:
			entities.append(champion)

	# Check minions
	for minion in minions_container.get_children():
		if filter_team != -1 and minion.get_meta("team") == filter_team:
			continue
		if pos.distance_to(minion.position) <= range_val:
			entities.append(minion)

	return entities


func _on_match_started() -> void:
	# Spawn first minion wave immediately
	_spawn_minion_wave(GameState.Team.BLUE)
	_spawn_minion_wave(GameState.Team.RED)


func _on_match_ended(_winning_team: int) -> void:
	set_process(false)
