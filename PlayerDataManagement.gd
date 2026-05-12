

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

func create_new_player(playerId : String,authType : String, name: String = "Player") -> Dictionary:
	print("[Player] Creating new player: ", name)

	# Build base player data
	player_data = {
		"name":          name,
		"coins":         0,
		"totalScore":    0,
		"currentWorld":  0,
		"currentLevel":  0,
		"createdAt":    Firebase.Firestore.SERVER_TIMESTAMP,
		"lastSeen": Firebase.Firestore.SERVER_TIMESTAMP,
		"AuthProvider": authType
	}

	# Save player document
	await DatabaseManager._save_data(player_data, playerId)

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




func _sync_from_firestore_background():
	# Runs in background without blocking game
	print("[Player] Background sync started...")


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
