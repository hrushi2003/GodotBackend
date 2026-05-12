# ==============================================================================
# sign_in_client.gd
# Path: addons/GodotPlayGameServices/scripts/sign_in/sign_in_client.gd
#
# PURPOSE:
#   Bridges the Kotlin/Android GPGS plugin signals into the Godot event loop.
#   The original plugin does not always correctly relay the serverSideAccessRequested
#   signal. This version explicitly maps it.
#
# REPLACE the original sign_in_client.gd with this file.
# ==============================================================================

extends Node

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted when GPGS successfully returns a server auth code.
## Connect to this in AuthFlowManager._setup_gpgs()
signal server_side_access_requested(auth_code: String)

## Emitted when the user is confirmed as signed in (no code needed)
signal user_authenticated(is_authenticated: bool)

# ── Internal state ─────────────────────────────────────────────────────────────
var _android_plugin = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	if OS.get_name() == "Android":
		_connect_android_plugin()
	else:
		push_warning("[SignInClient] Not on Android — GPGS signals will not fire.")


func _connect_android_plugin() -> void:
	if Engine.has_singleton("GodotPlayGameServices"):
		_android_plugin = Engine.get_singleton("GodotPlayGameServices")

		# ── CRITICAL: Map Kotlin signals → GDScript signals ────────────────
		# The Android plugin emits camelCase signals from Kotlin.
		# We must connect them here before calling request_server_side_access.

		if _android_plugin.has_signal("serverSideAccessRequested"):
			_android_plugin.serverSideAccessRequested.connect(_on_native_auth_code)
		else:
			push_error("[SignInClient] Android plugin does not have 'serverSideAccessRequested' signal. Check plugin version.")

		if _android_plugin.has_signal("userAuthenticated"):
			_android_plugin.userAuthenticated.connect(_on_native_user_authenticated)

		print("[SignInClient] Android plugin signals connected.")
	else:
		push_error("[SignInClient] GodotPlayGameServices singleton not found.")


# ── Public API ─────────────────────────────────────────────────────────────────

## Call this to begin the GPGS sign-in + server auth code flow.
## server_client_id MUST be the Web Client ID (not Android Client ID).
## force_refresh: set true to force a new code even if one was cached.
func request_server_side_access(server_client_id: String, force_refresh: bool = false) -> void:
	if _android_plugin == null:
		push_error("[SignInClient] Android plugin not initialized. Call _connect_android_plugin first.")
		return

	print("[SignInClient] Requesting server-side access with Web Client ID...")
	_android_plugin.requestServerSideAccess(server_client_id, force_refresh)


## Checks if the user is already signed in (non-blocking)
func is_authenticated() -> void:
	if _android_plugin:
		_android_plugin.isAuthenticated()


## Signs the user in interactively (shows the GPGS account picker)
func sign_in() -> void:
	if _android_plugin:
		_android_plugin.signIn()


## Signs the user out of GPGS
func sign_out() -> void:
	if _android_plugin:
		_android_plugin.signOut()


# ── Callbacks from Android ─────────────────────────────────────────────────────

## Called by the Android plugin when the auth code is ready
func _on_native_auth_code(auth_code: String) -> void:
	print("[SignInClient] Native auth code received. Empty: %s" % auth_code.is_empty())
	if auth_code.is_empty():
		push_error("[SignInClient] Received empty auth code from GPGS. Check Web Client ID.")
	server_side_access_requested.emit(auth_code)


## Called by the Android plugin to confirm authentication status
func _on_native_user_authenticated(is_auth: bool) -> void:
	print("[SignInClient] User authenticated: %s" % is_auth)
	user_authenticated.emit(is_auth)
