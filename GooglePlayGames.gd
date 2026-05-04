extends Node
@onready var sign_in_status: Label = $"../SignIn_Status"
@onready var player_name_label: Label = $"../PlayerNameLabel"

# Check if plugin is available (only works on exported APK)
var play_games = null

	
func _intailzie_playGames():
	GodotPlayGameServices.initialize()
	if Engine.has_singleton("GodotPlayGameServices"):
		play_games = Engine.get_singleton("GodotPlayGameServices")
		sign_in_status.text = "[PlayGames] Plugin is available"
	else:
		print("[PlayGames] Plugin not available (running in editor?)")
		sign_in_status.text = "[PlayGames] Plugin not available (running in editor?)"


# ─── Sign In ─────────────────────────────────────────────────────────────────
func sign_in():
	play_games.signIn()
	# Listen for result
	play_games.connect("userSignedIn", _on_signed_in)
	play_games.connect("userSignedOut", _on_signed_out)
	play_games.connect("signInFailed", _on_sign_in_failed)

func _on_signed_in():
	print("[PlayGames] Signed in!")
	sign_in_status.text = "[PlayGames] Signed in!"
	load_player_info()

func _on_signed_out():
	print("[PlayGames] Signed out")

func _on_sign_in_failed(error: String):
	sign_in_status.text = "[PlayGames] Sign-in failed: " + str(error)
	print("[PlayGames] Sign-in failed: ", error)


# ─── Player Info ──────────────────────────────────────────────────────────────
func load_player_info():
	play_games.loadCurrentPlayer(false)
	play_games.connect("currentPlayerLoaded", _on_player_loaded)

func _on_player_loaded(player_json: String):
	var player = JSON.parse_string(player_json)
	var playerName = player.get("displayName", "Unknown")
	var playerId = player.get("playerId", "")
	player_name_label.text = "player name is " + str(playerName) + " and player id is " +str(playerId)


# ─── Achievements ─────────────────────────────────────────────────────────────
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


# ─── Leaderboards ─────────────────────────────────────────────────────────────
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


# ─── Saved Games (Cloud Save) ─────────────────────────────────────────────────
func save_game(data: Dictionary):
	if play_games:
		var json_data = JSON.stringify(data)
		play_games.saveGame("save_slot_1", "My Save", json_data.to_utf8_buffer())

func load_game():
	if play_games:
		play_games.loadGame("save_slot_1")
		play_games.connect("gameLoaded", _on_game_loaded)

func _on_game_loaded(data: PackedByteArray):
	var json_str = data.get_string_from_utf8()
	var save_data = JSON.parse_string(json_str)
	print("[PlayGames] Save data loaded: ", save_data)


func _on_google_sign_in_pressed() -> void:
	_intailzie_playGames()
	sign_in()
