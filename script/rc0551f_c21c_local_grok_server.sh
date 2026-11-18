#!/usr/bin/env bash
# RC055.1f C2.1c — launch local owner-only live Grok pilot on an explicitly
# named review DB. No DB DDL, provider call, or secret is printed by this script.
# Existing port 3001 and private storage are never touched.
set -euo pipefail
set +x
umask 077

fail() { printf 'STOP: %s\n' "$1" >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$root"

[[ "${RAILS_ENV:-development}" == development ]] || fail "Only development permitted"
[[ "${RACK_ENV:-development}" != production ]] || fail "Production environment forbidden"
[[ -z "${DATABASE_URL:-}" ]] || fail "Global DATABASE_URL must be unset"
[[ -n "${RC_LOCAL_DEV_DATABASE_URL:-}" ]] || fail "Explicit RC_LOCAL_DEV_DATABASE_URL required"
original_db_url="$RC_LOCAL_DEV_DATABASE_URL"

secret="$HOME/.config/rails-calendar/calendar-ai.dev.env"
[[ -f "$secret" && -r "$secret" && ! -L "$secret" ]] || fail "Private local AI config file not readable"
secret_mode="$(stat -c '%a' "$secret")"
# Allow 0600 / 0400, or owner+group read-only. No world permissions.
(( (8#$secret_mode & 0007) == 0 )) || fail "AI config permissions expose secrets to other users"

port="${RC_C21C_PORT:-3002}"
[[ "$port" =~ ^[0-9]{4,5}$ ]] || fail "Invalid localhost port"
if ss -H -ltn "sport = :$port" | grep -q .; then
  fail "Port $port already listening; stop its old Puma process manually first"
fi

# A shell-compatible local config is already used by bin/rc051-paid-pilot.
# Only its own saved file is sourced; secret values are never echoed/logged.
set -a
# shellcheck disable=SC1090
source "$secret"
set +a
[[ "${RC_LOCAL_DEV_DATABASE_URL:-}" == "$original_db_url" ]] || fail "AI file changed database target"
[[ -z "${DATABASE_URL:-}" ]] || fail "AI file injected global DATABASE_URL"

export RAILS_ENV=development RC_GROK_ENABLED=true
export RC_C21C_EXPECTED_DB="${RC_C21C_EXPECTED_DB:-rails_calendar_rc0551f_c21b_review_20261117}"
[[ "$RC_C21C_EXPECTED_DB" =~ ^rails_calendar_rc0551f_c21[a-z0-9_]*$ ]] ||
  fail "Only a named RC0551f C2.1 local review/scratch DB is allowed"

bundle exec rails runner '
  abort "STOP: wrong Rails env" unless Rails.env.development?
  db = ActiveRecord::Base.connection
  name = db.select_value("SELECT current_database()")
  host = db.select_value("SELECT coalesce(inet_server_addr()::text, '\''socket'\'')")
  abort "STOP: database identity mismatch" unless name == ENV.fetch("RC_C21C_EXPECTED_DB")
  abort "STOP: database host is not local" unless ["socket", "127.0.0.1", "::1"].include?(host)
  required = %w[users workspaces professional_profiles ai_spend_entries owner_ai_conversations owner_ai_messages]
  abort "STOP: missing AI tables" unless required.all? { |table| db.data_source_exists?(table) }
  abort "STOP: Grok not enabled in this process; check private config" unless OwnerIntelligence::Grok.enabled?
  puts "C21C_LOCAL_GROK_READY (no provider call, no DB write)"
  puts "C21C_DATABASE=verified_local_review"
'
printf 'Starting live AI owner UI on localhost:%s; each paid turn still needs in-app consent.\n' "$port"
exec bundle exec rails server -b 127.0.0.1 -p "$port"
