# PassManager.gd — Autoload
extends Node

const MAX_PASSES       = 3
const RESTORE_INTERVAL = 1800  # 30 minutes
const PASS_COST_COINS  = 300

var pass_status := {}

signal passes_updated(current: int, max: int)
signal pass_consumed(current: int)
signal pass_restored(current: int)
signal passes_full()

# ═══════════════════════════════════════════════════════════════════════════════
# LOAD
# ═══════════════════════════════════════════════════════════════════════════════

func load_pass_status():
	# Try local cache first
	var cached = LocalCache.get_passes()
	if not cached.is_empty():
		pass_status = cached
		print("[Passes] Loaded from cache")
		await restore_offline_passes()
	else:
		# Load from Firestore subcollection
		var uid = Firebase.Auth.auth.get("localid", "")
		pass_status = await DatabaseManager._get_passes(uid)

		if pass_status.is_empty():
			# First time — create default
			pass_status = {
				"current":        MAX_PASSES,
				"max":            MAX_PASSES,
				"lastRestoredAt": await DatabaseManager.get_server_time(),
				"isUnlimited":    false
			}
			await _save(uid)
			print("[Passes] Created fresh pass status")
		else:
			await restore_offline_passes()

	emit_signal("passes_updated", get_current(), MAX_PASSES)
	print("[Passes] Loaded: ", get_current(), "/", MAX_PASSES)


func _save(playerId : String = ""):
	# Always save to cache AND Firestore subcollection
	LocalCache.set_passes(pass_status)
	await DatabaseManager._save_passes(pass_status, playerId)


# ═══════════════════════════════════════════════════════════════════════════════
# RESTORE OFFLINE PASSES
# ═══════════════════════════════════════════════════════════════════════════════

func restore_offline_passes():
	var current       = int(pass_status.get("current",        MAX_PASSES))
	var last_restored = int(pass_status.get("lastRestoredAt", 0))
	var is_unlimited  = pass_status.get("isUnlimited", false)

	if current >= MAX_PASSES or is_unlimited:
		return

	# Use server time — prevents device time cheating
	var now           = await DatabaseManager.get_server_time()
	var elapsed       = now - last_restored
	var passes_to_add = int(elapsed / RESTORE_INTERVAL)

	if passes_to_add <= 0:
		print("[Passes] No offline passes to restore yet")
		return

	var new_passes                = min(current + passes_to_add, MAX_PASSES)
	pass_status["current"]        = new_passes
	pass_status["lastRestoredAt"] = now

	var uid = Firebase.Auth.auth.get("localid", "")
	await _save(uid)
	print("[Passes] Offline restore: +", passes_to_add, " → ", new_passes, "/", MAX_PASSES)
	emit_signal("passes_updated", new_passes, MAX_PASSES)


# ═══════════════════════════════════════════════════════════════════════════════
# CONSUME — call when player enters a level
# ═══════════════════════════════════════════════════════════════════════════════

func consume_pass() -> Dictionary:
	var current      = int(pass_status.get("current",     0))
	var is_unlimited = pass_status.get("isUnlimited", false)

	if is_unlimited:
		return { "success": true, "current": current, "unlimited": true }

	if current <= 0:
		print("[Passes] No passes left!")
		return { "success": false, "current": 0, "reason": "no_passes" }

	var new_passes = current - 1

	# Start restore timer when first pass consumed from full
	if current == MAX_PASSES:
		var server_time                   = await DatabaseManager.get_server_time()
		pass_status["lastRestoredAt"]     = server_time

	pass_status["current"] = new_passes

	var uid = Firebase.Auth.auth.get("localid", "")
	await _save(uid)

	print("[Passes] Consumed → ", new_passes, "/", MAX_PASSES)
	emit_signal("pass_consumed", new_passes)
	emit_signal("passes_updated", new_passes, MAX_PASSES)

	# Schedule notification for when passes are full
	var passes_missing     = MAX_PASSES - new_passes
	var seconds_until_full = passes_missing * RESTORE_INTERVAL
	# NotificationManager.schedule_passes_full_notification(seconds_until_full)

	return { "success": true, "current": new_passes }


# ═══════════════════════════════════════════════════════════════════════════════
# RESTORE ONE PASS
# ═══════════════════════════════════════════════════════════════════════════════

func restore_one_pass():
	var current = int(pass_status.get("current", 0))
	var now     = await DatabaseManager.get_server_time()

	if current >= MAX_PASSES:
		pass_status["lastRestoredAt"] = now
		await _save(Firebase.Auth.auth.get("localid", ""))
		emit_signal("passes_full")
		return

	var new_passes                = current + 1
	pass_status["current"]        = new_passes
	pass_status["lastRestoredAt"] = now

	var uid = Firebase.Auth.auth.get("localid", "")
	await _save(uid)
	print("[Passes] Restored → ", new_passes, "/", MAX_PASSES)
	emit_signal("pass_restored", new_passes)
	emit_signal("passes_updated", new_passes, MAX_PASSES)

	if new_passes >= MAX_PASSES:
		pass
		# Cancel any existing notifications since we're full now
		#NotificationManager.cancel_notification(
		  #  NotificationManager.NOTIF_PASSES_FULL
	   # )


# ═══════════════════════════════════════════════════════════════════════════════
# BUY WITH COINS
# ═══════════════════════════════════════════════════════════════════════════════

func buy_pass_with_coins() -> Dictionary:
	var current = int(pass_status.get("current", 0))

	if current >= MAX_PASSES:
		return { "success": false, "reason": "already_full" }

	var player = LocalCache.get_player()
	var coins  = int(player.get("coins", 0))

	if coins < PASS_COST_COINS:
		return { "success": false, "reason": "not_enough_coins", "need": PASS_COST_COINS, "have": coins }

	player["coins"]        = coins - PASS_COST_COINS
	pass_status["current"] = min(current + 1, MAX_PASSES)

	LocalCache.set_player(player)
	await DatabaseManager.save_player(player, Firebase.Auth.auth.get("localid", ""))
	await _save(Firebase.Auth.auth.get("localid", ""))

	emit_signal("passes_updated", pass_status["current"], MAX_PASSES)
	return { "success": true, "current": pass_status["current"], "coins_left": player["coins"] }


# ═══════════════════════════════════════════════════════════════════════════════
# GETTERS
# ═══════════════════════════════════════════════════════════════════════════════

func get_current() -> int:
	return int(pass_status.get("current", 0))

func has_passes() -> bool:
	return get_current() > 0 or pass_status.get("isUnlimited", false)

func time_until_next_pass() -> int:
	if get_current() >= MAX_PASSES:
		return 0
	var now          = int(Time.get_unix_time_from_system())
	var last_restored = int(pass_status.get("lastRestoredAt", now))
	var elapsed      = now - last_restored
	var remaining    = RESTORE_INTERVAL - (elapsed % RESTORE_INTERVAL)
	return max(0, int(remaining))

func get_timer_string() -> String:
	var remaining = time_until_next_pass()
	var minutes   = remaining / 60
	var seconds   = remaining % 60
	return "%02d:%02d" % [minutes, seconds]

func get_pass_info() -> Dictionary:
	return {
		"current":        get_current(),
		"max":            MAX_PASSES,
		"has_passes":     has_passes(),
		"is_unlimited":   pass_status.get("isUnlimited", false),
		"time_remaining": get_timer_string(),
		"cost_per_pass":  PASS_COST_COINS
	}
