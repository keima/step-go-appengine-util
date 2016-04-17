#!/usr/bin/env bash

readonly GAE_VERSION_LOG_FILE="$WERCKER_CACHE_DIR/go_appengine_version"
readonly GAE_SDK_PATH="$WERCKER_CACHE_DIR/go_appengine"
readonly GAE_LOG_TIMESTAMP=1
readonly GAE_LOG_VERSION=2

readonly GAE_GOPATH="$WERCKER_CACHE_DIR/gopath"

readonly UNZIPPER=7z # unzip
readonly UNZIPPER_OPTION="x" # "-q -o"
readonly UNZIPPER_PKG_APT=p7zip-full
readonly UNZIPPER_PKG_YUM=p7zip

# get string at file's spefified line number
# singleline FILE LINE_NUM
#   singleline hoge 5 -> (line 5 at hoge) and return (head and tail return val)
#   singleline hoge five -> "" and return 1
#   singleline NOT_EXIST 5 -> "" and return 1
#   singleline hoge 99999(not exist line) -> "" and return 0
singleline() {
    # argument check
    expr "$2" + 1 >/dev/null 2>&1
    if [ $? -ge 2 ]; then
        echo ""; return 1
    fi

    if [ ! -e $1 ]; then
        echo ""; return 1
    fi

    # logic
    head -$2 $1 | tail -1
}

# check semver
#   semverlte 1.2.3 1.2.4 -> true
#   semverlte 1.2.3 1.2.3 -> true
#   semverlte 1.2.4 1.2.3 -> false
# @see http://stackoverflow.com/a/4024263
semverlte() {
    [ "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

##########

deprecation_check() {
    if [ ! -z ${WERCKER_GO_APPENGINE_UTIL_TARGET_DIRECTORY} ]; then
        warn "`target-directory` attr is deprecated since ver.0.1.0.\n"\
         "Please use `cwd` attr (wercker-builtin) instead.\n"\
         "(This attr will removed for ver.1.0.0.)"

        cd ${WERCKER_GO_APPENGINE_UTIL_TARGET_DIRECTORY}
    fi
}

setup_gopath() {
    local _GOPATH=""

    if [ ! -d ${GAE_GOPATH} ]; then
        mkdir ${GAE_GOPATH}
    fi
    _GOPATH=${GAE_GOPATH}

    if [ ! -z ${WERCKER_GO_APPENGINE_UTIL_GOPATH} ]; then
        _GOPATH=${WERCKER_GO_APPENGINE_UTIL_GOPATH}:${_GOPATH}
    fi

    export GOPATH=${_GOPATH}
}

install_deps_if_needed() {
  if hash ${UNZIPPER} ; then
    return 0
  else
    debug "$UNZIPPER is not found."

    if hash apt-get ; then
      sudo apt-get update; sudo apt-get install ${UNZIPPER_PKG_APT} -y
    elif hash yum ; then
      sudo yum install ${UNZIPPER_PKG_YUM} -y
    else
      fail "Not found neither suitable package manager nor $UNZIPPER."
    fi

    if hash ${UNZIPPER} ; then
      return 0
    else
      debug "$UNZIPPER is not found."
      return 1
    fi
  fi
}

check_update() {
  if [ -z ${LATEST} ]; then
    local LAST_MODIFIED=`singleline ${GAE_VERSION_LOG_FILE} ${GAE_LOG_TIMESTAMP}`
    local CURRENT_TIME=$(date +"%s")
    local readonly APPEND_TIME=604800 # 7 * 24 * 60 * 60

    debug "lastModified: $LAST_MODIFIED / currentTime: $CURRENT_TIME"

    if [ -z ${LAST_MODIFIED} ] || [ ${CURRENT_TIME} -gt $(( $LAST_MODIFIED + $APPEND_TIME )) ]; then
      LATEST=$(curl https://appengine.google.com/api/updatecheck | grep release | grep -Eo '[0-9\.]+')
    else
      LATEST=`singleline ${GAE_VERSION_LOG_FILE} ${GAE_LOG_VERSION}`
    fi
  fi

  echo "latest: $LATEST"

  [ ! -z ${LATEST} ]
}

# sdk_filename 1.2.3 -> "go_appengine_sdk_linux_amd64-1.2.3.zip"
sdk_filename() {
    echo "go_appengine_sdk_linux_amd64-$1.zip"
}

do_download() {
    cd ${WERCKER_CACHE_DIR}

    local FILE=`sdk_filename ${LATEST}`

    debug "Download $FILE ..."

    curl -O https://storage.googleapis.com/appengine-sdks/featured/${FILE}
    if [ $? -ne 0 ] ; then
      fail "curl error"
    fi

    cd -
}

do_install() {
    cd ${WERCKER_CACHE_DIR}

    if [ -d ${GAE_SDK_PATH} ]; then
        debug "Removing old sdk dir"
        rm -rf ${GAE_SDK_PATH}
    fi

    local FILE=`sdk_filename ${LATEST}`

    debug "Extracting $FILE ..."
    ${UNZIPPER} ${UNZIPPER_OPTION} ${FILE} > /dev/null
    if [ $? -ne 0 ] ; then
      fail "$UNZIPPER error"
    fi

    cd -
}

do_upgrade() {
    if [ -z ${LATEST} ] ; then
        fail "\$LATEST is empty"
    fi

    do_download
    # do_install は fetch_sdk_if_needed で行う

    # write update log
    cd ${WERCKER_CACHE_DIR}
    local CURRENT_TIME=$(date +"%s")
    echo -e "$CURRENT_TIME\n$LATEST" > ${GAE_VERSION_LOG_FILE}

    cd -
}

# fetch GAE/Go SDKs if needed
fetch_sdk_if_needed() {

  if ! check_update ; then
    warn "check_update is failed. Probably using in-cache SDK."
  fi

  if [ -f "$GAE_SDK_PATH/appcfg.py" ]; then
    debug "appcfg.py found in cache"

    VERSION_CACHE=`singleline ${GAE_VERSION_LOG_FILE} ${GAE_LOG_VERSION}`
    if [ ! -z ${VERSION_CACHE} ] && ! semverlte ${LATEST} ${VERSION_CACHE}; then
      info "go-appengine sdk ver. $LATEST is available. It's time to update!"
      do_upgrade
    fi
  else
    do_upgrade
  fi

  do_install
}

deprecation_check

if ! install_deps_if_needed ; then
  # if failed , show message and exit
  fail "[install_deps_if_needed] failed. Show output log."
fi

fetch_sdk_if_needed

debug 'Set $PATH and $GOPATH'
export PATH="$GAE_SDK_PATH":$PATH
setup_gopath


case ${WERCKER_GO_APPENGINE_UTIL_METHOD} in
  deploy)
    info "goapp deploy"
    ${GAE_SDK_PATH}/appcfg.py update ./ --oauth2_refresh_token="$WERCKER_GO_APPENGINE_UTIL_TOKEN"
    ;;
  get)
    info "goapp get"
    goapp get -d
    ;;
  test)
    info "goapp test"
    goapp test
    ;;
  build)
    info "goapp build"
    goapp build
    ;;
  *)
    fail "Unknown parameter: $WERCKER_GO_APPENGINE_UTIL_METHOD"
esac

if [ $? -eq 0 ]; then
    success "$WERCKER_GO_APPENGINE_UTIL_METHOD is Finished. :)"
else
    fail "$WERCKER_GO_APPENGINE_UTIL_METHOD failed... :("
fi
