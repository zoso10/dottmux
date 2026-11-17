#!/usr/bin/env bash

# Start and finish tasks, each in its own git worktree and tmux window.
#
#   usage: task.sh new <branch> [--from <ref>]
#          task.sh done [--force]
#
# Run from anywhere inside the repo, main checkout or a task worktree.
#
#   new   Creates a worktree for <branch> in <repo>/.claude/worktrees/, opens a
#         window there named after the branch's last segment, and starts
#         claude. Existing local or remote branches are checked out; a new
#         branch starts from the main checkout's HEAD unless --from is given.
#         If the worktree already exists, only the window is opened.
#   done  Removes the worktree you are in and closes its window. The branch is
#         kept. Refuses if there are uncommitted changes or commits that are
#         not on a remote or the main checkout's branch, unless --force.

set -euo pipefail

die() {
  echo "task: $*" >&2
  exit 1
}

main_checkout() {
  local common
  common="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" ||
    die "$PWD is not in a git repository"
  dirname "$common"
}

cmd_new() {
  local name="" from=""
  while (($#)); do
    case "$1" in
      --from) from="${2:?--from needs a ref}"; shift 2 ;;
      -*) die "unknown option $1" ;;
      *) [[ -z "$name" ]] || die "only one branch name"; name="$1"; shift ;;
    esac
  done
  [[ -n "$name" ]] || die "usage: task.sh new <branch> [--from <ref>]"
  git check-ref-format --branch "$name" > /dev/null 2>&1 || die "'$name' is not a valid branch name"

  local main path window
  main="$(main_checkout)"
  path="${main}/.claude/worktrees/${name//\//-}"
  window="${name##*/}"

  # keep task worktrees out of the main checkout's git status
  if ! git -C "$main" check-ignore -q .claude/worktrees/x; then
    echo ".claude/worktrees/" >> "$(git -C "$main" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
  fi

  if [[ -e "$path" ]]; then
    git -C "$path" rev-parse --is-inside-work-tree > /dev/null 2>&1 || die "$path exists and is not a worktree"
  elif git -C "$main" show-ref --verify --quiet "refs/heads/${name}"; then
    git -C "$main" worktree add --quiet "$path" "$name"
  elif git -C "$main" show-ref --verify --quiet "refs/remotes/origin/${name}"; then
    git -C "$main" worktree add --quiet --track -b "$name" "$path" "origin/${name}"
  else
    git -C "$main" worktree add --quiet -b "$name" "$path" "${from:-HEAD}"
  fi

  [[ -n "${TMUX:-}" ]] || { echo "worktree at $path (not in tmux, no window opened)"; return; }

  # start claude from a shell so the window survives claude exiting
  local id
  id="$(tmux new-window -P -F '#{window_id}' -n "$window" -c "$path")"
  tmux send-keys -t "$id" claude Enter
}

cmd_done() {
  local force=""
  case "${1:-}" in
    "") ;;
    --force) force=1 ;;
    *) die "usage: task.sh done [--force]" ;;
  esac

  local main top
  main="$(main_checkout)"
  top="$(git rev-parse --show-toplevel)"
  [[ "$top" == "${main}/.claude/worktrees/"* ]] || die "not in a task worktree ($top)"

  if [[ -z "$force" ]]; then
    [[ -z "$(git -C "$top" status --porcelain)" ]] ||
      die "uncommitted changes in $top (task.sh done --force to discard)"

    local base unpushed
    base="$(git -C "$main" rev-parse HEAD)"
    unpushed="$(git -C "$top" rev-list --count HEAD --not --remotes "$base")"
    [[ "$unpushed" == 0 ]] ||
      die "$unpushed commit(s) not pushed or merged (task.sh done --force to drop the worktree anyway)"
  fi

  # find the windows that live entirely inside this worktree before it goes away
  local windows
  windows=""
  if [[ -n "${TMUX:-}" ]]; then
    windows="$(tmux list-panes -a -F $'#{window_id}\t#{pane_current_path}' |
      awk -F'\t' -v top="$top" '
        { inside = ($2 == top || index($2, top "/") == 1) }
        !($1 in all) { all[$1] = 1; order[++n] = $1 }
        !inside { out[$1] = 1 }
        END { for (i = 1; i <= n; i++) if (!(order[i] in out)) print order[i] }
      ')"
  fi

  cd "$main"
  git worktree remove ${force:+--force} "$top"

  # last, since this script may be running in one of them
  local id
  for id in $windows; do
    tmux kill-window -t "$id"
  done
}

case "${1:-}" in
  new) shift; cmd_new "$@" ;;
  done) shift; cmd_done "$@" ;;
  *) die "usage: task.sh <new|done> ..." ;;
esac
