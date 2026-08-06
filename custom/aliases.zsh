alias kerb='kinit -t ~/.kerberos.sbarker.keytab -k sbarker@REDHAT.COM'
alias dropMerged='git branch --merged | egrep -v "(^\*|master|main|dev)" | xargs git branch -d'
alias bundleUpdate='antibody bundle < ${MY_PROFILE:-$HOME}/zsh_plugins.txt > ${MY_PROFILE:-$HOME}/zsh_plugins.zsh'
alias gls='gls --hyperlink=auto --color=tty'
alias mci='mvn clean install'
alias mcb='mvn clean install -Dqucik'

_git_has_upstream() {
  git remote get-url upstream &>/dev/null
}

updateFork() {
  local main_branch
  main_branch=$(git_main_branch)
  git fetch upstream "${main_branch}"
  if [[ $(git_current_branch) == "${main_branch}" ]]; then
    git rebase "upstream/${main_branch}"
  else
    local worktree_path
    worktree_path=$(git worktree list --porcelain \
      | awk '/^worktree /{wt=$2} /^branch refs\/heads\/'"${main_branch}"'/{print wt}')
    if [[ -n "${worktree_path}" ]]; then
      git -C "${worktree_path}" merge --ff-only "upstream/${main_branch}"
    else
      git branch -f "${main_branch}" "upstream/${main_branch}"
    fi
  fi
  git fetch origin "${main_branch}"
  git push --force-with-lease origin "upstream/${main_branch}:${main_branch}"
}

_syncOrigin() {
  local main_branch
  main_branch=$(git_main_branch)
  git fetch origin "${main_branch}"
  if [[ $(git_current_branch) == "${main_branch}" ]]; then
    git rebase "origin/${main_branch}"
  else
    local worktree_path
    worktree_path=$(git worktree list --porcelain \
      | awk '/^worktree /{wt=$2} /^branch refs\/heads\/'"${main_branch}"'/{print wt}')
    if [[ -n "${worktree_path}" ]]; then
      git -C "${worktree_path}" merge --ff-only "origin/${main_branch}"
    else
      git branch -f "${main_branch}" "origin/${main_branch}"
    fi
  fi
}

gnb() {
  local main_branch
  main_branch=$(git_main_branch)
  if _git_has_upstream; then
    updateFork && git checkout -b "$1" "upstream/${main_branch}"
  else
    _syncOrigin && git checkout -b "$1" "origin/${main_branch}"
  fi \
    && git push -u origin "$1"
}

_minikubeLoadImage() {
  local module="$1" tarPath="$2"
  mci -P dist -DskipTests -pl "${module}" -DskipDocs=true -Dquick -DwithAdditionalFilters=true \
    && gunzip --to-stdout "${tarPath}" | minikube image load - --alsologtostderr=true 2>&1 | tail -n1
}

minikubeloadproxy() {
  _minikubeLoadImage :kroxylicious-app kroxylicious-app/target/kroxylicious-proxy.img.tar.gz
}

minikubeloadoperator() {
  _minikubeLoadImage :kroxylicious-operator kroxylicious-kubernetes/kroxylicious-operator/target/kroxylicious-operator.img.tar.gz
}
