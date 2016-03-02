#!/usr/bin/env bash

. ./util.sh

readonly GAE_VERSION_LOG_FILE="$WERCKER_CACHE_DIR/go_appengine_version"
readonly GAE_SDK_PATH="$WERCKER_CACHE_DIR/go_appengine"
readonly GAE_LOG_TIMESTAMP=1
readonly GAE_LOG_VERSION=2

readonly GAE_GOPATH="$WERCKER_CACHE_DIR/gopath"

readonly UNZIPPER=7z # unzip
readonly UNZIPPER_OPTION="x" # "-q -o"
readonly UNZIPPER_PKG_APT=p7zip-full
readonly UNZIPPER_PKG_YUM=p7zip

setup_gopath() {
    if [ ! -d $GAE_GOPATH ]; then
        mkdir $GAE_GOPATH
    fi
    export GOPATH=$GAE_GOPATH
}

install_deps_if_needed() {
  if hash $UNZIPPER ; then
    return 0
  else
    debug "$UNZIPPER is not found."

    if hash apt-get ; then
      sudo apt-get update; sudo apt-get install $UNZIPPER_PKG_APT -y
    elif hash yum ; then
      sudo yum install $UNZIPPER_PKG_YUM -y
    else
      fail "Not found neither suitable package manager nor $UNZIPPER."
    fi

    if hash $UNZIPPER ; then
      return 0
    else
      debug "$UNZIPPER is not found."
      return 1
    fi
  fi
}

check_update() {
  if [ -z $LATEST ]; then
    local LAST_MODIFIED=`singleline $GAE_VERSION_LOG_FILE $GAE_LOG_TIMESTAMP`
    local CURRENT_TIME=$(date +"%s")
    local readonly APPEND_TIME=( 7 * 24 * 60 * 60 )

    debug "lastModified: $LAST_MODIFIED / currentTime: $CURRENT_TIME"

    if [ -z $LAST_MODIFIED ] || [ $CURRENT_TIME -gt $(( $LAST_MODIFIED + $APPEND_TIME )) ]; then
      LATEST=$(curl https://appengine.google.com/api/updatecheck | grep release | grep -Eo '[0-9\.]+')
    else
      LATEST=$LAST_MODIFIED
    fi
  fi

  echo "latest: $LATEST"

  [ ! -z $LATEST ]
}

# workaround timestamp messup fix
# @see https://groups.google.com/forum/#!topic/google-appengine-go/rWc4TkhSECk
fix_sdk_timestamp_messup() {
    if [ -d $GAE_SDK_PATH ]; then
        debug "Apply SDK timestamp mess-up..."

        cd $GAE_SDK_PATH/goroot
        find . -name "*.a" -exec touch {} \;
        cd -
    fi
}

# sdk_filename 1.2.3 -> "go_appengine_sdk_linux_amd64-1.2.3.zip"
sdk_filename() {
    echo "go_appengine_sdk_linux_amd64-$1.zip"
}

do_download() {
    local FILE=`sdk_filename $LATEST`

    debug "Download $FILE ..."

    curl -O https://storage.googleapis.com/appengine-sdks/featured/$FILE
    if [ $? -ne 0 ] ; then
      fail "curl error"
    fi
}

do_install() {
    if [ -d $GAE_SDK_PATH ]; then
        debug "Removing old sdk dir"
        rm -rf $GAE_SDK_PATH
    fi

    local FILE=`sdk_filename $LATEST`

    debug "Extracting $FILE ..."
    $UNZIPPER $UNZIPPER_OPTION $FILE > /dev/null
    if [ $? -ne 0 ] ; then
      fail "$UNZIPPER error"
    fi
}

do_upgrade() {
  if [ ! -z $LATEST ] ; then
    cd $WERCKER_CACHE_DIR

    do_download
    # do_install は fetch_sdk_if_needed で行う

    # write update log
    local CURRENT_TIME=$(date +"%s")
    echo -e "$CURRENT_TIME\n$LATEST" > $GAE_VERSION_LOG_FILE

    # debug
    ls -al

  else
    fail "\$LATEST is empty"
  fi
}

# fetch GAE/Go SDKs if needed
fetch_sdk_if_needed() {

  if ! check_update ; then
    warn "check_update is failed. Probably using in-cache SDK."
  fi

  if [ -f "$GAE_SDK_PATH/appcfg.py" ]; then
    debug "appcfg.py found in cache"

    VERSION_CACHE=`singleline $GAE_VERSION_LOG_FILE $GAE_LOG_VERSION`
    if [ ! -z $VERSION_CACHE ] && ! semverlte $LATEST $VERSION_CACHE; then
      info "go-appengine sdk ver. $LATEST is available. It's time to update!"
      do_upgrade
    fi
  else
    do_upgrade
  fi

  do_install
}

if ! install_deps_if_needed ; then
  # if failed , show message and exit
  fail "[install_deps_if_needed] failed. Show output log."
fi

fetch_sdk_if_needed

if [ ! -z $WERCKER_GO_APPENGINE_UTIL_TARGET_DIRECTORY ]; then
    TARGET_DIRECTORY="$WERCKER_SOURCE_DIR/$WERCKER_GO_APPENGINE_UTIL_TARGET_DIRECTORY"
    cd $TARGET_DIRECTORY
else
    TARGET_DIRECTORY="$WERCKER_SOURCE_DIR"
fi

debug 'Set $PATH and $GOPATH'
export PATH="$GAE_SDK_PATH":$PATH

setup_gopath

debug 'Display $PATH and $GOPATH'
echo $PATH
echo $GOPATH

debug 'Display $GOPATH via goapp env'
goapp env GOPATH


case $WERCKER_GO_APPENGINE_UTIL_METHOD in
  deploy)
    info "goapp deploy"
    $GAE_SDK_PATH/appcfg.py update "$TARGET_DIRECTORY" --oauth2_refresh_token="$WERCKER_GO_APPENGINE_UTIL_TOKEN"
    ;;
  get)
    info "goapp get"
    cd "$TARGET_DIRECTORY"
    goapp get -d
    ;;
  test)
    info "goapp test"
    cd "$TARGET_DIRECTORY"
    goapp test
    ;;
  build)
    info "goapp build"
    cd "$TARGET_DIRECTORY"
    goapp build
    ;;
  *)
    fail "Unknown parameter: $WERCKER_GO_APPENGINE_UTIL_METHOD"
esac

debug "Stat -----"

ls -l $GAE_SDK_PATH/goroot/src/hash/crc32/
ls -l $GAE_SDK_PATH/goroot/pkg/linux_amd64_appengine/hash/

if [ $? -eq 0 ]; then
    success "$WERCKER_GO_APPENGINE_UTIL_METHOD is Finished. :)"
else
    fail "$WERCKER_GO_APPENGINE_UTIL_METHOD failed... :("
fi
