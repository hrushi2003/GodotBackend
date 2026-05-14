

# PlayerManager.gd — Autoload
extends Node

const TOTAL_WORLDS     = 5
const LEVELS_PER_WORLD = 30

var playerId : String = ""
var player_data  := {}
var worlds_cache := {}
var is_loaded    := false

var player_pass = {}
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
		"AuthProvider": authType,
	}

	
	# Save player document
	await DatabaseManager._save_data(player_data, playerId)
	# Save to local cache
	player_data["id"] = playerId
	LocalCache._save_local_player_backup(player_data)
	is_loaded = true
	print("[Player] New player created!")
	emit_signal("player_created", player_data)
	return player_data




# ═══════════════════════════════════════════════════════════════════════════════
# LOAD FROM FIRESTORE
# ═══════════════════════════════════════════════════════════════════════════════

func _load_from_firestore():
	print("[Player] Loading from Firestore...")

	var uid = Firebase.Auth.auth.get("localid", "")
	await DatabaseManager._get_player_data(player_data.get(uid, ""))
	# Load player document
	if player_data.is_empty():
		print("[Player] No player data found in Firestore.")
		return
	print("[Player] Loaded from Firestore: ", player_data.get("name", "Unknown"))
	# Save to local cache
	LocalCache._save_local_player_backup(player_data)
	is_loaded = true
	emit_signal("player_loaded", player_data)




func _sync_from_firestore_background():
	# Runs in background without blocking game
	print("[Player] Background sync started...")

	var uid = Firebase.Auth.auth.get("localid", "")
	var firestore_data = await DatabaseManager._get_player_data(player_data.get(uid, ""))
	if firestore_data.is_empty():
		print("[Player] No data found in Firestore during background sync.")
		return
	# Compare timestamps to decide if we need to update local cache
	var local_last_seen = player_data.get("lastSeen", 0)
	var firestore_last_seen = firestore_data.get("lastSeen", 0)
	if firestore_last_seen > local_last_seen:
		print("[Player] Firestore has newer data, updating local cache.")
		player_data = firestore_data
		LocalCache._save_local_player_backup(player_data)
		emit_signal("player_loaded", player_data)
	else:
		print("[Player] Local cache is up to date, no sync needed.")	


# ═══════════════════════════════════════════════════════════════════════════════
# SAVE PLAYER
# ═══════════════════════════════════════════════════════════════════════════════

func save_player():
	player_data["lastSeen"] = Time.get_unix_time_from_system()
	LocalCache._save_local_player_backup(player_data)
	await DatabaseManager.save_player(player_data)
	print("[Player] Player saved!")


func update_field(field: String, value):
	player_data[field] = value
	LocalCache._save_local_player_backup(player_data)
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

func get_player_id() -> String:
	return player_data.get("id", "")

func get_player_coins() -> int:
	return player_data.get("coins", 0)

func get_player_score() -> int:
	return player_data.get("totalScore", 0)

func get_current_world() -> int:
	return player_data.get("currentWorld", 0)

func get_current_level() -> int:
	return player_data.get("currentLevel", 0)

# ═══════════════════════════════════════════════════════════════════════════════
