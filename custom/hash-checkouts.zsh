# shellcheck disable=SC2034
typeset -a projects

_hasKey() {
   local var="${1}[$2]"
   echo "testing ${var}"
   (( ${(P)+${var}} )) && return 0
   return 1
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
  cache=${XDG_CACHE_HOME:-$HOME/.cache}/.zsh-hashes
  if [ -f "${cache}" ]; then
    while IFS="" read -r p || [ -n "$p" ]; do
      hash -d "$p"
      projects+=("$p")
    done <"${cache}"
  fi
  gfind "${HOME}"/development -maxdepth 1 -mindepth 1 -type d -printf "%f\0"  \
   | while IFS= read -r -d '' file; do \
    _hasKey projects "$file" || _buildHash "$file" ; done
  #Replace the cache with any updates we have added
  hash -d >"${cache}"
}
