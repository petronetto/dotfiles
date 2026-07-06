#!/usr/bin/env zsh

export DISABLE_TELEMETRY=true

# The `universal`/`amp`/`replit` agents hardcode their global skills path to
# ~/.agents/skills (see isUniversalAgent()/getCanonicalSkillsDir() in
# vercel-labs/skills' cli.mjs) — XDG_CONFIG_HOME has no effect on it. The
# CLI also tracks a global lock file at ~/.agents/.skill-lock.json (unless
# XDG_STATE_HOME is set). We run the CLI inside a throwaway `node`
# container with the chezmoi source tree bind-mounted directly at
# /root/.agents/skills, and the lock file bind-mounted alongside it at
# /root/.agents/.skill-lock.json, so both the skills and their lock file
# are written straight into version control. No host env vars, no rsync
# mirror, no `chezmoi` binary calls.
typeset -g SKILLS_SYNC_SOURCE_DIR="${HOME}/.local/share/chezmoi/dot_config/agents/skills"
typeset -g SKILLS_SYNC_LOCK_FILE="${HOME}/.local/share/chezmoi/dot_config/agents/.skill-lock.json"
typeset -g SKILLS_SYNC_LIVE_DIR="${HOME}/.config/agents/skills"
typeset -g SKILLS_SYNC_DOCKER_IMAGE="node:lts"

_skills_sync_help() {
	cat <<-EOF
	Usage: skills-sync <command> [args...]

	Wrapper around \`npx skills\` (global, universal agent) that runs the
	CLI inside a $SKILLS_SYNC_DOCKER_IMAGE container with the chezmoi
	source tree ($SKILLS_SYNC_SOURCE_DIR) bind-mounted at the container's
	~/.agents/skills, and the global lock file ($SKILLS_SYNC_LOCK_FILE)
	bind-mounted at ~/.agents/.skill-lock.json, so add/update/remove write
	directly into version control. No host env vars, rsync, or \`chezmoi\`
	commands are involved; applying to $SKILLS_SYNC_LIVE_DIR
	(e.g. \`chezmoi apply\`) is left to you.

	Commands:
	  add <args...>     Install a skill (forces -g --agent universal)
	  update <args...>  Update installed skill(s) (forces -g --agent universal)
	  remove <args...>  Remove a skill (forces -g --agent universal)
	  list <args...>    List installed skills (forces -g --agent universal)
	  prune             Delete every skill from $SKILLS_SYNC_LIVE_DIR
	  help              Show this help
	  <anything else>   Passed through to \`npx skills\` in the container

	Examples:
	  skills-sync add vercel-labs/agent-skills --skill web-design-guidelines
	  skills-sync list
	  skills-sync remove my-skill
	  skills-sync prune
	EOF
}

# Runs `npx skills <args>` inside a throwaway node container, with the
# chezmoi source tree mounted at the container's canonical universal-agent
# skills path (~/.agents/skills), and the global lock file mounted
# alongside it (~/.agents/.skill-lock.json).
_skills_sync_docker_run() {
	mkdir -p "$SKILLS_SYNC_SOURCE_DIR"
	[[ -f "$SKILLS_SYNC_LOCK_FILE" ]] || : >"$SKILLS_SYNC_LOCK_FILE"

	local -a tty_flags
	[[ -t 0 && -t 1 ]] && tty_flags=(-it)

	docker run --rm "${tty_flags[@]}" \
		-v "${SKILLS_SYNC_SOURCE_DIR}:/root/.agents/skills" \
		-v "${SKILLS_SYNC_LOCK_FILE}:/root/.agents/.skill-lock.json" \
		"$SKILLS_SYNC_DOCKER_IMAGE" \
		npx --yes skills "$@"
}

# Wipes every installed skill from the live ~/.config/agents/skills dir.
_skills_sync_prune() {
	rm -rf "${SKILLS_SYNC_LIVE_DIR:?}"/*(N)
}

# Wrapper around `npx skills` that installs/updates/removes/lists skills
# directly into the chezmoi source tree via a dockerized CLI run.
skills-sync() {
	local subcommand=${1:-help}
	(($# > 0)) && shift

	case "$subcommand" in
	add | update | remove | list)
		_skills_sync_docker_run "$subcommand" "$@" -g --agent universal
		;;
	prune)
		_skills_sync_prune
		;;
	help | -h | --help)
		_skills_sync_help
		;;
	*)
		_skills_sync_docker_run "$subcommand" "$@"
		;;
	esac
}
