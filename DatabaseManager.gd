extends Node

@export var retriesCount = 3


# Called when the node enters the scene tree for the first time.

#--- Here is the example model for saving the data to the firebase, modify it according to the requirements
func _save_data(data : Dictionary, player_id : String):
	var collection : FirestoreCollection = Firebase.Firestore.collection("playersDataNew")
	var doc := FirestoreDocument.new()
	doc.doc_name = player_id
	doc.fields = data
	var retries = retriesCount
	var success = false
	while retries > 0 and not success :
		var task = await collection.update(doc)
		
		if task != null :
			print("Saved Succesfully")
			success = true
			#LocalCache._save_local_player_backup(doc.fields)
		else:
			print("save failed, retrying...")
			retries -= 1
			await  get_tree().create_timer(1.0).timeout
	if not success :
		print("saving to cloud failed, saving locally")
		#LocalCache._save_local_player_backup(doc.fields)
	

func _get_player_data(playerId : String) -> Dictionary:
	var collection : FirestoreCollection = Firebase.Firestore.collection("playersDataNew")
	
	var retries = retriesCount
	
	while retries > 0 :
		var task = await collection.get_doc(playerId)
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


func _save_passes(passes_data : Dictionary,playerId : String):
	var collection : FirestoreCollection = Firebase.Firestore.collection("playersDataNew/" + playerId + "/passes")

	var playerData = await _get_player_data(playerId)
	if playerData.is_empty():
		print("No player data found for playerId: %s. Cannot save passes." %
			[playerId])
		return
	
	var pass_doc := FirestoreDocument.new()
	pass_doc.doc_name = playerId + "_passes"
	pass_doc.fields = passes_data
	var retries = retriesCount
	var success = false
	while retries > 0 and not success :
		var task = await collection.update(pass_doc)
		if task != null :
			print("Passes saved Succesfully")
			success = true
		else:
			print("save failed, retrying...")
			retries -= 1
			await  get_tree().create_timer(1.0).timeout
	if not success :
		print("saving passes to cloud failed, saving locally")

func _get_passes(playerId : String) -> Dictionary:
	var collection : FirestoreCollection = Firebase.Firestore.collection("playersDataNew/" + playerId + "/passes")
	var playerData = await _get_player_data(playerId)
	if playerData.is_empty():
		print("No player data found for playerId: %s. Cannot load passes." %
			[playerId])
		return {}
	
	var retries = retriesCount
	while retries > 0 :
		var task = await collection.get_doc(playerId + "_passes")
		if task:
			print("Passes loaded from cloud")
			var doc : FirestoreDocument = task
			return doc.fields
		else:
			print("load failed, retrying...")
			retries -= 1
			await  get_tree().create_timer(1.0).timeout
	print("loading passes from local backup")
	return {}

func get_server_time() -> int:
	return Time.get_unix_time_from_system()
