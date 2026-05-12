extends Node
const FIREBASE_PROJECT_ID = "silent-greens-4e402"

@onready var sign_in_status: Label = $"../SignIn_Status"
@onready var player_name_label: Label = $"../PlayerNameLabel"

var play_games = null
var firebase_uid := ""
var firebase_token := ""
var _auth_code_used := false   # ← prevent double use
signal auth_succeeded(user_data: Dictionary)
signal auth_failed(reason: String)

var CLIENT_SECRET = "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"
const WEB_CLIENT_ID: String = "540866235695-pmhhgte71aog0bli6a204jh35aqp2rtu.apps.googleusercontent.com"
const AUTH_TIMEOUT: float = 20.0

var _sign_in_client = null
var _pending_code: String = ""

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZE
# ═══════════════════════════════════════════════════════════════════════════════

func _initialize_play_games():
	if Engine.has_singleton("GodotPlayGameServices"):
		play_games = Engine.get_singleton("GodotPlayGameServices")
		
		for sig in play_games.get_signal_list():
			var sig_name = sig["name"]
			if sig_name in ["script_changed", "property_list_changed"]:
				continue
			print("[PlayGames] Available signal: ", sig_name)

		GodotPlayGameServices.initialize()
		sign_in_status.text = "[PlayGames] Plugin available"
		print("[PlayGames] Plugin loaded!")
	else:
		sign_in_status.text = "[PlayGames] Not available (editor mode)"
		print("[PlayGames] Not available")

func _on_any_signal(sig_name: String):
	print("[PlayGames] Signal fired: ", sig_name)

# ═══════════════════════════════════════════════════════════════════════════════
# SIGN IN
# ═══════════════════════════════════════════════════════════════════════════════


func sign_in():
	if not play_games:
		print("[PlayGames] Plugin not initialized")
		return

	# ── Connect correct signals ───────────────────────────────────────────
	if not play_games.is_connected("userAuthenticated", _on_user_authenticated):
		play_games.connect("userAuthenticated", _on_user_authenticated)

	if not play_games.is_connected("serverSideAccessRequested", _on_server_side_access_requested):
		play_games.connect("serverSideAccessRequested", _on_server_side_access_requested)

	if not play_games.is_connected("currentPlayerLoaded", _on_player_loaded):
		play_games.connect("currentPlayerLoaded", _on_player_loaded)
	
	_auth_code_used = false  # reset before each sign in
	play_games.signIn()



func _setup_gpgs() -> bool:
	if _sign_in_client != null: return true
	
	if GodotPlayGameServices.initialize() != GodotPlayGameServices.PlayGamesPluginError.OK:
		return false

	var ClientScript = load("res://addons/GodotPlayGameServices/scripts/sign_in/sign_in_client.gd")
	_sign_in_client = ClientScript.new()
	add_child(_sign_in_client)
	
	# Connect signal to our local variable
	_sign_in_client.server_side_access_requested.connect(func(code):
		_pending_code = code
		print("[GPGS] Signal received raw code.")
	)
	return true
# ── userAuthenticated returns both success and fail in one signal ──────────────

func _on_user_authenticated(is_authenticated: bool):
	print("[PlayGames] ================================")
	if is_authenticated:
		print("[PlayGames] Authenticated!")
		sign_in_status.text = "[PlayGames] Authenticated! Getting Firebase token..."

		# Load player info
		play_games.loadCurrentPlayer(false)

		# Request server auth code for Firebase
		play_games.requestServerSideAccess(WEB_CLIENT_ID, false)
	else:
		print("[PlayGames] Authentication failed!")
		sign_in_status.text = "[PlayGames] Auth failed, using anonymous login"
		if play_games.has_method("getLastError"):
			print("[PlayGames] Last error: ", play_games.getLastError())
		if play_games.has_method("getSignInError"):
			print("[PlayGames] Sign in error: ", play_games.getSignInError())
		if play_games.has_method("isAuthenticated"):
			print("[PlayGames] isAuthenticated check: ", play_games.isAuthenticated())
		_sign_in_anonymous()
	print("[PlayGames] ================================")

# ── serverSideAccessRequested returns auth code ───────────────────────────────
func _on_server_side_access_requested(auth_code: String):
	if _auth_code_used:
		print("[PlayGames] Auth code already used — ignoring duplicate signal")
		return
	if auth_code == "" or auth_code == null:
		print("[PlayGames] Auth code empty!")
		_sign_in_anonymous()
		return
	
	_auth_code_used = true
	print("[PlayGames] Auth code received!")
	sign_in_status.text = "[PlayGames] Signing into Firebase..."
	await _sign_in_to_firebase(auth_code)


