#!/bin/sh

header() {
  "$@" 2>/dev/null | sed '/^$/d' | head -1
}

echo 'Build environment:'
uname -srvmo
header gcc --version
header g++ --version
header make --version
header git --version
header autoconf --version
header automake --version
header m4 --version
header perl --version
header ruby --version
