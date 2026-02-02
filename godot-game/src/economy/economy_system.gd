extends Node
## Economy system singleton
## Manages gold, XP, items, and shop

signal item_purchased(agent_id: String, item: Dictionary)
signal item_sold(agent_id: String, item: Dictionary)

# Item database
var items: Dictionary = {}

# Passive gold generation
const PASSIVE_GOLD_INTERVAL := 1.0
const PASSIVE_GOLD_AMOUNT := 2

var passive_gold_timer: float = 0.0


func _ready() -> void:
	_load_items()


func _process(delta: float) -> void:
	if GameState.match_state != GameState.MatchState.PLAYING:
		return

	# Passive gold generation
	passive_gold_timer += delta
	if passive_gold_timer >= PASSIVE_GOLD_INTERVAL:
		passive_gold_timer = 0.0
		_distribute_passive_gold()


func _load_items() -> void:
	## Load item definitions
	# Basic items (components)
	items = {
		# === BASIC ITEMS ===
		"long_sword": {
			"id": "long_sword",
			"name": "Long Sword",
			"cost": 350,
			"attack_damage": 10,
			"tier": 1
		},
		"amplifying_tome": {
			"id": "amplifying_tome",
			"name": "Amplifying Tome",
			"cost": 435,
			"ability_power": 20,
			"tier": 1
		},
		"ruby_crystal": {
			"id": "ruby_crystal",
			"name": "Ruby Crystal",
			"cost": 400,
			"health": 150,
			"tier": 1
		},
		"cloth_armor": {
			"id": "cloth_armor",
			"name": "Cloth Armor",
			"cost": 300,
			"armor": 15,
			"tier": 1
		},
		"null_magic_mantle": {
			"id": "null_magic_mantle",
			"name": "Null-Magic Mantle",
			"cost": 450,
			"magic_resist": 25,
			"tier": 1
		},
		"boots": {
			"id": "boots",
			"name": "Boots",
			"cost": 300,
			"move_speed": 25,
			"tier": 1
		},
		"sapphire_crystal": {
			"id": "sapphire_crystal",
			"name": "Sapphire Crystal",
			"cost": 350,
			"mana": 250,
			"tier": 1
		},
		"dagger": {
			"id": "dagger",
			"name": "Dagger",
			"cost": 300,
			"attack_speed": 0.12,
			"tier": 1
		},

		# === TIER 2 ITEMS ===
		"pickaxe": {
			"id": "pickaxe",
			"name": "Pickaxe",
			"cost": 875,
			"attack_damage": 25,
			"tier": 2,
			"builds_from": ["long_sword"]
		},
		"blasting_wand": {
			"id": "blasting_wand",
			"name": "Blasting Wand",
			"cost": 850,
			"ability_power": 40,
			"tier": 2,
			"builds_from": ["amplifying_tome"]
		},
		"giants_belt": {
			"id": "giants_belt",
			"name": "Giant's Belt",
			"cost": 900,
			"health": 350,
			"tier": 2,
			"builds_from": ["ruby_crystal"]
		},
		"chain_vest": {
			"id": "chain_vest",
			"name": "Chain Vest",
			"cost": 800,
			"armor": 40,
			"tier": 2,
			"builds_from": ["cloth_armor"]
		},
		"berserker_greaves": {
			"id": "berserker_greaves",
			"name": "Berserker's Greaves",
			"cost": 1100,
			"move_speed": 45,
			"attack_speed": 0.35,
			"tier": 2,
			"builds_from": ["boots", "dagger"]
		},

		# === TIER 3 ITEMS (Complete) ===
		"infinity_edge": {
			"id": "infinity_edge",
			"name": "Infinity Edge",
			"cost": 3400,
			"attack_damage": 70,
			"crit_chance": 0.25,
			"tier": 3,
			"builds_from": ["pickaxe", "pickaxe"],
			"passive": "Critical strikes deal 35% bonus damage"
		},
		"rabadons_deathcap": {
			"id": "rabadons_deathcap",
			"name": "Rabadon's Deathcap",
			"cost": 3600,
			"ability_power": 120,
			"tier": 3,
			"builds_from": ["blasting_wand", "blasting_wand"],
			"passive": "Increases total Ability Power by 35%"
		},
		"warmogs_armor": {
			"id": "warmogs_armor",
			"name": "Warmog's Armor",
			"cost": 3000,
			"health": 800,
			"health_regen": 200,
			"tier": 3,
			"builds_from": ["giants_belt", "giants_belt"],
			"passive": "Regenerate 5% max health per second when out of combat"
		},
		"thornmail": {
			"id": "thornmail",
			"name": "Thornmail",
			"cost": 2700,
			"armor": 80,
			"health": 350,
			"tier": 3,
			"builds_from": ["chain_vest", "giants_belt"],
			"passive": "Reflect 25% of physical damage taken back to attacker"
		},
		"void_staff": {
			"id": "void_staff",
			"name": "Void Staff",
			"cost": 2800,
			"ability_power": 65,
			"magic_penetration_percent": 0.40,
			"tier": 3,
			"builds_from": ["blasting_wand"],
			"passive": "Magic damage ignores 40% of target's Magic Resist"
		},
		"guardian_angel": {
			"id": "guardian_angel",
			"name": "Guardian Angel",
			"cost": 2800,
			"attack_damage": 40,
			"armor": 40,
			"tier": 3,
			"builds_from": ["pickaxe", "chain_vest"],
			"passive": "Upon death, revive with 50% health after 4 seconds (300s cooldown)"
		}
	}


