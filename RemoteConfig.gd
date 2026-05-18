extends Node

const API_KEY = "AIzaSyCyd5yvMf3kkvxy0TcxqU3RWLDuOj-8mU8"
const PROJECT_ID = "silentgreensdata"       
const APP_ID = "1:663405748090:web:39a0e7133b017ba67e00c3"
@onready var enemy_speed_label: Label = $"../Enemy_speed_Label"
@onready var spawn_rate_label: Label = $"../Spawn_rate_Label"

var remote_config := {}


func _ready():
	pass
	#await sign_in_anonymously()
	#await fetch_remote_config()
	#apply_config()


# ─── Step 1: Anonymous Sign-In ───────────────────────────────────────────────
func sign_in_anonymously():
	var url = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + API_KEY
	var body = JSON.stringify({"returnSecureToken": true})
	var headers = ["Content-Type: application/json"]

	var http = HTTPRequest.new()
	add_child(http)
	http.request(url, headers, HTTPClient.METHOD_POST, body)

	var result = await http.request_completed
	var response_text = result[3].get_string_from_utf8()
	print("[Auth] Response: ", response_text)

	var response = JSON.parse_string(response_text)
	if response == null or not response.has("idToken"):
		print("[Auth] ERROR: Failed to sign in anonymously")
		return

	print("[Auth] Sign-in successful")


# ─── Step 2: Fetch Remote Config ─────────────────────────────────────────────
func fetch_remote_config():
	var url = "https://firebaseremoteconfig.googleapis.com/v1/projects/%s/namespaces/firebase:fetch" % PROJECT_ID

	var body = JSON.stringify({
		"app_instance_id": "godot_" + str(randi_range(100000, 999999)),
		"app_id": APP_ID,
		"language_code": "en",
		"platform_version": "godot",
		"app_version": "1.0.0",
		"sdk_version": "1.0.0"
	})

	var headers = [
		"Content-Type: application/json",
		"x-goog-api-key: " + API_KEY
	]

	var http = HTTPRequest.new()
	add_child(http)
	http.request(url, headers, HTTPClient.METHOD_POST, body)

	var result = await http.request_completed
	var response_text = result[3].get_string_from_utf8()
	print("[RemoteConfig] Status code: ", result[1])
	print("[RemoteConfig] Raw response: ", response_text)

	var response = JSON.parse_string(response_text)
	if response == null:
		print("[RemoteConfig] ERROR: Failed to parse response")
		load_cached_config()
		return

	var entries = response.get("entries", {})
	if entries.is_empty():
		print("[RemoteConfig] WARNING: No entries found, loading cache")
		load_cached_config()
		return

	remote_config = entries
	print("[RemoteConfig] Loaded: ", remote_config)
	save_config()


# ─── Step 3: Apply Config ─────────────────────────────────────────────────────
func apply_config():
	if remote_config.is_empty():
		print("[Config] No config to apply")
		return

	var enemy_speed = float(remote_config.get("enemy_speed", "5"))
	var spawn_rate  = float(remote_config.get("spawn_rate",  "2"))

	print("[Config] enemy_speed = ", enemy_speed)
	print("[Config] spawn_rate  = ", spawn_rate)
	
	enemy_speed_label.text = "Enemy speed is "+ str(enemy_speed)
	spawn_rate_label.text = "Spawn rate is " + str(spawn_rate)
	spawn_rate_label.show()


# ─── Cache: Save & Load ───────────────────────────────────────────────────────
func save_config():
	var file = FileAccess.open("user://remote_config.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(remote_config))
		print("[Cache] Config saved")


func load_cached_config():
	if FileAccess.file_exists("user://remote_config.json"):
		var file = FileAccess.open("user://remote_config.json", FileAccess.READ)
		if file:
			remote_config = JSON.parse_string(file.get_as_text())
			print("[Cache] Loaded cached config: ", remote_config)
	else:
		print("[Cache] No cache found, using hardcoded defaults")
		remote_config = {
			"enemy_speed": "5",
			"spawn_rate": "2"
		}


func _on_button_pressed() -> void:
	enemy_speed_label.text = "Fetching from firebase"
	spawn_rate_label.hide()
	fetch_remote_config()
	apply_config()
