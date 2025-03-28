# shellcheck disable=SC2034
typeset -a projects

OS=$(uname)
_search_paths=("${HOME}/src" "${HOME}/src/strimzi" "${HOME}/src/kroxy" "${HOME}/src/kroxylicious" "${HOME}/src/flink")

_findCommand() {
  if [ "$OS" = 'Darwin' ]; then
    # for MacOS
    echo "$(command -v gfind)"
  else
    # for Linux and Windows
    echo "$(command -v find)"
  fi
}

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
  local fnd search_dir=$1
  fnd="$(_findCommand)"
  if [ -d "${search_dir}" ]; then
    echo "checking ${search_dir} using ${fnd}"
    ${fnd} "${search_dir}" -maxdepth 1 -mindepth 1 -type d -printf "%f\n"  \
    | while IFS='' read -r file; do \
      _hasKey projects "$file" || _buildHash "${search_dir}" "${file}" ; done
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
  for p in "${_search_paths[@]}"; do
    if [[ -r "${p}" ]]; then
      _findCheckouts "${p}"
    fi
  done

  #Replace the cache with any updates we have added
  hash -d >"${cache}"
}
