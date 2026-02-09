#!/usr/bin/env bash

CONNECTED_VPN=$(osascript -e 'tell application "Tunnelblick" to get name of configurations where state = "CONNECTED"')

if [[ -n ${CONNECTED_VPN} ]]; then
  # VPN is connected - run your command
  echo "RH Global connected $(date)" >> ~/.vpn-connect.log
  kinit --keychain sbarker@IPA.REDHAT.COM
fi

exit 0
