#!/usr/bin/env bash
set -uo pipefail

BASE="${1:-}"
TOKEN="${2:-}"
if [ -z "$BASE" ]; then
  echo "usage: scripts/smoke.sh <base-url> [session-token]" >&2
  echo "  base-url: https://<project-ref>.supabase.co/functions/v1" >&2
  exit 2
fi

pass=0
fail=0
pending=0
rows=""

body_file=$(mktemp)
trap 'rm -f "$body_file"' EXIT

call() {
  local method="$1" path="$2"
  shift 2
  curl -sS -X "$method" "$BASE$path" -o "$body_file" -w '%{http_code}' "$@" 2>/dev/null
}

record() {
  local name="$1" expected="$2" actual="$3" verdict="$4"
  rows+="| $name | $expected | $actual | $verdict |"$'\n'
  case "$verdict" in
    pass) pass=$((pass + 1)) ;;
    pending) pending=$((pending + 1)) ;;
    *) fail=$((fail + 1)) ;;
  esac
}

check() {
  local name="$1" expected_code="$2" expected_text="$3" actual_code="$4"
  local body
  body=$(head -c 200 "$body_file" | tr -d '\n')
  if [ "$actual_code" = "$expected_code" ] && { [ -z "$expected_text" ] || grep -q "$expected_text" "$body_file"; }; then
    record "$name" "$expected_code${expected_text:+ $expected_text}" "$actual_code $body" pass
  else
    record "$name" "$expected_code${expected_text:+ $expected_text}" "$actual_code $body" FAIL
  fi
}

anon=$(uuidgen | tr 'A-Z' 'a-z')
other_anon=$(uuidgen | tr 'A-Z' 'a-z')
space=$(uuidgen | tr 'A-Z' 'a-z')

code=$(call GET "/fx?base=USD")
check "GET /fx?base=USD" 200 '"rates"' "$code"

code=$(call GET "/fx?base=XX")
check "GET /fx?base=XX (bad code)" 400 invalid_request "$code"

code=$(call GET /config)
check "GET /config" 200 monetizationEnabled "$code"

code=$(call POST /parse -H 'content-type: application/json' -d '{"url":"https://www.ikea.com/us/en/p/billy-bookcase-black-oak-effect-00477337/"}')
check "POST /parse" 200 canonicalURL "$code"

code=$(call POST /parse -H 'content-type: application/json' -d '{"url":"not a url"}')
check "POST /parse (bad url)" 400 invalid_request "$code"

code=$(call POST /events -H 'content-type: application/json' -H "x-anon-id: $anon" -d '{"events":[{"name":"smoke_check_not_stored","ts":"2026-01-01T00:00:00Z","appVersion":"smoke","locale":"en_US"}]}')
check "POST /events (name off the allowlist, nothing stored)" 202 "" "$code"

code=$(call POST /events -H 'content-type: application/json' -H 'x-anon-id: nope' -d '{"events":[]}')
check "POST /events (bad anon id)" 400 invalid_request "$code"

code=$(call GET /invite-redeem/ZZZZZZ)
check "GET /invite-redeem/ZZZZZZ" 404 not_found "$code"

code=$(call GET "/entitlement/$space")
check "GET /entitlement/{id} (no auth)" 401 unauthorized "$code"

code=$(call GET /fx -X OPTIONS)
check "OPTIONS /fx" 405 invalid_request "$code"

