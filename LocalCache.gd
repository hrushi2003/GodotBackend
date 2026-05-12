extends Node
func _save_local_player_backup(data: Dictionary):
	var file = FileAccess.open("user://player_data.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _load_local_player_backup():
	if not FileAccess.file_exists("user://player_data.json"):
		print("No local data found")
		return {}
	var file = FileAccess.open("user://player_data.json", FileAccess.READ)
	var content = file.get_as_text()
	file.close()	
	return JSON.parse_string(content)
