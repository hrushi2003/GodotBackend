extends Node
@onready var pass_status : Label = $"../pass_status"
@onready var generatePass : Button = $"../generate_passes"
@onready var consumePass : Button = $"../consume_passes"
@onready var restore_passes: Button = $"../restore_passes"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	generatePass.connect("pressed", GeneratePasses)
	consumePass.connect("pressed", ConsumePass)
	restore_passes.connect("pressed",restore_pass)
	PassManager.passes_updated.connect(_on_passes_updated)

func GeneratePasses():
	var uid = Firebase.Auth.auth.get("localid", "")
	if(uid == ""):
		print("[Passes] Cannot generate passes: No user logged in.")
		return
	PassManager.load_pass_status()

func _on_passes_updated(current : int, max_passes : int):
	pass_status.text = "Passes: %d/%d" % [current, max_passes]
	
func ConsumePass():
	PassManager.consume_pass()
	
func restore_pass():
	PassManager.restore_one_pass()