if [ -n "$TOKEN" ]; then
  invite_body="{\"spaceId\":\"$space\",\"shareURL\":\"https://www.icloud.com/share/corbie-smoke-test\"}"
  code=$(call POST /invite -H 'content-type: application/json' -H "authorization: Bearer $TOKEN" -d "$invite_body")
  check "POST /invite (session token)" 201 '"code"' "$code"
  replaced=$(grep -o '"code":"[A-Z0-9]*"' "$body_file" | head -1 | cut -d'"' -f4)
  code=$(call POST /invite -H 'content-type: application/json' -H "authorization: Bearer $TOKEN" -d "$invite_body")
  check "POST /invite (a second code for the same space)" 201 '"code"' "$code"
  invite=$(grep -o '"code":"[A-Z0-9]*"' "$body_file" | head -1 | cut -d'"' -f4)

  if [ -n "$replaced" ] && [ -n "$invite" ]; then
    code=$(call "GET" "/invite-redeem/$replaced" -H "x-anon-id: $anon")
    check "GET /invite-redeem/{replaced code}" 410 superseded "$code"
    code=$(call "GET" "/invite-redeem/$invite" -H "x-anon-id: $anon")
    check "GET /invite-redeem/{fresh code}" 200 shareURL "$code"
    code=$(call "GET" "/invite-redeem/$invite" -H "x-anon-id: $anon")
    check "GET /invite-redeem/{same code, same device}" 200 shareURL "$code"
    code=$(call "GET" "/invite-redeem/$invite" -H "x-anon-id: $other_anon")
    check "GET /invite-redeem/{same code, other device}" 409 redeemed "$code"
    code=$(call "GET" "/invite-redeem/$invite")
    check "GET /invite-redeem/{same code, no device id}" 409 redeemed "$code"
  else
    for name in "GET /invite-redeem/{replaced code}" "GET /invite-redeem/{fresh code}" "GET /invite-redeem/{same code, same device}" "GET /invite-redeem/{same code, other device}" "GET /invite-redeem/{same code, no device id}"; do
      record "$name" "a code to redeem" "no code issued" FAIL
    done
  fi

  code=$(call GET "/entitlement/$space" -H "authorization: Bearer $TOKEN")
  check "GET /entitlement/{id} (session token)" 200 '"none"' "$code"

  code=$(call POST /session -H 'content-type: application/json' -H "authorization: Bearer $TOKEN" -d '{}')
  check "POST /session (session token refused)" 401 unauthorized "$code"

  code=$(call POST /apple-revoke -H 'content-type: application/json' -H "authorization: Bearer $TOKEN" -d '{"authorizationCode":"smoke"}')
  body=$(head -c 200 "$body_file" | tr -d '\n')
  if [ "$code" = "500" ] && grep -q "APPLE_" "$body_file"; then
    record "POST /apple-revoke" "204 once Apple keys are set" "$code $body" pending
  elif [ "$code" = "502" ] || [ "$code" = "400" ]; then
    record "POST /apple-revoke" "204 with a real authorization code" "$code $body" pending
  else
    record "POST /apple-revoke" "204 with a real authorization code" "$code $body" FAIL
  fi
else
  for name in "POST /invite (session token)" "POST /invite (a second code for the same space)" "GET /invite-redeem/{replaced code}" "GET /invite-redeem/{fresh code}" "GET /invite-redeem/{same code, same device}" "GET /invite-redeem/{same code, other device}" "GET /invite-redeem/{same code, no device id}" "GET /entitlement/{id} (session token)" "POST /session (session token refused)" "POST /apple-revoke"; do
    record "$name" "needs a session token" "not run, no token given" pending
  done
fi

code=$(call POST /appstore-notifications -H 'content-type: application/json' -d '{"signedPayload":"not-a-jws"}')
body=$(head -c 200 "$body_file" | tr -d '\n')
if [ "$code" = "400" ]; then
  record "POST /appstore-notifications (garbage)" "400 invalid_request, real flow needs Apple" "$code $body" pending
else
  record "POST /appstore-notifications (garbage)" "400 invalid_request, real flow needs Apple" "$code $body" FAIL
fi

code=$(call POST /session -H 'content-type: application/json' -d '{}')
check "POST /session (no token)" 401 unauthorized "$code"

printf '\n| Endpoint | Expected | Actual | Verdict |\n| --- | --- | --- | --- |\n%s\n' "$rows"
printf 'pass %d, fail %d, pending %d\n' "$pass" "$fail" "$pending"
[ "$fail" -eq 0 ]
