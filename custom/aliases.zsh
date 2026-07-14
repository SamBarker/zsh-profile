alias kerb='kinit -t ~/.kerberos.sbarker.keytab -k sbarker@REDHAT.COM'
alias dropMerged='git branch --merged | egrep -v "(^\*|master|main|dev)" | xargs git branch -d'
alias bundleUpdate='antibody bundle < ${MY_PROFILE:-$HOME}/zsh_plugins.txt > ${MY_PROFILE:-$HOME}/zsh_plugins.zsh'
alias gls='gls --hyperlink=auto --color=tty'
alias mci='mvn clean install'
alias mcb='mvn clean install -Dqucik'

updateFork() {
  local main_branch
  main_branch=$(git_main_branch)
  git fetch upstream "${main_branch}"
  if [[ $(git_current_branch) == "${main_branch}" ]]; then
    git rebase "upstream/${main_branch}"   # already on main — rebase in place
  else
    git branch -f "${main_branch}" upstream/"${main_branch}"  # on a feature branch — update main without switching
  fi
  git fetch origin "${main_branch}"  # refresh stale tracking info so --force-with-lease works correctly
  git push --force-with-lease origin "${main_branch}"
}

gnb() {
  updateFork && git checkout -b "$1" "upstream/$(git_main_branch)" && git push -u origin "$1"
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
  _minikubeLoadImage :kroxylicious-operator kroxylicious-operator/target/kroxylicious-operator.img.tar.gz
}
