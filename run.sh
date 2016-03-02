#!/usr/bin/env bash

readonly GAE_VERSION_LOG_FILE="$WERCKER_CACHE_DIR/go_appengine_version"
readonly UNZIPPER=7z # unzip
readonly UNZIPPER_OPTION="x" # "-q -o"
readonly UNZIPPER_PKG_APT=p7zip-full
readonly UNZIPPER_PKG_YUM=p7zip

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
    local LAST_MODIFIED=$(stat -c%Y $GAE_VERSION_LOG_FILE 2> /dev/null)
    local CURRENT_TIME=$(date +"%s")
    local readonly APPEND_TIME=( 7 * 24 * 60 * 60 )

    debug "lastModified: $LAST_MODIFIED / currentTime: $CURRENT_TIME"

    if [ -z $LAST_MODIFIED ] || [ $CURRENT_TIME -gt $(( $LAST_MODIFIED + $APPEND_TIME )) ]; then
      LATEST=$(curl https://appengine.google.com/api/updatecheck | grep release | grep -Eo '[0-9\.]+')
    else
      LATEST=$(echo $GAE_VERSION_LOG_FILE 2> /dev/null)
    fi
  fi

  echo "latest: $LATEST"

  [ ! -z $LATEST ]
}

# check semver
#   semverlte 1.2.3 1.2.4 -> true
#   semverlte 1.2.3 1.2.3 -> true
#   semverlte 1.2.4 1.2.3 -> false
# @see http://stackoverflow.com/a/4024263
semverlte() {
    [ "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

do_upgrade() {
  if [ ! -z $LATEST ] ; then
    cd $WERCKER_CACHE_DIR
    local FILE=go_appengine_sdk_linux_amd64-$LATEST.zip

    debug "Download $FILE ..."

    curl -O https://storage.googleapis.com/appengine-sdks/featured/$FILE
    if [ $? -ne 0 ] ; then
      fail "curl error"
    fi

    $UNZIPPER $UNZIPPER_OPTION $FILE > /dev/null
    if [ $? -ne 0 ] ; then
      fail "$UNZIPPER error"
    fi

    # workaround timestamp mess
    # @see https://groups.google.com/forum/#!topic/google-appengine-go/rWc4TkhSECk
#    cd go_appengine/goroot
#    find . -name "*.a" -exec touch {} \;
#    cd -

    # write update log
    echo $LATEST > $GAE_VERSION_LOG_FILE

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

  if [ -f "$WERCKER_CACHE_DIR/go_appengine/appcfg.py" ]; then
    debug "appcfg.py found in cache"

    VERSION_CACHE=$(echo $GAE_VERSION_LOG_FILE 2> /dev/null)
    if [ ! -z $VERSION_CACHE ] && ! semverlte $LATEST $VERSION_CACHE; then
      info "go-appengine sdk ver. $LATEST is available. It's time to update!"
      do_upgrade
    fi
  else
    do_upgrade
  fi
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
export PATH="$WERCKER_CACHE_DIR/go_appengine":$PATH

# @see http://qiita.com/hogedigo/items/fae5b6fe7071becd4051
#export GOPATH="$TARGET_DIRECTORY"

debug 'Display $PATH and $GOPATH'
echo $PATH
echo $GOPATH

debug 'Display $GOPATH via goapp env'
goapp env GOPATH


case $WERCKER_GO_APPENGINE_UTIL_METHOD in
  deploy)
    info "goapp deploy"
    $WERCKER_CACHE_DIR/go_appengine/appcfg.py update "$TARGET_DIRECTORY" --oauth2_refresh_token="$WERCKER_GO_APPENGINE_UTIL_TOKEN"
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

if [ $? -eq 0 ]; then
    success "$WERCKER_GO_APPENGINE_UTIL_METHOD is Finished. :)"
else
    fail "$WERCKER_GO_APPENGINE_UTIL_METHOD failed... :("
fi
