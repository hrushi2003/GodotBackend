# GameCenterManager.gd — Autoload
extends Node

var game_center: GameCenterManager
var local_player: GKLocalPlayer

const API_KEY = "AIzaSyCyd5yvMf3kkvxy0TcxqU3RWLDuOj-8mU8"
const FIREBASE_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signInWithGameCenter?key="

func _ready():
    game_center = GameCenterManager.new()
    
    # Connect signals BEFORE calling authenticate
    game_center.authentication_error.connect(func(error: String):
        print("❌ Auth error: ", error)
    )
    game_center.authentication_result.connect(func(status: bool):
        print("✅ Auth result: ", status)
        if status:
            
            local_player = game_center.local_player

            _fetch_identity_signature()
            print("Player ID: ", local_player.game_player_id)
            print("Display name: ", local_player.display_name)
            print("Alias: ", local_player.alias)
    )
    
    game_center.authenticate()

func _fetch_identity_signature():
    local_player.fetch_items_for_identity_verification_signature(
        func(values: Dictionary, error: Variant):
            if error:
                print("❌ Error: ", error)
                return
            
            # Print everything in detail
            print("=== RAW VALUES ===")
            for key in values.keys():
                var val = values[key]
                print("Key: '", key, "' | Type: ", typeof(val), " | Value: ", val)
                if val is PackedByteArray:
                    print("  -> Base64: ", Marshalls.raw_to_base64(val))
                    print("  -> Size: ", val.size())
        
            _sign_in_to_firebase(values)
    )

func _sign_in_to_firebase(values: Dictionary):

    # IMPORTANT:
    # These MUST remain PackedByteArray
    var signature_bytes: PackedByteArray = values.get("data", PackedByteArray())
    var salt_bytes: PackedByteArray = values.get("salt", PackedByteArray())

    # Force proper string conversion
    var public_key_url: String = str(values.get("url", ""))

    # Firebase expects timestamp as STRING
    var timestamp: String = str(values.get("timestamp", 0))

    # IMPORTANT:
    # Some Godot versions don't provide PackedByteArray.encode_base64().
    # Use Marshalls.raw_to_base64() which returns a String.
    var signature_b64: String = Marshalls.raw_to_base64(signature_bytes)
    var salt_b64: String = Marshalls.raw_to_base64(salt_bytes)

    print("====== FIREBASE VALUES ======")
    print("publicKeyUrl: ", public_key_url)
    print("timestamp: ", timestamp)
    print("playerId: ", local_player.game_player_id)

    print("signature length: ", signature_b64.length())
    print("salt length: ", salt_b64.length())

    print("signature preview: ", signature_b64.substr(0, 40))
    print("salt preview: ", salt_b64.substr(0, 40))

    # IMPORTANT:
    # Firebase expects ONLY these fields
    var body_dict = {
        "playerId": local_player.game_player_id,
        "publicKeyUrl": public_key_url,
        "signature": signature_b64,
        "salt": salt_b64,
        "timestamp": timestamp,
        "displayName": local_player.display_name
    }

    var body := JSON.stringify(body_dict)

    print("====== REQUEST BODY ======")
    print(body)

    var headers = [
        "Content-Type: application/json"
    ]

    var http := HTTPRequest.new()
    add_child(http)

    http.request_completed.connect(_on_firebase_response)

    var url := FIREBASE_URL + API_KEY

    var err = http.request(
        url,
        headers,
        HTTPClient.METHOD_POST,
        body
    )

    if err != OK:
        print("❌ HTTP Request Failed: ", err)


func _on_firebase_response(result, response_code, headers, body):

    var response_text: String = body.get_string_from_utf8()

    print("")
    print("====== FIREBASE RESPONSE ======")
    print("HTTP Code: ", response_code)
    print("Raw Response: ", response_text)

    var json = JSON.parse_string(response_text)

    if response_code == 200:

        print("")
        print("✅ FIREBASE LOGIN SUCCESS")
        print("Firebase UID: ", json.get("localId", ""))

        # Optional if using Firebase Godot plugin
        if Engine.has_singleton("Firebase"):
            Firebase.Auth.set_user(json)

    else:

        print("")
        print("❌ Firebase Login Failed")

        if typeof(json) == TYPE_DICTIONARY:

            print(json)

            if json.has("error"):
                print("Firebase Error: ", json["error"])
