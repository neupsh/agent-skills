#!/usr/bin/env bash
# Symlink skills from the skill-only plugins into ~/.claude/skills so they load
# under bare names (e.g. `tech-lead`) in every Claude Code session.
#
# Usage: ./install.sh [--remove]
#
# WHEN TO USE THIS vs. `/plugin install`
#   Plugin install is the normal path and namespaces skills as `<plugin>:<skill>`.
#   These symlinks load the same skills under bare names instead. Use ONE or the
#   other per plugin — enabling a plugin in settings.json *and* symlinking its
#   skills loads them twice.
#
#   design-system and safety-hooks ship assets/hooks and are installed as plugins;
#   they are deliberately NOT handled here.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DST="$HOME/.claude/skills"

# Plugins whose skills are linked under bare names.
PLUGINS=(engineering-skills personal-ops)

mkdir -p "$SKILLS_DST"

for plugin in "${PLUGINS[@]}"; do
  src_root="$REPO_DIR/$plugin/skills"
  [[ -d "$src_root" ]] || { echo "SKIP     no skills/ in $plugin" >&2; continue; }

  for dir in "$src_root"/*/; do
    [[ -d "$dir" ]] || continue
    name="$(basename "$dir")"
    link="$SKILLS_DST/$name"

    if [[ "${1:-}" == "--remove" ]]; then
      if [[ -L "$link" ]]; then
        rm "$link"
        echo "removed  $link"
      fi
      continue
    fi

    # Never clobber a real directory — only ever manage symlinks.
    if [[ -e "$link" && ! -L "$link" ]]; then
      echo "SKIP     $link exists and is not a symlink (won't overwrite)" >&2
      continue
    fi

    ln -sfn "${dir%/}" "$link"
    echo "linked   $link -> ${dir%/}"
  done
done
