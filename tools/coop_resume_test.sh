#!/bin/bash
# Co-op save/continue: two copies play, the client drops out, then the host
# continues the saved run and the client rejoins. The first state after
# continuing must equal the last state both saw before the drop.
cd "$(dirname "$0")/.."
PORT=$((24800 + RANDOM % 1000))
OUT=$(mktemp -d)
HS="--coop-save=user://coop_test_host.json"
CS="--coop-save=user://coop_test_client.json"
run_pair() { # $1 = tag, $2 = extra host args, $3 = extra client args
  timeout 600 godot --headless --path . res://tests/coop_test.tscn -- --role=host --port=$PORT --class=pyre_warden --nodes=${NODES:-8} $HS $2 > "$OUT/$1_host.txt" 2>&1 &
  local H=$!
  sleep 2
  timeout 600 godot --headless --path . res://tests/coop_test.tscn -- --role=client --port=$PORT --class=hollow_scribe --nodes=${NODES:-8} $CS $3 > "$OUT/$1_client.txt" 2>&1
  wait $H
}
NODES=12 run_pair first "" "--leave-at=4"
PORT=$((PORT + 1))
NODES=4 run_pair second "--resume" ""
grep -h "COOP TEST\|FAIL\|LEAVING" "$OUT"/*.txt
BEFORE=$(grep "^COOP SYNC 4:" "$OUT/first_client.txt" | sed 's/^COOP SYNC [0-9]*: //')
AFTER_H=$(grep "^COOP SYNC 1:" "$OUT/second_host.txt" | sed 's/^COOP SYNC [0-9]*: //')
AFTER_C=$(grep "^COOP SYNC 1:" "$OUT/second_client.txt" | sed 's/^COOP SYNC [0-9]*: //')
STATUS=0
[ -n "$BEFORE" ] && [ "$BEFORE" == "$AFTER_H" ] && [ "$AFTER_H" == "$AFTER_C" ] || STATUS=1
diff <(grep "^COOP SYNC" "$OUT/second_host.txt") <(grep "^COOP SYNC" "$OUT/second_client.txt") > /dev/null || STATUS=1
grep -q "COOP TEST (host): PASS" "$OUT/second_host.txt" && grep -q "COOP TEST (client): PASS" "$OUT/second_client.txt" || STATUS=1
if [ $STATUS -eq 0 ]; then echo "RESUME: PASS (continued run matches the state before the drop)"; else echo "RESUME: FAIL (logs in $OUT)"; fi
exit $STATUS
