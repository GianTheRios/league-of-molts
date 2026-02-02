extends Node
## Network manager singleton
## Handles WebSocket server for agent connections

signal agent_connected(agent_id: String)
signal agent_disconnected(agent_id: String)
signal agent_action_received(agent_id: String, action: Dictionary)

const DEFAULT_PORT := 9050
const TICK_RATE := 20  # Hz
const TICK_INTERVAL := 1.0 / TICK_RATE

var server: TCPServer
var websocket_peers: Dictionary = {}  # peer_id -> AgentConnection
var agent_to_peer: Dictionary = {}    # agent_id -> peer_id

var tick_timer: float = 0.0
var is_running: bool = false

# Reference to arena
var arena: Arena


func _ready() -> void:
	set_process(false)


func start_server(port: int = DEFAULT_PORT) -> Error:
	server = TCPServer.new()
	var err = server.listen(port)
	if err != OK:
		push_error("[NetworkManager] Failed to start server on port ", port)
		return err

	is_running = true
	set_process(true)
	print("[NetworkManager] Server started on port ", port)
	return OK


func stop_server() -> void:
	is_running = false
	set_process(false)

	# Disconnect all peers
	for peer_id in websocket_peers:
		var conn = websocket_peers[peer_id]
		if conn.socket:
			conn.socket.close()

	websocket_peers.clear()
	agent_to_peer.clear()

	if server:
		server.stop()
		server = null

	print("[NetworkManager] Server stopped")


func _process(delta: float) -> void:
	if not is_running:
		return

	# Accept new connections
	_poll_new_connections()

	# Update existing connections
	_poll_peers()

	# Send observations at tick rate
	tick_timer += delta
	if tick_timer >= TICK_INTERVAL:
		tick_timer = 0.0
		_broadcast_observations()


func _poll_new_connections() -> void:
	if not server or not server.is_listening():
		return

	while server.is_connection_available():
		var tcp_peer = server.take_connection()
		if tcp_peer:
			var ws = WebSocketPeer.new()
			ws.accept_stream(tcp_peer)

			var peer_id = tcp_peer.get_instance_id()
			var conn = AgentConnection.new()
			conn.socket = ws
			conn.tcp = tcp_peer
			conn.state = AgentConnection.State.CONNECTING
			websocket_peers[peer_id] = conn

			print("[NetworkManager] New connection pending: ", peer_id)


func _poll_peers() -> void:
	var to_remove: Array = []

	for peer_id in websocket_peers:
		var conn: AgentConnection = websocket_peers[peer_id]
		conn.socket.poll()

		var state = conn.socket.get_ready_state()

		match state:
			WebSocketPeer.STATE_OPEN:
				if conn.state == AgentConnection.State.CONNECTING:
					conn.state = AgentConnection.State.CONNECTED
					print("[NetworkManager] WebSocket opened: ", peer_id)

				# Process incoming messages
				while conn.socket.get_available_packet_count() > 0:
					var packet = conn.socket.get_packet()
					_handle_message(peer_id, conn, packet)

			WebSocketPeer.STATE_CLOSING:
				pass  # Wait for close

			WebSocketPeer.STATE_CLOSED:
				to_remove.append(peer_id)
				var code = conn.socket.get_close_code()
				var reason = conn.socket.get_close_reason()
				print("[NetworkManager] Connection closed: ", peer_id, " code=", code, " reason=", reason)

				if conn.agent_id:
					agent_disconnected.emit(conn.agent_id)
					agent_to_peer.erase(conn.agent_id)

	# Remove closed connections
	for peer_id in to_remove:
		websocket_peers.erase(peer_id)


