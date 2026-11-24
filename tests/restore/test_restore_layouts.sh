#!/usr/bin/env bash
# Offline test of backup/restore.sh for the three snapshot layouts it must handle:
#   1. repository stack: .env inside the backed-up repository;
#   2. repository stack, .env only under extra/ (one candidate, picked automatically);
#   3. hand-built live stack: its own compose file and .env under extra/, operator token under another name.
# restic, docker and ip are replaced by stubs on PATH; no container, network or real backup is touched.
set -Eeuo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
PASS=0 FAIL=0

mkdir -p "$TMP/bin"
cat > "$TMP/bin/restic" <<'EOF'
#!/usr/bin/env bash
# restic stub: "restore <id> --target DIR" copies the prepared snapshot; other commands are no-ops.
if [[ "$1" == restore ]]; then cp -a "$FAKE_SNAPSHOT/." "$4/"; fi
exit 0
EOF
cat > "$TMP/bin/docker" <<'EOF'
#!/usr/bin/env bash
# docker stub: records every call; never runs anything.
printf '%s\n' "$*" >> "$DOCKER_LOG"
exit 0
EOF
cat > "$TMP/bin/ip" <<'EOF'
#!/usr/bin/env bash
echo "1: wg0    inet 10.66.0.1/24 scope global wg0"
EOF
chmod +x "$TMP/bin/"*

printf 'RESTIC_REPOSITORY=s3:fake\nRESTIC_PASSWORD=fake\n' > "$TMP/restic.env"

make_snapshot() {  # $1 = snapshot dir
  local s="$1/var/tmp/projectd-backup.X"
  mkdir -p "$s/project/deployment/contabo" "$s/influxdb" "$s/grafana" "$s/mosquitto-data"
  cp "$REPO/deployment/contabo/compose.yml" "$s/project/deployment/contabo/"
  echo "$s"
}

run_case() {  # name, expected exit code, extra restore args...
  local name="$1" expected="$2"; shift 2
  local dest="$TMP/dest-$name" code=0
  : > "$TMP/docker-$name.log"
  PATH="$TMP/bin:$PATH" BACKUP_ENV="$TMP/restic.env" DOCKER_LOG="$TMP/docker-$name.log" \
    FAKE_SNAPSHOT="$TMP/snap-$name" \
    bash "$REPO/backup/restore.sh" --apply --yes --destination "$dest" "$@" > "$TMP/out-$name.log" 2>&1 || code=$?
  if [[ "$code" == "$expected" ]]; then
    PASS=$((PASS + 1)); echo "ok   $name (exit $code)"
  else
    FAIL=$((FAIL + 1)); echo "FAIL $name: exit $code, expected $expected"; sed 's/^/     /' "$TMP/out-$name.log"
  fi
}

check() {  # description, command...
  if "${@:2}"; then PASS=$((PASS + 1)); echo "ok   $1"; else FAIL=$((FAIL + 1)); echo "FAIL $1"; fi
}

# 1. Repository .env.
s="$(make_snapshot "$TMP/snap-repo")"
printf 'INFLUX_TOKEN=repo-token-value\n' > "$s/project/deployment/contabo/.env"
run_case repo 0
check "repo: compose uses the repository stack" grep -q -- "-f $TMP/dest-repo/deployment/contabo/compose.yml" "$TMP/docker-repo.log"
check "repo: token reaches influx restore" grep -q -- "--token repo-token-value" "$TMP/docker-repo.log"

# 2. Repository stack, .env only under extra/.
s="$(make_snapshot "$TMP/snap-extra")"
mkdir -p "$s/extra/opt/live"
printf 'INFLUX_TOKEN=extra-token-value\n' > "$s/extra/opt/live/.env"
run_case extra 0
check "extra: .env copied into the restored repository" test -f "$TMP/dest-extra/deployment/contabo/.env"
check "extra: restored .env is mode 600" test "$(stat -c %a "$TMP/dest-extra/deployment/contabo/.env")" = 600
check "extra: token reaches influx restore" grep -q -- "--token extra-token-value" "$TMP/docker-extra.log"

# 2b. Two candidates under extra/ and no --env-file: must refuse and print paths only.
s="$(make_snapshot "$TMP/snap-ambiguous")"
mkdir -p "$s/extra/opt/a" "$s/extra/opt/b"
printf 'INFLUX_TOKEN=secret-a\n' > "$s/extra/opt/a/.env"
printf 'INFLUX_TOKEN=secret-b\n' > "$s/extra/opt/b/.env"
run_case ambiguous 1
check "ambiguous: lists candidate paths" grep -q "/opt/a/.env" "$TMP/out-ambiguous.log"
check "ambiguous: never prints secrets" bash -c "! grep -q secret- '$TMP/out-ambiguous.log'"
check "ambiguous: nothing started" test ! -s "$TMP/docker-ambiguous.log"

# 3. Hand-built live stack with its own compose file and token variable name.
s="$(make_snapshot "$TMP/snap-live")"
mkdir -p "$s/extra/opt/Live_Stack/config"
printf 'services: {}\n' > "$s/extra/opt/Live_Stack/docker-compose.yml"
printf 'listener 8883\n' > "$s/extra/opt/Live_Stack/config/mosquitto.conf"
printf 'DOCKER_INFLUXDB_INIT_ADMIN_TOKEN=live-token-value\n' > "$s/extra/opt/Live_Stack/.env"
run_case live 0 --compose-file /opt/Live_Stack/docker-compose.yml --env-file /opt/Live_Stack/.env \
  --influx-token-var DOCKER_INFLUXDB_INIT_ADMIN_TOKEN
check "live: compose uses the live stack's file" grep -q -- "-f $TMP/dest-live/live-deployment/docker-compose.yml" "$TMP/docker-live.log"
check "live: relative config kept next to compose" test -f "$TMP/dest-live/live-deployment/config/mosquitto.conf"
check "live: token from the named variable" grep -q -- "--token live-token-value" "$TMP/docker-live.log"

# 3b. Wrong token variable name: clear error before anything starts.
s="$(make_snapshot "$TMP/snap-badvar")"
mkdir -p "$s/extra/opt/L"
printf 'services: {}\n' > "$s/extra/opt/L/docker-compose.yml"
printf 'OTHER=1\n' > "$s/extra/opt/L/.env"
run_case badvar 1 --compose-file /opt/L/docker-compose.yml --env-file /opt/L/.env
check "badvar: names the missing variable" grep -q "INFLUX_TOKEN is missing" "$TMP/out-badvar.log"
check "badvar: nothing started" test ! -s "$TMP/docker-badvar.log"

echo "restore layouts: $PASS passed, $FAIL failed"
[[ "$FAIL" == 0 ]]
