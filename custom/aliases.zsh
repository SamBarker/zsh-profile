alias kerb='kinit -t ~/.kerberos.sbarker.keytab -k sbarker@REDHAT.COM'
alias dropMerged='git branch --merged | egrep -v "(^\*|master|main|dev)" | xargs git branch -d'
alias bundleUpdate='antibody bundle < ${MY_PROFILE:-$HOME}/zsh_plugins.txt > ${MY_PROFILE:-$HOME}/zsh_plugins.zsh'
alias gls='gls --hyperlink=auto --color=tty'
alias mci='mvn clean install'
alias updateFork='BRANCH_NAME=${$(git symbolic-ref -q HEAD)##refs/heads/}; gco main && grhh && gf upstream && grb upstream/main && gpf! && gco ${BRANCH_NAME}' #checkout main which tracks origin/main make sure its reset. Fetch & rebase to the latest upstream/main and push that up to my fork

source "${HOME}/.config/op/plugins.sh"