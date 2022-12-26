#!/usr/bin/env bash

set -e

readonly WORKING_DIR="$(dirname "$(readlink -f "${0}")")"

function err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

#######################################
# Compiles irecovery.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function compile_irecovery() {
  cd libirecovery
  ./autogen.sh
  make -j"$(sysctl -n hw.ncpu)"
  cd -
}

#######################################
# Compiles gaster.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function compile_gaster() {
  cd gaster
  make macos -j"$(sysctl -n hw.ncpu)"
  cp ./gaster ../SSHRD_Script/Darwin
  cd -
}

#######################################
# Compiles t8015_bootkit.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function compile_t8015_bootkit() {
  cd t8015_bootkit
  make -j"$(sysctl -n hw.ncpu)"
  cd -
}

#######################################
# Compiles KPF.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function compile_kpf() {
  cd PongoOS/checkra1n/Kernel15Patcher/
  make -j"$(sysctl -n hw.ncpu)"
  cd -
}

#######################################
# Downloads iBoot64Patcher.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function get_iboot64patcher() {
  curl -LO https://nightly.link/Cryptiiiic/iBoot64Patcher/workflows/ci/main/iBoot64Patcher-macOS-x86_64-DEBUG.zip
  unzip -p iBoot64Patcher-macOS-x86_64-DEBUG.zip | tar -xv
  rm -v iBoot64Patcher*.zip
  chmod +x ./iBoot64Patcher
  set +e
  xattr -d com.apple.quarantine ./iBoot64Patcher
  set -e
}

#######################################
# Create Python Virtual Environments.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function create_env() {
  cd ..
  python3 -m venv ./.venv/
  source ./.venv/bin/activate
  python -m pip install --upgrade pip
  python -m pip install git+https://github.com/m1stadev/PyIMG4.git@master
  cd -
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
  if ! which -s curl; then
    err "cURL missing. Aborted."
    exit 1
  fi

  if ! which -s git; then
    err "git missing. Aborted."
    exit 1
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    err "git missing. Aborted."
    exit 1
  fi

  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

  pushd "${WORKING_DIR}" || { err "WORKING_DIR not found. Exited."; exit 1; }

  compile_irecovery
  compile_gaster
  compile_t8015_bootkit
  compile_kpf
  get_iboot64patcher
  create_env

  # Ignore errors
  popd || true
}

main "$@"
