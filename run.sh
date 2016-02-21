#!/usr/bin/env bash

GAE_VERSION_LOG_FILE=go_appengine_version

install_deps_if_needed() {
  if hash unzip ; then
    return true
  else
    debug "unzip is not found."

    if hash apt-get ; then
      sudo apt-get update; sudo apt-get install unzip -y
    elif hash yum ; then
      sudo yum install unzip -y
    else
      fail "Not found neither suitable package manager nor unzip."
    fi

    if hash unzip ; then
      return true
    else
      debug "unzip is not found."
      return false
    fi
  fi
}

check_update() {
  if [ -z $LATEST ]; then
    LAST_MODIFIED=$(echo stat -c %Y $GAE_VERSION_LOG_FILE 2> /dev/null)
    CURRENT_TIME=`date +"%s"`
    if [ -z LAST_MODIFIED ] || [ CURRENT_TIME -gt $(( LAST_MODIFIED + 7 * 24 * 60 * 60 )) ]; then
      export LATEST=`curl https://appengine.google.com/api/updatecheck | grep release | grep -Eo '[0-9\.]+'`
    else
      export LATEST=`echo $GAE_VERSION_LOG_FILE 2> /dev/null`
    fi
  fi
  return [ ! -z $LATEST ]
}

# check semver
#   semverlte 1.2.3 1.2.4 -> true
#   semverlte 1.2.3 1.2.3 -> true
#   semverlte 1.2.4 1.2.3 -> false
# @see http://stackoverflow.com/a/4024263
semverlte() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | head -n1`" ]
}

do_upgrade() {
  if [ -z $LATEST ] ; then
    cd $WERCKER_CACHE_DIR
    FILE=go_appengine_sdk_linux_amd64-$LATEST.zip

    debug "Download $FILE ..."

    curl -O https://storage.googleapis.com/appengine-sdks/featured/$FILE
    if $? ; then
      fail "curl error"
    fi

    unzip -q $FILE -d $HOME
    if $? ; then
      fail "unzip error"
    fi
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

    VERSION_CACHE=`echo $GAE_VERSION_LOG_FILE 2> /dev/null`
    if [ ! -z $VERSION_CACHE ] && [ ! semverlte $LATEST $VERSION_CACHE ]; then
      info "go-appengine sdk ver. $LATEST is available. It's time to update!"
      do_upgrade
    fi
  else
    do_upgrade
  fi
}

if install_deps_if_needed ; then
  # if failed , show message and exit
  fail "[install_deps_if_needed] failed. Show output log."
fi

fetch_sdk_if_needed

debug 'Set $PATH and $GOPATH'
export PATH="$WERCKER_CACHE_DIR/go_appengine":$PATH
export GOPATH="$WERCKER_SOURCE_DIR"

debug 'Display $GOPATH'
goapp env GOPATH

cd $WERCKER_GO_APPENGINE_UTIL_TARGET_DIRECTORY

case $WERCKER_GO_APPENGINE_UTIL_METHOD in
  deploy)
    info "goapp deploy"
    $WERCKER_CACHE_DIR/go_appengine/appcfg.py update "$WERCKER_SOURCE_DIR" --oauth2_refresh_token="$WERCKER_GO_APPENGINE_UTIL_TOKEN"
    ;;
  get)
    info "goapp get"
    goapp get
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

success "$WERCKER_GO_APPENGINE_UTIL_METHOD is Finished."