func _handle_message(peer_id: int, conn: AgentConnection, packet: PackedByteArray) -> void:
	var text = packet.get_string_from_utf8()
	var json = JSON.new()
	var err = json.parse(text)

	if err != OK:
		push_warning("[NetworkManager] Invalid JSON from ", peer_id, ": ", json.get_error_message())
		return

	var data: Dictionary = json.data
	var msg_type = data.get("type", "")

	match msg_type:
		"auth":
			_handle_auth(peer_id, conn, data)
		"action":
			_handle_action(peer_id, conn, data)
		"ping":
			_send_to_peer(peer_id, {"type": "pong", "timestamp": data.get("timestamp", 0)})
		_:
			push_warning("[NetworkManager] Unknown message type: ", msg_type)


func _handle_auth(peer_id: int, conn: AgentConnection, data: Dictionary) -> void:
	var agent_id = data.get("agent_id", "")
	var token = data.get("token", "")  # For future auth

	if agent_id.is_empty():
		_send_to_peer(peer_id, {"type": "auth_error", "message": "Missing agent_id"})
		return

	# Check if agent already connected
	if agent_to_peer.has(agent_id):
		_send_to_peer(peer_id, {"type": "auth_error", "message": "Agent already connected"})
		return

	# Register agent
	conn.agent_id = agent_id
	conn.state = AgentConnection.State.AUTHENTICATED
	agent_to_peer[agent_id] = peer_id

	# Determine team (simple round-robin for now)
	var blue_count = GameState.teams[GameState.Team.BLUE]["agents"].size()
	var red_count = GameState.teams[GameState.Team.RED]["agents"].size()
	var team = GameState.Team.BLUE if blue_count <= red_count else GameState.Team.RED

	if GameState.register_agent(agent_id, team):
		_send_to_peer(peer_id, {
			"type": "auth_success",
			"agent_id": agent_id,
			"team": "blue" if team == GameState.Team.BLUE else "red"
		})
		agent_connected.emit(agent_id)
		print("[NetworkManager] Agent authenticated: ", agent_id, " on team ", team)

		# Spawn champion for agent
		if arena:
			var champion = arena.spawn_champion(agent_id, "ironclad", team)
			conn.champion = champion
	else:
		_send_to_peer(peer_id, {"type": "auth_error", "message": "Team is full"})


func _handle_action(peer_id: int, conn: AgentConnection, data: Dictionary) -> void:
	if conn.state != AgentConnection.State.AUTHENTICATED:
		return

	if not conn.champion or not is_instance_valid(conn.champion):
		return

	var actions = data.get("actions", [])
	for action in actions:
		_execute_action(conn.champion, action)

	agent_action_received.emit(conn.agent_id, data)


func _execute_action(champion: Node2D, action: Dictionary) -> void:
	var action_type = action.get("action_type", "")

	match action_type:
		"move":
			var target = action.get("target", {})
			var pos = Vector2(target.get("x", 0), target.get("y", 0))
			if champion.has_method("move_to"):
				champion.move_to(pos)

		"stop":
			if champion.has_method("stop"):
				champion.stop()

		"attack":
			var target_id = action.get("target_id", "")
			var target = _find_entity_by_id(target_id)
			if target and champion.has_method("attack_target"):
				champion.attack_target(target)

		"ability":
			var ability_key = action.get("ability", "")
			var target = action.get("target", {})
			var target_pos = Vector2(target.get("x", 0), target.get("y", 0))
			var target_id = action.get("target_id", "")
			var target_unit = _find_entity_by_id(target_id) if target_id else null

			if champion.has_method("use_ability"):
				champion.use_ability(ability_key, target_pos, target_unit)

		"buy":
			var item_id = action.get("item_id", "")
			# TODO: Implement shop system
			pass


func _find_entity_by_id(entity_id: String) -> Node2D:
	# Search champions
	for champion in get_tree().get_nodes_in_group("champions"):
		if champion.get_meta("agent_id", "") == entity_id:
			return champion

	# Search minions (by instance ID for now)
	# TODO: Implement proper minion IDs

	return null


