extends Node


func _ready():
	if Engine.has_singleton("Firebase"):
		var firebase = Engine.get_singleton("Firebase")
		firebase.connect("token_received", _on_token_received)
		firebase.get_fcm_token()

func _on_token_received(token: String):
	print("FCM Token: ", token)