func _distribute_passive_gold() -> void:
	for champion in get_tree().get_nodes_in_group("champions"):
		if champion.has_method("add_gold"):
			champion.add_gold(PASSIVE_GOLD_AMOUNT)


func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})


func get_all_items() -> Dictionary:
	return items


func get_items_by_tier(tier: int) -> Array:
	var result: Array = []
	for item_id in items:
		if items[item_id].get("tier", 0) == tier:
			result.append(items[item_id])
	return result


func can_purchase(champion: Node2D, item_id: String) -> bool:
	var item = get_item(item_id)
	if item.is_empty():
		return false

	# Check gold
	var gold = champion.get("gold") if champion.has_method("get") else champion.get_meta("gold", 0)
	if gold < item["cost"]:
		return false

	# Check inventory space
	var current_items = champion.get("items") if champion.has_method("get") else []
	if current_items.size() >= 6:
		return false

	return true


func purchase_item(champion: Node2D, item_id: String) -> bool:
	if not can_purchase(champion, item_id):
		return false

	var item = get_item(item_id).duplicate()

	if champion.has_method("buy_item"):
		return champion.buy_item(item)
	else:
		# Direct meta manipulation
		var gold = champion.get_meta("gold", 0)
		champion.set_meta("gold", gold - item["cost"])

		var current_items = champion.get_meta("items", [])
		current_items.append(item)
		champion.set_meta("items", current_items)

		var agent_id = champion.get_meta("agent_id", "")
		item_purchased.emit(agent_id, item)
		return true


func sell_item(champion: Node2D, item_index: int) -> bool:
	var current_items = []
	if champion.has_method("get"):
		current_items = champion.items
	else:
		current_items = champion.get_meta("items", [])

	if item_index < 0 or item_index >= current_items.size():
		return false

	var item = current_items[item_index]
	var sell_value = int(item["cost"] * 0.7)  # 70% refund

	current_items.remove_at(item_index)

	if champion.has_method("add_gold"):
		champion.add_gold(sell_value)
	else:
		var gold = champion.get_meta("gold", 0)
		champion.set_meta("gold", gold + sell_value)

	var agent_id = champion.get_meta("agent_id", "")
	item_sold.emit(agent_id, item)
	return true


func get_shop_data() -> Dictionary:
	## Get shop data formatted for agent API
	return {
		"items": items,
		"categories": {
			"attack_damage": get_items_with_stat("attack_damage"),
			"ability_power": get_items_with_stat("ability_power"),
			"defense": get_items_with_stat("armor") + get_items_with_stat("magic_resist"),
			"health": get_items_with_stat("health"),
			"boots": get_items_with_stat("move_speed")
		}
	}


func get_items_with_stat(stat: String) -> Array:
	var result: Array = []
	for item_id in items:
		if items[item_id].has(stat):
			result.append(item_id)
	return result


func calculate_item_stats(item_list: Array) -> Dictionary:
	## Sum up all stats from a list of items
	var stats = {
		"health": 0,
		"mana": 0,
		"attack_damage": 0,
		"ability_power": 0,
		"armor": 0,
		"magic_resist": 0,
		"move_speed": 0,
		"attack_speed": 0.0,
		"crit_chance": 0.0
	}

	for item in item_list:
		for stat in stats:
			if item.has(stat):
				stats[stat] += item[stat]

	return stats
