# shellcheck disable=SC2034
typeset -a projects

OS=$(uname)

if [ "$OS" = 'Darwin' ]; then
  # for MacOS
  FIND=$(command -v gfind)
else
  # for Linux and Windows
  FIND=$(which find)
fi

_hasKey() {
  local var="${1}[$2]"
  (( ${(P)+${var}} )) && return 0
  return 1
}

_buildHash() {
  local projects_dir=$1
  local proj=$2
  if git -C "${projects_dir}/${proj}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      hash -d "${proj}=${projects_dir}/${proj}"
  fi
}

_findCheckouts() {
  local search_dir=$1

  [ -d "${search_dir}" ] && ${FIND} "${search_dir}" -maxdepth 1 -mindepth 1 -type d -printf "%f\0"  \
    | while IFS= read -r -d '' file; do \
      _hasKey projects "$file" || _buildHash "${search_dir}" "${file}" ; done
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

  _findCheckouts "${HOME}/src"
  _findCheckouts "${HOME}/src/strimzi"
  _findCheckouts "${HOME}/src/kroxy"
  _findCheckouts "${HOME}/src/kroxylicious"
  _findCheckouts "${HOME}/src/flink"

  #Replace the cache with any updates we have added
  hash -d >"${cache}"
}
