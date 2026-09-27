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

## Why

Skills run with your agent's full permissions: files, terminal, logged-in accounts. Studies of public
skill marketplaces found about a quarter of skills have at least one vulnerability. The scanners are
great but noisy: pattern matching flags honest setup scripts as "critical". skill-check has the agent
check every flagged line in context, so you get a verdict you can act on.

## Requirements

Python 3.10+ and git. The scanners are installed once into `~/.skill-check/venv` on first use.

## License

MIT. The scanners it installs are Apache 2.0 (NVIDIA, Cisco).
