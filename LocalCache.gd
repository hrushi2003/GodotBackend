extends Node
func _save_local_player_backup(data: Dictionary):
	if SaveManager == null:
		print("SaveManager not found, cannot save local backup")
		return
	SaveManager.save_game(0, data)

func _load_local_player_backup():
	if SaveManager == null:
		print("SaveManager not found, cannot load local backup")
		return {}
	return SaveManager.load_game(0)

func get_passes():
	var backup = _load_local_player_backup()
	if backup.empty():
		print("No local backup found for passes")
		return {}
	var passes = backup.get("passes", {})
	if passes.empty():
		print("No passes data found in local backup")
	return passes

func set_passes(passes_data: Dictionary):
	var backup = _load_local_player_backup()
	if backup.empty():
		print("No local backup found, cannot set passes")
		return
	backup["passes"] = passes_data
	_save_local_player_backup(backup)