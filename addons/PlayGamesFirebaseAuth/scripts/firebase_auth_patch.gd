# ==============================================================================
# PATCH FILE: auth.gd  (addons/godot-firebase/auth/auth.gd)
# ==============================================================================
#
# This file documents the EXACT changes needed in the godot-firebase addon
# to support Google Play Games Services authentication.
#
# DO NOT replace your entire auth.gd with this file.
# Instead, find the login_with_google_play function and apply the diff below.
#
# ── WHAT TO CHANGE ────────────────────────────────────────────────────────────
#
# Find the existing login_with_google_play function (or add it if missing):
#
#   BEFORE (broken - causes INVALID_CREDENTIAL_OR_PROVIDER_ID):
#   func login_with_google_play(auth_code: String) -> void:
#       if _is_ready():
#           is_busy = true
#           _oauth_login_request_body.postBody = "serverAuthCode=" + auth_code + "&providerId=playgames.google.com"
#           _oauth_login_request_body.requestUri = "http://localhost"
#           ...
#
#   AFTER (correct - uses OAuth 2.0 spec's "code=" key + URI encoding):
#   func login_with_google_play(auth_code: String) -> void:
#       if _is_ready():
#           is_busy = true
#           _oauth_login_request_body.postBody = "code=" + auth_code.uri_encode() + "&providerId=playgames.google.com"
#           _oauth_login_request_body.requestUri = "http://localhost"
#           _oauth_login_request_body.returnIdpCredential = true
#           var err = request(
#               _base_url + _signin_with_oauth_request_url,
#               _headers,
#               HTTPClient.METHOD_POST,
#               JSON.stringify(_oauth_login_request_body)
#           )
#
# KEY DIFFERENCES:
#   1. "serverAuthCode=" → "code="       (OAuth 2.0 spec compliance)
#   2. Added .uri_encode() on the auth_code (safety for special chars)
#   3. returnIdpCredential = true         (ensures Firebase returns full user data)
#
# ── WHY THIS MATTERS ──────────────────────────────────────────────────────────
#
# Firebase's signInWithIdp endpoint reconstructs a URL like:
#   http://localhost?<postBody_key>=<value>
#
# Google's OAuth2 server strictly validates that the authorization code
# is passed with the key "code" (per RFC 6749 §4.1.2).
# Any other key name (serverAuthCode, authCode, token, etc.) causes:
#   { "error": { "code": 400, "message": "INVALID_CREDENTIAL_OR_PROVIDER_ID" } }
#
# ==============================================================================

# This script is for documentation purposes only.
# Apply the patch manually to your godot-firebase addon.
