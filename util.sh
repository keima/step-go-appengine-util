#!/usr/bin/env bash
# Util functions

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
