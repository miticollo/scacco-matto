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
  ./autogen.sh --disable-silent-rules
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
# Compiles gaster for futurerestore.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function compile_gaster_fr() {
  cd gaster-futurerestore
  make macos -j"$(sysctl -n hw.ncpu)"
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
# Compiles termz.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function compile_termz() {
  cd termz
  make -j"$(sysctl -n hw.ncpu)"
  cd -
}

#######################################
# Compiles pongoterm.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function compile_pongoterm() {
  cd PongoOS/scripts
  make -j"$(sysctl -n hw.ncpu)" pongoterm
  cd -
}

#######################################
# Compiles libplist.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function compile_libplist() {
  cd libplist
  ./autogen.sh --disable-silent-rules
  make -j"$(sysctl -n hw.ncpu)"
  cd -
}

#######################################
# Compiles libimobiledevice-glue.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function compile_libimobiledevice-glue() {
  cd libimobiledevice-glue
  libplist_LIBS="-L$(eval "${WORKING_DIR}")/libplist/src/.libs -lplist-2.0" libplist_CFLAGS="-I$(eval "${WORKING_DIR}")/libplist/include/plist" ./autogen.sh --disable-silent-rules
  make -j"$(sysctl -n hw.ncpu)"
  cd -
}

#######################################
# Compiles libimobiledevice.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function compile_libimobiledevice() {
  cd libimobiledevice

  # https://docs.brew.sh/How-to-Build-Software-Outside-Homebrew-with-Homebrew-keg-only-Dependencies#pkg-config-detection
  PKG_CONFIG_PATH="$(brew --prefix)/opt/openssl/lib/pkgconfig"
  export PKG_CONFIG_PATH
  ./autogen.sh --disable-silent-rules
  make -j"$(sysctl -n hw.ncpu)"
  cd -
}

#######################################
# Compiles libusbmuxd.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function compile_libusbmuxd() {
  cd libusbmuxd
  # based on ../libplist/src/libplist-2.0.pc
  ./autogen.sh --disable-silent-rules
  make -j"$(sysctl -n hw.ncpu)"
  cd -
}

#######################################
# Compiles ibootim.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function compile_ibootim() {
  cd ibootim
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
  chmod -v +x ./iBoot64Patcher
  set +e
  xattr -d com.apple.quarantine ./iBoot64Patcher
  set -e
}

#######################################
# Downloads futurestore.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function get_futurerestore() {
  curl -LO https://nightly.link/miticollo/futurerestore/actions/runs/4580365432/futurerestore-macOS-DEBUG.zip
  unzip -p futurerestore-macOS-DEBUG.zip | tar -xv
  rm -v futurerestore*.zip
  chmod -v +x ./futurerestore
  set +e
  xattr -d com.apple.quarantine ./futurerestore
  set -e
}

#######################################
# Set executable bits for img4tool.
# Arguments:
#   None
# Outputs:
#   0 without errors, non-zero otherwise.
#######################################
function executable_img4tool() {
  chmod -v +x ./img4tool
  set +e
  xattr -d com.apple.quarantine ./img4tool
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
  python -m pip install --upgrade pip git+https://github.com/m1stadev/PyIMG4.git@master frida-tools frida git+https://github.com/doronz88/pymobiledevice3.git@master
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

  if [[ "$OSTYPE" != "darwin"* ]]; then
    err "${OSTYPE} not supported. Aborted."
    exit 1
  fi

  if ! which -s curl; then
    err "cURL missing. Aborted."
    exit 1
  fi

  if ! which -s git; then
    err "git missing. Aborted."
    exit 1
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    err "python3 missing. Aborted."
    exit 1
  fi

  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

  pushd "${WORKING_DIR}" || { err "WORKING_DIR not found. Exited."; exit 1; }

  compile_libplist
  compile_libimobiledevice-glue
  compile_irecovery
  compile_libusbmuxd
  compile_libimobiledevice
  create_env
  compile_gaster
  compile_gaster_fr
  compile_t8015_bootkit
  compile_ibootim
  compile_kpf
  compile_pongoterm
  get_iboot64patcher
  get_futurerestore
  compile_termz
  executable_img4tool

  # Ignore errors
  popd || true
}

main "$@"
