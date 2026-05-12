

# PlayerManager.gd — Autoload
extends Node

const TOTAL_WORLDS     = 5
const LEVELS_PER_WORLD = 30

var player_data  := {}
var worlds_cache := {}
var is_loaded    := false

signal player_loaded(data: Dictionary)
signal player_created(data: Dictionary)
signal world_updated(world_id: String)


# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZE — call on game start
# ═══════════════════════════════════════════════════════════════════════════════

func initialize():
	print("[Player] Initializing...")

	# Try local cache first — fastest
	var cached = LocalCache._load_local_player_backup()
	if not cached.is_empty():
		player_data  = cached
		worlds_cache = LocalCache.get_all_worlds()
		is_loaded    = true
		print("[Player] Loaded from cache: ", player_data.get("name", "Unknown"))
		emit_signal("player_loaded", player_data)
		# Sync with Firestore in background
		_sync_from_firestore_background()
		return

	# No cache — load from Firestore
	await _load_from_firestore()


# ═══════════════════════════════════════════════════════════════════════════════
# CREATE NEW PLAYER
# ═══════════════════════════════════════════════════════════════════════════════

func create_new_player(name: String = "Player") -> Dictionary:
	print("[Player] Creating new player: ", name)

	# Build base player data
	player_data = {
		"name":          name,
		"coins":         0,
		"totalScore":    0,
		"currentWorld":  1,
		"currentLevel":  1,
		"createdAt":     Time.get_unix_time_from_system(),
		"lastSeen":      Time.get_unix_time_from_system()
	}

	# Save player document
	await DatabaseManager.save_player(player_data)

	# Save to local cache
	
	is_loaded = true
	print("[Player] New player created!")
	emit_signal("player_created", player_data)
	return player_data




# ═══════════════════════════════════════════════════════════════════════════════
# LOAD FROM FIRESTORE
# ═══════════════════════════════════════════════════════════════════════════════

func _load_from_firestore():
	print("[Player] Loading from Firestore...")

	# Load player document
	var data = await DatabaseManager._get_player_data()

	if data.is_empty():
		# New player — create fresh
		print("[Player] No player found — creating new player")
		return

	player_data = data
	print("[Player] Player found: ", player_data.get("name", "Unknown"))
	# Save to cache
	LocalCache._save_local_player_backup(player_data)
	is_loaded = true
	emit_signal("player_loaded", player_data)




func _sync_from_firestore_background():
	# Runs in background without blocking game
	print("[Player] Background sync started...")
	var data = await DatabaseManager._get_player_data()

	if not data.is_empty():
		player_data = data
		LocalCache._save_local_player_backup(player_data)
	print("[Player] Background sync complete!")


# ═══════════════════════════════════════════════════════════════════════════════
# SAVE PLAYER
# ═══════════════════════════════════════════════════════════════════════════════

func save_player():
	player_data["lastSeen"] = Time.get_unix_time_from_system()
	LocalCache.set_player(player_data)
	await DatabaseManager.save_player(player_data)
	print("[Player] Player saved!")


func update_field(field: String, value):
	player_data[field] = value
	LocalCache.set_player(player_data)
	await DatabaseManager.save_player(player_data)
	print("[Player] Updated field: ", field, " = ", value)


# ═══════════════════════════════════════════════════════════════════════════════
# COINS
# ═══════════════════════════════════════════════════════════════════════════════

# coins implementation function


# ═══════════════════════════════════════════════════════════════════════════════
# LEVEL COMPLETION
# ═══════════════════════════════════════════════════════════════════════════════



# ═══════════════════════════════════════════════════════════════════════════════
# GETTERS
# ═══════════════════════════════════════════════════════════════════════════════

func get_player_name() -> String:
	return player_data.get("name", "Player")