# ═══════════════════════════════════════════════════════════════════════════════
# FIREBASE AUTH
# ═══════════════════════════════════════════════════════════════════════════════

func _sign_in_to_firebase(auth_code: String):
	if not Firebase.Auth.is_connected("login_succeeded", _on_firebase_login_success):
		Firebase.Auth.connect("login_succeeded", _on_firebase_login_success)

	if not Firebase.Auth.is_connected("login_failed", _on_firebase_login_failed):
		Firebase.Auth.connect("login_failed", _on_firebase_login_failed)

	var body = {
        "postBody": "code=" + auth_code + "&providerId=playgames.google.com",
        "requestUri": "http://localhost",
        "returnSecureToken": true,
        "returnIdpCredential": true
	}

	Firebase.Auth.request(
        Firebase.Auth._base_url + Firebase.Auth._signin_with_oauth_request_url,
        Firebase.Auth._headers,
        HTTPClient.METHOD_POST,
        JSON.stringify(body)
	)
	

func _login_firebase_play_games(access_token: String):
	print("[Firebase] Signing in with Play Games provider...")

	if not Firebase.Auth.is_connected("login_succeeded", _on_firebase_login_success):
		Firebase.Auth.connect("login_succeeded", _on_firebase_login_success)
	if not Firebase.Auth.is_connected("login_failed", _on_firebase_login_failed):
		Firebase.Auth.connect("login_failed", _on_firebase_login_failed)
	if not Firebase.Auth.is_connected("auth_request", _on_raw_auth_request):
		Firebase.Auth.connect("auth_request", _on_raw_auth_request)

    # ── Try Play Games provider ────────────────────────────────────────────
	var body = {
        "postBody":            "access_token=" + access_token + "&providerId=playgames.google.com",
        "requestUri":          "https://%s.firebaseapp.com/__/auth/handler" % FIREBASE_PROJECT_ID,
        "returnIdpCredential": true,
        "returnSecureToken":   true
	}

	Firebase.Auth.is_busy           = false
	Firebase.Auth.auth_request_type = Firebase.Auth.Auth_Type.LOGIN_OAUTH

	var err = Firebase.Auth.request(
        Firebase.Auth._base_url + Firebase.Auth._signin_with_oauth_request_url,
        Firebase.Auth._headers,
        HTTPClient.METHOD_POST,
        JSON.stringify(body)
	)

	print("[Firebase] Request sent, err: ", err)

	if err != OK:
		_sign_in_anonymous()
	
