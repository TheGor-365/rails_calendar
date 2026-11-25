#!/usr/bin/env bash
# C2.5a1 isolated UI review. Only the named local worktree / database / port.
# Avoids fragile long pasted heredocs and broken asdf npm shims.
# Does not migrate, seed, delete, deploy, or initiate an AI provider call.
set -euo pipefail
set +x
umask 077

stop() { printf 'STOP: %s\n' "$1" >&2; exit 2; }
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
review="$HOME/rails_calendar_c25a_ia_review_20261123"
[[ "$root" == "$review" ]] || stop "Only the isolated C2.5a worktree may be used"
cd "$root"

expected="${RC_C25A1_EXPECTED_SHA:-}"
[[ "$expected" =~ ^[0-9a-f]{40}$ ]] || stop "Set RC_C25A1_EXPECTED_SHA to the exact approved code/document commit"
[[ "$(git rev-parse HEAD)" == "$expected" ]] || stop "Unexpected local HEAD"
git diff --quiet && git diff --cached --quiet || stop "Tracked source files modified"
[[ "${RAILS_ENV:-development}" == development ]] || stop "Development environment required"
[[ "${RACK_ENV:-development}" != production ]] || stop "Production environment forbidden"
[[ -z "${DATABASE_URL:-}" ]] || stop "Global DATABASE_URL must be unset"
[[ -z "$(ss -H -ltn 'sport = :3003')" ]] || stop "Port 3003 already listening; stop only the review server first"

ruby_dir="$HOME/.asdf/installs/ruby/3.4.13/bin"
[[ -x "$ruby_dir/ruby" ]] || stop "Ruby 3.4.13 executable missing"
export PATH="$ruby_dir:$PATH"
export ASDF_RUBY_VERSION=3.4.13
[[ "$(ruby -e 'print RUBY_VERSION')" == 3.4.13 ]] || stop "Wrong Ruby"
BUNDLE_FROZEN=true bundle check >/dev/null || stop "Bundler dependencies missing; do not install automatically"

node_bin=""
for dir in "$HOME"/.asdf/installs/nodejs/*/bin "$HOME"/.nvm/versions/node/*/bin "$HOME"/.local/share/mise/installs/node/*/bin "$HOME"/.local/share/fnm/node-versions/*/installation/bin /usr/local/bin /usr/bin; do
  [[ -x "$dir/node" && -x "$dir/npm" ]] || continue
  if PATH="$dir:$PATH" "$dir/npm" --version >/dev/null 2>&1; then
    node_bin="$dir"
    break
  fi
done
[[ -n "$node_bin" ]] || stop "Direct Node/npm installation not found"
export PATH="$node_bin:$PATH"
hash -r
printf 'NODE=%s NPM=%s\n' "$(node --version)" "$(npm --version)"

[[ -x node_modules/.bin/esbuild && -x node_modules/.bin/sass ]] || stop "Existing node_modules missing; review before npm install"
npm run build
npm run build:css
[[ -s app/assets/builds/application.js && -s app/assets/builds/application.css ]] || stop "Frontend assets are not present"
git diff --quiet && git diff --cached --quiet || stop "Build modified tracked source files"
printf 'C25A1_ASSETS_READY=PASS\n'

unset DATABASE_URL GEM_HOME GEM_PATH BUNDLE_GEMFILE
export RAILS_ENV=development RACK_ENV=development
export RC_LOCAL_DEV_DATABASE_URL='postgresql://gor@localhost/rails_calendar_rc0551f_c21b_review_20261117?host=%2Fvar%2Frun%2Fpostgresql'
export RC_C21C_EXPECTED_DB='rails_calendar_rc0551f_c21b_review_20261117'
export RC_C21C_PORT=3003

exec bash script/rc0551f_c21c_local_grok_server.sh
