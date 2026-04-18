#!/bin/bash
set -euo pipefail

rm -f tmp/pids/server.pid

echo "[entrypoint] FOAF_NETWORK=${FOAF_NETWORK:-unset} RAILS_ENV=${RAILS_ENV}"
echo "[entrypoint] Running migrations..."
bundle exec rails db:migrate

echo "[entrypoint] Starting Puma on port ${PORT:-3002}..."
exec bundle exec puma -C config/puma.rb
