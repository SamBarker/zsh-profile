OS=$(uname)

# Root under which all my git checkouts live. Repos may sit directly under it
# or be nested one/two levels down inside grouping folders (strimzi, kroxy, …).
_search_root="${HOME}/src"

# How deep to search. Repos nested inside grouping folders live at depth 2+.
# Override for a one-off deeper/shallower scan: HASH_CHECKOUTS_DEPTH=4 hashCheckouts
_hash_checkouts_depth="${HASH_CHECKOUTS_DEPTH:-3}"

_findCommand() {
  # GNU find is required for -printf. On macOS that's gfind (brew coreutils/findutils).
  if [ "$OS" = 'Darwin' ]; then
    command -v gfind
  else
    command -v find
  fi
}

# Register every git checkout under $_search_root in the directory hash table
# (repo-name -> path). With AUTO_CD this lets you `cd` to a repo by its bare
# name from anywhere. Safe to re-run any time — e.g. after cloning a new repo,
# just type `hashCheckouts` to pick it up in the current session.
hashCheckouts() {
  local find_cmd
  find_cmd="$(_findCommand)"

  [ -d "${_search_root}" ] || return 0

  # Locate every .git entry and take its parent dir (%h) as the repo root.
  # -prune stops find descending into .git itself. This also matches git
  # worktrees, where .git is a file rather than a directory.
  local find_output
  find_output="$(
    "${find_cmd}" "${_search_root}" \
      -maxdepth "${_hash_checkouts_depth}" \
      -name .git -prune -printf '%h\n' 2>/dev/null
  )"

  # Split the newline-separated output into an array. The (f) flag splits on
  # newlines; @ inside double quotes keeps each line a separate element even
  # if a path contains spaces.
  local -a repo_paths
  repo_paths=( "${(@f)find_output}" )

  # Drop any duplicate paths (u = unique).
  repo_paths=( "${(@u)repo_paths}" )

  local repo_path repo_name
  for repo_path in "${repo_paths[@]}"; do
    [ -n "${repo_path}" ] || continue   # skip the empty element when nothing matched
    repo_name="${repo_path:t}"          # :t = tail, i.e. the basename
    hash -d -- "${repo_name}=${repo_path}"
  done
}