func _login_firebase_with_token(token: String, token_type: String):
	if not Firebase.Auth.is_connected("login_succeeded", _on_firebase_login_success):
		Firebase.Auth.connect("login_succeeded", _on_firebase_login_success)
	if not Firebase.Auth.is_connected("login_failed", _on_firebase_login_failed):
		Firebase.Auth.connect("login_failed", _on_firebase_login_failed)
	var post_body = ""
	if token_type == "id_token":
		post_body = "id_token=" + token + "&providerId=google.com"
	else:
		post_body = "access_token=" + token + "&providerId=google.com"
	var body = {
		"postBody": post_body,
		"requestUri": "https://%s.firebaseapp.com/__/auth/handler" % FIREBASE_PROJECT_ID,
		"returnIdpCredential": true,
		"returnSecureToken": true
	}
	Firebase.Auth.is_busy = false
	Firebase.Auth.auth_request_type = Firebase.Auth.Auth_Type.LOGIN_OAUTH
	var err = Firebase.Auth.request(
		Firebase.Auth._base_url + Firebase.Auth._signin_with_oauth_request_url,
		Firebase.Auth._headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	print("[Firebase] Request sent, err: ", err)
	if err != OK:
		print("[Firebase] ❌ Request failed!")
		_sign_in_anonymous()


func _on_raw_auth_request(result_code, result_content):
	print("[Firebase] result_code: ", result_code)
	print("[Firebase] result_content: ", result_content)
	
func _on_firebase_login_success(auth_result: Dictionary):
	# GodotNuts lowercases all keys
	firebase_uid = auth_result.get("localid", "")
	firebase_token = auth_result.get("idtoken", "")
	var user_name = auth_result.get("displayname", "Unknown")

	print("[Firebase] UID: ", firebase_uid)
	print("[Firebase] Name: ", user_name)

	sign_in_status.text = "[Firebase] Signed in: " + user_name
	player_name_label.text = "Name: " + user_name

	# Save auth for next session
	Firebase.Auth.save_auth(Firebase.Auth.auth)


func _on_firebase_login_failed(error_code, message: String):
	print("[Firebase] Login failed: ", message)
	sign_in_status.text = "[Firebase] Failed: " + message
	_sign_in_anonymous()


# ═══════════════════════════════════════════════════════════════════════════════
# ANONYMOUS FALLBACK
# ═══════════════════════════════════════════════════════════════════════════════

func _sign_in_anonymous():
	print("[Firebase] Signing in anonymously...")
	sign_in_status.text = "[Firebase] Signing in anonymously..."

	if not Firebase.Auth.is_connected("login_succeeded", _on_firebase_login_success):
		Firebase.Auth.connect("login_succeeded", _on_firebase_login_success)
		Firebase.Auth.connect("login_failed", _on_firebase_login_failed)

	Firebase.Auth.login_anonymous()


# ═══════════════════════════════════════════════════════════════════════════════
# AUTO LOGIN — call this on game start to restore previous session
# ═══════════════════════════════════════════════════════════════════════════════

func try_auto_login():
	if not Firebase.Auth.needs_login():
		print("[Firebase] Restoring previous session...")
		sign_in_status.text = "[Firebase] Restoring session..."

		if not Firebase.Auth.is_connected("token_refresh_succeeded", _on_token_refreshed):
			Firebase.Auth.connect("token_refresh_succeeded", _on_token_refreshed)

		Firebase.Auth.load_auth()
	else:
		print("[Firebase] No saved session")


func _on_token_refreshed(auth_result: Dictionary):
	firebase_uid = auth_result.get("localid", "")
	firebase_token = auth_result.get("idtoken", "")

	print("[Firebase] Session restored! UID: ", firebase_uid)
	sign_in_status.text = "[Firebase] Session restored!"


# ═══════════════════════════════════════════════════════════════════════════════
# PLAYER INFO
# ═══════════════════════════════════════════════════════════════════════════════

func _on_player_loaded(player_json: String):
	var player = JSON.parse_string(player_json)
	var player_name = player.get("displayName", "Unknown")
	var player_id = player.get("playerId", "")
	print("[PlayGames] Name: ", player_name, " ID: ", player_id)
	player_name_label.text = player_name


# ═══════════════════════════════════════════════════════════════════════════════
# ACHIEVEMENTS
# ═══════════════════════════════════════════════════════════════════════════════

func unlock_achievement(achievement_id: String):
	if play_games:
		play_games.unlockAchievement(achievement_id)
		print("[PlayGames] Achievement unlocked: ", achievement_id)

func increment_achievement(achievement_id: String, steps: int):
	if play_games:
		play_games.incrementAchievement(achievement_id, steps)

func show_achievements():
	if play_games:
		play_games.showAchievements()


# ═══════════════════════════════════════════════════════════════════════════════
# LEADERBOARDS
# ═══════════════════════════════════════════════════════════════════════════════

func submit_score(leaderboard_id: String, score: int):
	if play_games:
		play_games.submitScore(leaderboard_id, score)
		print("[PlayGames] Score submitted: ", score)

func show_leaderboard(leaderboard_id: String):
	if play_games:
		play_games.showLeaderboard(leaderboard_id)

func show_all_leaderboards():
	if play_games:
		play_games.showAllLeaderboards()


# ═══════════════════════════════════════════════════════════════════════════════
# CLOUD SAVE
# ═══════════════════════════════════════════════════════════════════════════════

func save_game(data: Dictionary):
	if play_games:
		play_games.saveGame("save_slot_1", "My Save", JSON.stringify(data).to_utf8_buffer())

func load_game():
	if play_games:
		if not play_games.is_connected("gameLoaded", _on_game_loaded):
			play_games.connect("gameLoaded", _on_game_loaded)
		play_games.loadGame("save_slot_1")

func _on_game_loaded(data: PackedByteArray):
	var save_data = JSON.parse_string(data.get_string_from_utf8())
	print("[PlayGames] Save loaded: ", save_data)


# ═══════════════════════════════════════════════════════════════════════════════
# BUTTON
# ═══════════════════════════════════════════════════════════════════════════════

func _on_google_sign_in_pressed() -> void:
	_initialize_play_games()
	sign_in()
