extends Node

@export var retriesCount = 3


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass#_save_data()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
#--- Here is the example model for saving the data to the firebase, modify it according to the requirements
func _save_data(data : Dictionary):
	var collection : FirestoreCollection = Firebase.Firestore.collection("playersDataNew")
	var doc := FirestoreDocument.new()
	doc.doc_name = "player_1"
	doc.fields = data
	var retries = retriesCount
	var success = false
	while retries > 0 and not success :
		var task = await collection.update(doc)
		
		if task != null :
			print("Saved Succesfully")
			success = true
			LocalCache._save_local_backup(doc.fields)
		else:
			print("save failed, retrying...")
			retries -= 1
			await  get_tree().create_timer(1.0).timeout
	if not success :
		print("saving to cloud failed, saving locally")
		LocalCache._save_local_backup(doc.fields)
	

func _get_player_data() -> Dictionary:
	var collection : FirestoreCollection = Firebase.Firestore.collection("playersDataNew")
	
	var retries = retriesCount
	
	while retries > 0 :
		var task = await collection.get_doc("player_1")
		if task:
			print("loaded from cloud")
			var doc : FirestoreDocument = task
			return doc.fields
		else:
			print("load failed, retrying...")
			retries -= 1
			await  get_tree().create_timer(1.0).timeout
	print("loading from local backup")
	return {}
# --- cache and load data ---
