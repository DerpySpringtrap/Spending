#!/bin/bash
# Runs a two-player co-op test on this machine (host + client over localhost)
# and checks both clients stayed in sync. Usage: tools/coop_test.sh [nodes] [host class] [client class]
cd "$(dirname "$0")/.."
NODES=${1:-12}
HOST_CLASS=${2:-pyre_warden}
CLIENT_CLASS=${3:-rootmother}
PORT=$((24800 + RANDOM % 1000))
OUT=$(mktemp -d)
timeout 900 godot --headless --path . res://tests/coop_test.tscn -- --role=host --port=$PORT --class=$HOST_CLASS --nodes=$NODES > "$OUT/host.txt" 2>&1 &
HOST=$!
sleep 2
timeout 900 godot --headless --path . res://tests/coop_test.tscn -- --role=client --port=$PORT --class=$CLIENT_CLASS --nodes=$NODES > "$OUT/client.txt" 2>&1 &
CLIENT=$!
wait $HOST; H=$?
wait $CLIENT; C=$?
grep "COOP TEST\|FAIL\|SCRIPT ERROR" "$OUT/host.txt" "$OUT/client.txt"
grep "^COOP SYNC" "$OUT/host.txt" > "$OUT/h.sync"
grep "^COOP SYNC" "$OUT/client.txt" > "$OUT/c.sync"
N=$(( $(wc -l < "$OUT/h.sync") < $(wc -l < "$OUT/c.sync") ? $(wc -l < "$OUT/h.sync") : $(wc -l < "$OUT/c.sync") ))
if [ "$N" -gt 0 ] && diff <(head -n $N "$OUT/h.sync") <(head -n $N "$OUT/c.sync") > /dev/null; then
  echo "SYNC: $N checkpoints identical"
  SYNC=0
else
  echo "SYNC: MISMATCH or no checkpoints (logs in $OUT)"
  diff <(head -n $N "$OUT/h.sync") <(head -n $N "$OUT/c.sync") | head -20
  SYNC=1
fi
[ $H -eq 0 ] && [ $C -eq 0 ] && [ $SYNC -eq 0 ] && echo "COOP: PASS" && exit 0
echo "COOP: FAIL (logs in $OUT)"; exit 1
