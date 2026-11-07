#!/usr/bin/env bash
# Hermetic, no-PostgreSQL regression test; no real DB or backup is accessed.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root/bin/rc-staging-restore-preflight"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin"
printf 'PGDMPsynthetic-fixture-not-a-real-backup' > "$tmp/fixture.dump"
chmod 600 "$tmp/fixture.dump"
expected="$(sha256sum "$tmp/fixture.dump" | cut -d ' ' -f 1)"
cat > "$tmp/bin/pg_restore" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  --version) echo "pg_restore (PostgreSQL) ${FAKE_RESTORE_VERSION:-18.6}" ;;
  --list|--file=/dev/null) exit 0 ;;
  *) exit 3 ;;
esac
MOCK
cat > "$tmp/bin/psql" <<'MOCK'
#!/usr/bin/env bash
# Consume SQL, but never connect or write.
cat >/dev/null
printf '%s\n' "${FAKE_DB_STATE:-ABSENT}"
MOCK
chmod 700 "$tmp/bin/pg_restore" "$tmp/bin/psql"
common=(
 "RC_RESTORE_ARCHIVE=$tmp/fixture.dump"
 "RC_EXPECTED_SHA256=$expected"
 'RC_STAGING_DB=rc_restore_check_20261107'
 'RC_STAGING_PGHOST=staging.example.invalid'
 'RC_STAGING_PGPORT=5432'
 'RC_STAGING_PGUSER=restore_checker'
 "RC_PG_RESTORE_BIN=$tmp/bin/pg_restore"
 "RC_PSQL_BIN=$tmp/bin/psql"
)
# Explicitly clear dangerous application context from the test shell.
run() { env -u DATABASE_URL -u RAILS_ENV -u RACK_ENV "${common[@]}" "$@" bash "$script"; }
assert_blocked() {
  if run "$@" >"$tmp/out" 2>&1; then
    echo 'FAIL: expected fail-closed preflight' >&2; cat "$tmp/out" >&2; exit 1
  fi
  grep -q 'PREFLIGHT BLOCKED' "$tmp/out"
}
run | grep -q 'PREFLIGHT PASS'
assert_blocked FAKE_DB_STATE=EXISTS
assert_blocked RC_STAGING_DB=ruby_calendar
assert_blocked RC_STAGING_DB=ruby_calendar_test
assert_blocked RC_EXPECTED_SHA256="$(printf '0%.0s' {1..64})"
assert_blocked FAKE_RESTORE_VERSION=16.11
assert_blocked DATABASE_URL='postgres://production.example.invalid/prod'
assert_blocked RAILS_ENV=production
# No ability to perform CREATE DATABASE / pg_restore --dbname exists in script.
if grep -Eq '(^|[[:space:]])(createdb|dropdb|rails[[:space:]]+db:migrate|pg_restore[[:space:]]+--dbname)' "$script"; then
  echo 'FAIL: prohibited database mutation command found in preflight script' >&2; exit 1
fi
echo 'RC-023 preflight offline negative/positive tests: PASS'
