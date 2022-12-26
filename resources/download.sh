#!/usr/bin/env bash

set -e

readonly WORKING_DIR="$(dirname "$(readlink -f "${0}")")"

function err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

#######################################
# Entry point.
# Globals:
#   WORKING_DIR
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function main() {
  pushd "${WORKING_DIR}" || { err "WORKING_DIR not found. Exited."; exit 1; }

  curl -LO https://github.com/palera1n/loader/raw/main/palera1nLoader/Required/bootstrap.tar
  curl -LO https://cdn.discordapp.com/attachments/1028398976640229380/1043815743269126225/resigner.sh
  curl -LO https://apt.bingner.com/debs/1443.00/com.ex.substitute_2.3.1_iphoneos-arm.deb
  curl -LO https://apt.bingner.com/debs/1443.00/com.saurik.substrate.safemode_0.9.6005_iphoneos-arm.deb
  curl -LO http://apt.thebigboss.org/repofiles/cydia/debs2.0/preferenceloader_2.2.6.deb

  # Ignore errors
  popd || true
}

main "$@"
