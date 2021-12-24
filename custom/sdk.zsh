loadSdkMan() {
  #THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
  [[ -s "${HOME}/.sdkman/bin/sdkman-init.sh" ]] && source "${HOME}/.sdkman/bin/sdkman-init.sh"
}

sdk() {
  local currentSdk
  currentSdk=$(whence -v sdk)
  set +x
  if [[ "${currentSdk}" != '*.sdkman-main.sh' ]]; then
    #unload this definition of sdk to load the real one from SDKMAN
    unfunction sdk && loadSdkMan
  fi
  set -x
}
