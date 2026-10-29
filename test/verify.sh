#!/bin/bash
# Validation helper for Audio Boost.
# Usage: ./test/verify.sh [path-to-plugin]

set -uo pipefail

PLUGIN="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0

pass() { echo "  OK  $*"; }
bad() { echo " FAIL $*"; fail=1; }

echo "== Manifest =="
if omarchy plugin validate "$PLUGIN" >/dev/null 2>&1; then
  pass "omarchy schema validation"
else
  bad "omarchy schema validation"
fi

if node -e '
const fs = require("fs");
const path = require("path");
const dir = process.argv[1];
const m = JSON.parse(fs.readFileSync(path.join(dir, "manifest.json"), "utf8"));
const required = ["schemaVersion","id","name","version","author","license","description","kinds","entryPoints"];
let rc = 0;
for (const f of required) {
  if (!(f in m)) { console.error("missing required field: " + f); rc = 1; }
}
if (m.schemaVersion !== 1) { console.error("schemaVersion must be 1"); rc = 1; }
if (m.id !== "io.github.kingokeke.audio-boost") { console.error("unexpected id"); rc = 1; }
for (const kind of ["bar-widget","panel"]) {
  if (!Array.isArray(m.kinds) || !m.kinds.includes(kind)) { console.error("missing kind: " + kind); rc = 1; }
}
if (!m.entryPoints || !m.entryPoints.barWidget || !m.entryPoints.panel) { console.error("missing entryPoints"); rc = 1; }
for (const ep of [m.entryPoints.barWidget, m.entryPoints.panel]) {
  if (ep && !fs.existsSync(path.join(dir, ep))) { console.error("missing entry point file: " + ep); rc = 1; }
}
if (m.keepLoaded !== true) { console.error("keepLoaded must be true"); rc = 1; }
if (!m.omarchy || m.omarchy.clonedFrom !== "omarchy.osd") { console.error("clonedFrom must be omarchy.osd"); rc = 1; }
const keys = (m.barWidget && Array.isArray(m.barWidget.schema) ? m.barWidget.schema : []).map((s) => s.key);
for (const key of ["maxVolume","step","showPercent","warnOnBoost","boostEnabled","overdriveColor"]) {
  if (!keys.includes(key)) { console.error("missing setting: " + key); rc = 1; }
}
process.exit(rc);
' "$PLUGIN" >/dev/null 2>&1; then
  pass "required fields, kinds, entry points, clone source, settings"
else
  bad "required fields, kinds, entry points, clone source, settings"
fi

echo "== Helper =="
if bash -n "$PLUGIN/bin/omarchy-volume-boost"; then
  pass "bin/omarchy-volume-boost syntax"
else
  bad "bin/omarchy-volume-boost syntax"
fi

echo "== QML features =="
grep -q 'BoostSlider' "$PLUGIN/Panel.qml" && pass "panel uses BoostSlider" || bad "panel uses BoostSlider"
grep -q 'toggleBoost' "$PLUGIN/Panel.qml" && pass "panel has toggleBoost" || bad "panel has toggleBoost"
grep -q 'overdriveColor' "$PLUGIN/Panel.qml" && pass "panel has overdriveColor" || bad "panel has overdriveColor"
grep -q 'boostFrom' "$PLUGIN/Osd.qml" 2>/dev/null || true
grep -q 'overdriveFrom' "$PLUGIN/Osd.qml" && pass "OSD has overdriveFrom" || bad "OSD has overdriveFrom"
grep -q 'overdriveColor' "$PLUGIN/Osd.qml" && pass "OSD has overdriveColor" || bad "OSD has overdriveColor"
grep -q '_boostValue' "$PLUGIN/BoostSlider.qml" && pass "slider has boost segment" || bad "slider has boost segment"

echo "== Marketplace safety self-check =="
forbidden_names=$(find "$PLUGIN" -name .git -prune -o -type f \
  \( -iname '*install*' -o -iname '*setup*' -o -iname '*uninstall*' \) -print 2>/dev/null)
if [[ -z $forbidden_names ]]; then
  pass "no install/setup/uninstall filenames"
else
  bad "install/setup/uninstall filenames present: $forbidden_names"
fi

forbidden_text=$(grep -RIn --exclude-dir=.git --exclude-dir=test \
  -E '\b(sudo|pkexec)\b|omarchy pkg (add|drop|remove|update)|\b(pacman|paru|yay|apt-get|apt|dnf|zypper|apk)\b[^\n]*\b(install|remove|upgrade|add|del)\b|\bsystemctl\b|\bsystemd-run\b|\bcurl\b|\bwget\b|\bgit clone\b' \
  "$PLUGIN" 2>/dev/null)
if [[ -z $forbidden_text ]]; then
  pass "no obvious privilege/package/service/remote-exec patterns"
else
  bad "forbidden patterns found:"
  printf '%s\n' "$forbidden_text"
fi

echo
if (( fail )); then
  echo "FAILED"
  exit 1
fi
echo "All checks passed."
