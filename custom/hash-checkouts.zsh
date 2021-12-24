# shellcheck disable=SC2034
typeset -A projects

_hasKey() {
   local var="${1}[$2]"
   (( ${(P)+${var}} )) && return 1
   return 0
}

_buildHash() {
  local proj=$1
  if git -C "${HOME}/development/${proj}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      # shellcheck disable=SC2140
      hash -d "${proj}"="${HOME}/development/${proj}"
  fi
}

#Include all git projects in the directory hash table
#Which with AUTO_CD allows jumping to a checkout just by the repo name
hashCheckouts() {
  local cache=${XDG_CACHE_HOME:-$HOME/.cache}/.zsh-hashes
  if [ -f "${cache}" ]; then
    while IFS="" read -r p || [ -n "$p" ]; do
      hash -d "$p"
    done <"${cache}"
  fi
  # shellcheck disable=SC2045
  for proj in $(ls "${HOME}/development/"); do
    _hasKey projects "${proj}" || _buildHash "${proj}"
  done
  #Replace the cache with any updates we have added
  hash -d >"${cache}"
}
