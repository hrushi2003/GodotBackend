extends Node

@export var retriesCount = 3


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass#_save_data()
	_get_player_data()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
#--- Here is the example model for saving the data to the firebase, modify it according to the requirements
func _save_data():
	var collection : FirestoreCollection = Firebase.Firestore.collection("players")
	var doc := FirestoreDocument.new()
	doc.doc_name = "player_1"
	var player_name = "Hrushi"
	doc.fields = {
		"player_name" : player_name,
		"age" : 55,
	}
	var retries = retriesCount
	var success = false
	while retries > 0 and not success :
		var task = await collection.update(doc)
		
		if task != null :
			print("Saved Succesfully")
			success = true
			_save_local_backup(doc.fields)
		else:
			print("save failed, retrying...")
			retries -= 1
			await  get_tree().create_timer(1.0).timeout
	if not success :
		print("saving to cloud failed, saving locally")
		_save_local_backup(doc.fields)
	

func _get_player_data():
	var collection : FirestoreCollection = Firebase.Firestore.collection("players")
	
	var retries = retriesCount
	
	while retries > 0 :
		var task = await collection.get_doc("player_1")
		if task:
			print("loaded from cloud")
			var doc : FirestoreDocument = task
			print(doc.fields)
			return
		else:
			print("load failed, retrying...")
			retries -= 1
			await  get_tree().create_timer(1.0).timeout
	print("loading from local backup")
	return _load_local_backup()
# --- cache and load data ---
func _save_local_backup(data: Dictionary):
	var file = FileAccess.open("user://player_data.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _load_local_backup():
	if not FileAccess.file_exists("user://player_data.json"):
		print("No local data found")
		return {}
	
	var file = FileAccess.open("user://player_data.json", FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	return JSON.parse_string(content)
