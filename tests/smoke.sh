#!/usr/bin/env sh
# Static checks on the Gatherly page (run in CI before building the image)
set -e
FILE="app/index.html"
test -f "$FILE"                       || { echo "FAIL: $FILE missing"; exit 1; }
grep -q "<title>Gatherly</title>" "$FILE" || { echo "FAIL: title"; exit 1; }
grep -q "<h1>Gatherly</h1>" "$FILE"       || { echo "FAIL: heading"; exit 1; }
test "$(grep -c '<button' "$FILE")" -ge 2 || { echo "FAIL: expected 2 buttons"; exit 1; }
echo "PASS: page checks"
