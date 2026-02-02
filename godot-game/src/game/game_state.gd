extends Node
## Global game state singleton
## Manages match state, teams, and synchronization

signal match_started
signal match_ended(winning_team: int)
signal champion_spawned(champion: Node2D)
signal champion_died(champion: Node2D, killer: Node2D)
signal tower_destroyed(tower: Node2D, team: int)
signal gold_changed(agent_id: String, amount: int)

enum MatchState {
	WAITING,      # Waiting for agents to connect
	CHAMPION_SELECT,  # Agents selecting champions
	LOADING,      # Loading match
	PLAYING,      # Match in progress
	PAUSED,       # Match paused
	ENDED         # Match ended
}

enum Team {
	BLUE = 0,
	RED = 1
}

const TICK_RATE := 20  # Hz - observations per second
const MAX_AGENTS_PER_TEAM := 3
const RESPAWN_TIME_BASE := 5.0  # seconds
const RESPAWN_TIME_PER_LEVEL := 2.0

var match_state: MatchState = MatchState.WAITING
var current_tick: int = 0
var match_start_time: float = 0.0
var match_duration: float = 0.0

# Team data
var teams: Dictionary = {
	Team.BLUE: {
		"agents": [],
		"champions": [],
		"towers_remaining": 2,
		"nexus_health": 5000.0
	},
	Team.RED: {
		"agents": [],
		"champions": [],
		"towers_remaining": 2,
		"nexus_health": 5000.0
	}
}

# Agent to champion mapping
var agent_champions: Dictionary = {}  # agent_id -> Champion node

# Match configuration
var config: Dictionary = {
	"max_match_duration": 1800.0,  # 30 minutes
	"minion_spawn_interval": 30.0,
	"gold_per_minion_kill": 20,
	"gold_per_champion_kill": 300,
	"gold_per_assist": 150,
	"xp_per_minion_kill": 30,
	"xp_per_champion_kill": 200
}


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if match_state == MatchState.PLAYING:
		current_tick += 1
		match_duration += delta

		# Check win conditions
		_check_win_conditions()


func start_match() -> void:
	if match_state != MatchState.LOADING:
		push_warning("Cannot start match from state: ", match_state)
		return

	match_state = MatchState.PLAYING
	match_start_time = Time.get_unix_time_from_system()
	current_tick = 0
	set_process(true)
	match_started.emit()
	print("[GameState] Match started")


func end_match(winning_team: int) -> void:
	match_state = MatchState.ENDED
	set_process(false)
	match_ended.emit(winning_team)
	print("[GameState] Match ended - Winner: ", "BLUE" if winning_team == Team.BLUE else "RED")


func register_agent(agent_id: String, team: int) -> bool:
	if teams[team]["agents"].size() >= MAX_AGENTS_PER_TEAM:
		return false

	teams[team]["agents"].append(agent_id)
	print("[GameState] Agent registered: ", agent_id, " on team ", team)
	return true


func assign_champion(agent_id: String, champion: Node2D) -> void:
	agent_champions[agent_id] = champion
	var team = get_agent_team(agent_id)
	if team != -1:
		teams[team]["champions"].append(champion)
	champion_spawned.emit(champion)


func get_agent_team(agent_id: String) -> int:
	for team in [Team.BLUE, Team.RED]:
		if agent_id in teams[team]["agents"]:
			return team
	return -1


func get_champion_for_agent(agent_id: String) -> Node2D:
	return agent_champions.get(agent_id)


func get_all_champions() -> Array:
	var all_champs: Array = []
	all_champs.append_array(teams[Team.BLUE]["champions"])
	all_champs.append_array(teams[Team.RED]["champions"])
	return all_champs


func get_team_champions(team: int) -> Array:
	return teams[team]["champions"]


func get_enemy_team(team: int) -> int:
	return Team.RED if team == Team.BLUE else Team.BLUE


func on_champion_death(champion: Node2D, killer: Node2D) -> void:
	champion_died.emit(champion, killer)

	# Calculate respawn time
	var level = champion.level if champion.has_method("get") else 1
	var respawn_time = RESPAWN_TIME_BASE + (level * RESPAWN_TIME_PER_LEVEL)

	# Award gold/xp to killer
	if killer and killer.has_method("add_gold"):
		killer.add_gold(config["gold_per_champion_kill"])


func on_tower_destroyed(tower: Node2D, team: int) -> void:
	teams[team]["towers_remaining"] -= 1
	tower_destroyed.emit(tower, team)
	print("[GameState] Tower destroyed - Team ", team, " has ", teams[team]["towers_remaining"], " remaining")


func damage_nexus(team: int, damage: float) -> void:
	teams[team]["nexus_health"] -= damage
	if teams[team]["nexus_health"] <= 0:
		var winning_team = get_enemy_team(team)
		end_match(winning_team)


func _check_win_conditions() -> void:
	# Check nexus destruction
	for team in [Team.BLUE, Team.RED]:
		if teams[team]["nexus_health"] <= 0:
			end_match(get_enemy_team(team))
			return

	# Check time limit
	if match_duration >= config["max_match_duration"]:
		# Determine winner by remaining nexus health
		var blue_health = teams[Team.BLUE]["nexus_health"]
		var red_health = teams[Team.RED]["nexus_health"]
		if blue_health > red_health:
			end_match(Team.BLUE)
		elif red_health > blue_health:
			end_match(Team.RED)
		else:
			# True tie - blue wins by default (rare)
			end_match(Team.BLUE)


func get_match_snapshot() -> Dictionary:
	## Returns current match state for serialization
	return {
		"tick": current_tick,
		"state": match_state,
		"duration": match_duration,
		"teams": {
			"blue": {
				"nexus_health": teams[Team.BLUE]["nexus_health"],
				"towers_remaining": teams[Team.BLUE]["towers_remaining"]
			},
			"red": {
				"nexus_health": teams[Team.RED]["nexus_health"],
				"towers_remaining": teams[Team.RED]["towers_remaining"]
			}
		}
	}
