# skill-check

A skill for Claude (and other coding agents) that safety-checks agent skills **before** you install
or update them. It runs two free, open-source scanners, [NVIDIA SkillSpector](https://github.com/NVIDIA/skillspector)
and [Cisco Skill Scanner](https://github.com/cisco-ai-defense/skill-scanner), then has the agent read
the skill for what scanners miss and explain the verdict in plain language: ✅ looks safe,
⚠️ caution, or ⛔ don't install. Nothing is installed without your OK.

## Install

```bash
npx skills add rembertoius-dot/skill-check
```

Then ask your agent to install a skill as usual ("install this skill: owner/repo"), send it a
GitHub link, or ask "is this skill safe?". It also works for auditing the skills you already have.

## Make it automatic (Claude Code)

The skill triggers on its own when you ask your agent to install something, but an agent can still
run `npx skills add` directly. To make the check impossible to skip, add this hook to
`~/.claude/settings.json` (merge it into any `hooks` you already have):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "~/.claude/skills/skill-check/hooks/skill-check-gate.sh", "timeout": 10 }]
      }
    ]
  }
}
```

Now any `skills add` or `skills update` the agent tries is stopped until it has run the check, shown
you the verdict, and you've said yes. Listing (`--list`) is never blocked. It needs `jq`
(`brew install jq`). If you installed the skill somewhere else, point `command` at that folder's
`hooks/skill-check-gate.sh`.

## Why

Skills run with your agent's full permissions: files, terminal, logged-in accounts. Studies of public
skill marketplaces found about a quarter of skills have at least one vulnerability. The scanners are
great but noisy: pattern matching flags honest setup scripts as "critical". skill-check has the agent
check every flagged line in context, so you get a verdict you can act on.

## Requirements

Python 3.10+ and git. The scanners are installed once into `~/.skill-check/venv` on first use.

## License

MIT. The scanners it installs are Apache 2.0 (NVIDIA, Cisco).
