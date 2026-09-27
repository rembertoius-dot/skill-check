#!/usr/bin/env bash
# Scan an agent skill BEFORE installing or updating it. Never installs anything from the skill itself.
#
# Usage: check_skill.sh <source>
#   <source> = owner/repo | https://github.com/owner/repo[/tree/branch/path] | local folder | file.skill (zip)
#
# Fetches the skill into a throwaway folder, runs two free, offline-capable scanners
# (NVIDIA SkillSpector --no-llm, Cisco skill-scanner static analyzers), and prints where the reports
# and the fetched files are, so the agent can read them. Exit code: 0 ran fine, 2 couldn't fetch/scan.
set -uo pipefail

SRC="${1:?usage: check_skill.sh <owner/repo | github url | folder | file.skill>}"
HOME_DIR="${SKILL_CHECK_HOME:-$HOME/.skill-check}"
VENV="$HOME_DIR/venv"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/skill-check.XXXXXX")"
FETCHED="$WORK/src"
REPORTS="$WORK/reports"
mkdir -p "$REPORTS"

# --- the scanners live in their own venv, installed once -------------------------------------------
pick_python() {
  for c in python3.13 python3.12 python3.11 python3.10 /opt/homebrew/bin/python3.12; do
    command -v "$c" >/dev/null 2>&1 && { command -v "$c"; return; }
  done
}
# Reuse scanners the user already has on PATH (e.g. an existing SkillSpector install); otherwise use
# (and if needed create) our own venv.
SS_BIN="$(command -v skillspector || echo "$VENV/bin/skillspector")"
SC_BIN="$(command -v skill-scanner || echo "$VENV/bin/skill-scanner")"
if [ ! -x "$SS_BIN" ] || [ ! -x "$SC_BIN" ]; then
  PY="$(pick_python)"
  [ -n "$PY" ] || { echo "Need Python 3.10+ (macOS: brew install python@3.12)" >&2; exit 2; }
  echo "First run: installing the scanners into $VENV (one time)…" >&2
  mkdir -p "$HOME_DIR"
  "$PY" -m venv "$VENV" && "$VENV/bin/pip" install -q --upgrade pip >/dev/null 2>&1
  PKGS=()
  [ -x "$SS_BIN" ] || PKGS+=("git+https://github.com/NVIDIA/skillspector.git")
  [ -x "$SC_BIN" ] || PKGS+=("cisco-ai-skill-scanner")
  "$VENV/bin/pip" install -q "${PKGS[@]}" || { echo "Scanner install failed" >&2; exit 2; }
  [ -x "$SS_BIN" ] || SS_BIN="$VENV/bin/skillspector"
  [ -x "$SC_BIN" ] || SC_BIN="$VENV/bin/skill-scanner"
fi

# --- fetch the skill without installing it --------------------------------------------------------
case "$SRC" in
  *.skill|*.zip)
    mkdir -p "$FETCHED" && unzip -q "$SRC" -d "$FETCHED" || { echo "Can't unzip $SRC" >&2; exit 2; } ;;
  /*|./*|~*)
    cp -R "${SRC/#\~/$HOME}" "$FETCHED" || { echo "Can't read $SRC" >&2; exit 2; } ;;
  http*://github.com/*|[A-Za-z0-9_.-]*/[A-Za-z0-9_.-]*)
    URL="$SRC"; SUBPATH=""
    [[ "$SRC" != http* ]] && URL="https://github.com/$SRC"
    if [[ "$URL" =~ ^(https://github.com/[^/]+/[^/]+)/tree/([^/]+)/?(.*)$ ]]; then
      URL="${BASH_REMATCH[1]}"; BRANCH="${BASH_REMATCH[2]}"; SUBPATH="${BASH_REMATCH[3]}"
      git clone -q --depth 1 --branch "$BRANCH" "$URL" "$WORK/repo" || { echo "Can't clone $URL" >&2; exit 2; }
    else
      git clone -q --depth 1 "$URL" "$WORK/repo" || { echo "Can't clone $URL" >&2; exit 2; }
    fi
    mv "$WORK/repo/$SUBPATH" "$FETCHED" 2>/dev/null || mv "$WORK/repo" "$FETCHED"
    ( cd "$FETCHED" && git log -1 --format='commit %h (%cd) by %an' 2>/dev/null ) > "$REPORTS/source.txt" ;;
  *) echo "Don't know how to fetch: $SRC" >&2; exit 2 ;;
esac

# --- scan ---------------------------------------------------------------------------------------
"$SS_BIN" scan "$FETCHED" --no-llm --format json --output "$REPORTS/skillspector.json" >"$REPORTS/skillspector.log" 2>&1
SS=$?
# Cisco's scanner wants a folder with SKILL.md at its root; repos with skills in subfolders use scan-all.
if [ -f "$FETCHED/SKILL.md" ]; then
  "$SC_BIN" scan "$FETCHED" --format json --output "$REPORTS/cisco.json" >"$REPORTS/cisco.log" 2>&1
else
  "$SC_BIN" scan-all "$FETCHED" --recursive --format json --output "$REPORTS/cisco.json" >"$REPORTS/cisco.log" 2>&1
fi
CS=$?

# --- inventory for the human review ---------------------------------------------------------------
( cd "$FETCHED" && find . -type f ! -path './.git/*' | sort ) > "$REPORTS/files.txt"
( cd "$FETCHED" && grep -rnIE \
  'curl[^|]*\|\s*(ba)?sh|wget[^|]*\|\s*(ba)?sh|base64 (-d|--decode)|eval\(|exec\(|child_process|subprocess|os\.system|\.env\b|id_rsa|\.ssh/|keychain|security find-|AWS_SECRET|API_KEY|TOKEN|webhook|ngrok|pastebin|discord(app)?\.com/api/webhooks|rm -rf|chmod \+x|crontab|launchctl|~/\.claude/settings|dangerously|--no-verify|ignore (all|previous) instructions|do not (tell|mention|ask)' \
  --exclude-dir=.git . 2>/dev/null | head -80 ) > "$REPORTS/red-flags.txt"

echo "SKILL-CHECK"
echo "source:     $SRC"
[ -f "$REPORTS/source.txt" ] && echo "revision:   $(cat "$REPORTS/source.txt")"
echo "files:      $(wc -l < "$REPORTS/files.txt" | tr -d ' ') ($REPORTS/files.txt)"
echo "fetched to: $FETCHED"
echo "skillspector exit $SS  -> $REPORTS/skillspector.json (log: skillspector.log)"
echo "cisco        exit $CS  -> $REPORTS/cisco.json (log: cisco.log)"
echo "pattern hits: $(wc -l < "$REPORTS/red-flags.txt" | tr -d ' ') -> $REPORTS/red-flags.txt"
exit 0
