extends Node

@onready var sign_in_status: Label = $"../SignIn_Status"
@onready var player_name_label: Label = $"../PlayerNameLabel"

var game_center = null

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZE
# ═══════════════════════════════════════════════════════════════════════════════

#func _ready():
	#_initialize_game_center()
func _ready():
	# If we are NOT on iOS, hide this button
	if OS.get_name() != "iOS":
		$"../AppleSignIN".hide()
	
	_initialize_game_center()
	

func _initialize_game_center():
	# Step 1: Check if the iOS plugin is actually loaded in the engine
	if Engine.has_singleton("GameCenter"):
		game_center = Engine.get_singleton("GameCenter")
		print("[GameCenter] Plugin initialized successfully")
	else:
		# If you are on Windows/Mac editor, this will always happen
		print("[GameCenter] Not available (running in editor or not on iOS)")

# ═══════════════════════════════════════════════════════════════════════════════
# SIGN IN
# ═══════════════════════════════════════════════════════════════════════════════

func sign_in():
	if not game_center:
		print("[GameCenter] Plugin not found, falling back to anonymous login")
		_sign_in_anonymous()
		return
		
	# Step 2: Connect to the signals (events) the plugin sends out
	if not game_center.is_connected("authenticated", _on_authenticated):
		game_center.connect("authenticated", _on_authenticated)
		game_center.connect("authentication_failed", _on_authentication_failed)
	
	# Step 3: Tell the iOS system to show the login popup
	print("[GameCenter] Triggering authentication...")
	game_center.authenticate()

# ═══════════════════════════════════════════════════════════════════════════════
# CALLBACKS (What happens after the login)
# ═══════════════════════════════════════════════════════════════════════════════

func _on_authenticated():
	# Step 4: Retrieve the player's info once they successfully log in
	var player_id = game_center.get_player_id()
	var player_name = game_center.get_player_name()
	
	print("[GameCenter] Welcome, ", player_name)
	if sign_in_status:
		sign_in_status.text = "Signed into Game Center: " + player_name
	
	# Step 5: Sync this login with your teammate's Firebase system
	_check_and_create_player(player_id, player_name, "AppleGameCenter")

func _on_authentication_failed(error):
	print("[GameCenter] Login failed: ", error)
	if sign_in_status:
		sign_in_status.text = "Game Center Login Failed. Switching to Anonymous."
	_sign_in_anonymous()

# ═══════════════════════════════════════════════════════════════════════════════
# FIREBASE & DATABASE INTEGRATION
# ═══════════════════════════════════════════════════════════════════════════════

func _check_and_create_player(player_id: String, name: String, auth_type: String):
	print("[Player] Checking Firestore for ID: ", player_id)

	# Use the DatabaseManager your teammate built to check for existing users
	var existing_data = await DatabaseManager._get_player_data(player_id)
	
	if existing_data.is_empty():
		print("[Player] New iOS user detected. Creating profile...")
		await PlayerDataManagement.create_new_player(player_id, auth_type, name)
	else:
		print("[Player] Returning iOS user found: ", existing_data.get("name", "Unknown"))
		PlayerDataManagement.player_data = existing_data
		PlayerDataManagement.emit_signal("player_loaded", existing_data)

func _sign_in_anonymous():
	# This ensures the game still works even if the user cancels Game Center
	print("[Firebase] Using anonymous fallback...")
	if Firebase.Auth:
		Firebase.Auth.login_anonymous()


func _on_apple_sign_in_pressed() -> void:
	sign_in() # Replace with function body.
