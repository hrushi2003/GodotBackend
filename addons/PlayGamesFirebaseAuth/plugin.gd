@tool
extends EditorPlugin

func _enter_tree() -> void:
	print("[PlayGamesFirebaseAuth] Plugin loaded.")

func _exit_tree() -> void:
	print("[PlayGamesFirebaseAuth] Plugin unloaded.")
