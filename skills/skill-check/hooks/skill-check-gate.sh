#!/usr/bin/env bash
# Claude Code PreToolUse hook (Bash): stop `skills add/update/check` (check installs updates too) until the skill has been checked.
# Lets the command through when it carries SKILL_CHECKED=1 (added after skill-check ran and the user
# said yes) or when it only lists (--list / -l).
cmd="$(jq -r '.tool_input.command // empty')"
printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]_-])skills(@[^[:space:]]+)?[[:space:]]+(add|a|update|upgrade|check|install|i|experimental_install|experimental_sync)([[:space:]]|$)' || exit 0
printf '%s' "$cmd" | grep -Eq 'SKILL_CHECKED=1|(^|[[:space:]])(--list|-l)([[:space:]]|$)' && exit 0
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
jq -n --arg script "$here/../scripts/check_skill.sh" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
  permissionDecisionReason: ("skill-check gate: this installs or updates an agent skill. First run the skill-check skill on the exact source (bash " + $script + " <source>), report the verdict to the user, and wait for a clear yes. Then re-run the same command prefixed with SKILL_CHECKED=1 (e.g. SKILL_CHECKED=1 npx skills add owner/repo).")}}'