func _broadcast_observations() -> void:
	if GameState.match_state != GameState.MatchState.PLAYING:
		return

	for peer_id in websocket_peers:
		var conn: AgentConnection = websocket_peers[peer_id]
		if conn.state != AgentConnection.State.AUTHENTICATED:
			continue
		if not conn.champion or not is_instance_valid(conn.champion):
			continue

		var observation = _build_observation(conn)
		_send_to_peer(peer_id, observation)


func _build_observation(conn: AgentConnection) -> Dictionary:
	var champion = conn.champion
	var team = champion.get_meta("team", 0)
	var enemy_team = GameState.get_enemy_team(team)

	# Self observation
	var self_obs = champion.get_observation() if champion.has_method("get_observation") else _basic_observation(champion)

	# Allies
	var allies: Array = []
	for ally in GameState.get_team_champions(team):
		if ally != champion:
			if ally.has_method("get_observation"):
				allies.append(ally.get_observation())
			else:
				allies.append(_basic_observation(ally))

	# Enemies (with fog of war - for now all visible)
	var enemies: Array = []
	for enemy in GameState.get_team_champions(enemy_team):
		if enemy.has_method("get_visible_position"):
			enemies.append(enemy.get_visible_position(team))
		else:
			enemies.append(_basic_observation(enemy))

	# Minions
	var allied_minions: Array = []
	var enemy_minions: Array = []
	for minion in get_tree().get_nodes_in_group("minions"):
		var minion_team = minion.get_meta("team", -1)
		var minion_data = _minion_observation(minion)
		if minion_team == team:
			allied_minions.append(minion_data)
		else:
			enemy_minions.append(minion_data)

	# Structures
	var structures = _get_structure_observations()

	return {
		"type": "observation",
		"tick": GameState.current_tick,
		"match_time": GameState.match_duration,
		"self": self_obs,
		"allies": allies,
		"enemies": enemies,
		"minions": {
			"allied": allied_minions,
			"enemy": enemy_minions
		},
		"structures": structures
	}


func _basic_observation(entity: Node2D) -> Dictionary:
	return {
		"position": {"x": entity.position.x, "y": entity.position.y},
		"health": entity.get_meta("health", 0),
		"max_health": entity.get_meta("max_health", 0),
		"team": entity.get_meta("team", -1)
	}


func _minion_observation(minion: Node2D) -> Dictionary:
	return {
		"id": str(minion.get_instance_id()),
		"position": {"x": minion.position.x, "y": minion.position.y},
		"health": minion.get_meta("health", 0),
		"max_health": minion.get_meta("max_health", 0),
		"is_melee": minion.get_meta("is_melee", true)
	}


func _get_structure_observations() -> Dictionary:
	# TODO: Implement proper structure tracking
	return {
		"towers": {
			"blue": [],
			"red": []
		},
		"nexus": {
			"blue": {"health": GameState.teams[GameState.Team.BLUE]["nexus_health"]},
			"red": {"health": GameState.teams[GameState.Team.RED]["nexus_health"]}
		}
	}


func _send_to_peer(peer_id: int, data: Dictionary) -> void:
	if not websocket_peers.has(peer_id):
		return

	var conn = websocket_peers[peer_id]
	if conn.socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	var json_str = JSON.stringify(data)
	conn.socket.send_text(json_str)


func broadcast_event(event: Dictionary) -> void:
	## Broadcast a game event to all connected agents
	for peer_id in websocket_peers:
		var conn = websocket_peers[peer_id]
		if conn.state == AgentConnection.State.AUTHENTICATED:
			_send_to_peer(peer_id, event)


# === AgentConnection class ===

class AgentConnection:
	enum State {
		CONNECTING,
		CONNECTED,
		AUTHENTICATED,
		DISCONNECTED
	}

	var socket: WebSocketPeer
	var tcp: StreamPeerTCP
	var agent_id: String = ""
	var state: State = State.CONNECTING
	var champion: Node2D = null
	var last_action_tick: int = 0
