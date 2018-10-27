#!/bin/bash

# Usage:
#   travis.sh install  # Install required software
#   travis.sh env      # Print build environment
#   travis.sh script   # Test the build

set -eu
set -o pipefail

docker_exec() {
  if [ $# -ge 1 ] && [ $1 = sudo ]; then
    shift
    docker exec -u root -i -t build_test /bin/bash -c ". $(pwd)/scripts/bash/travis_retry.bash && cd $(pwd)/form && $*"
  elif [ $# -ge 2 ] && [ $1 = travis_retry ] && [ $2 = sudo ]; then
    shift 2
    docker exec -u root -i -t build_test /bin/bash -c ". $(pwd)/scripts/bash/travis_retry.bash && cd $(pwd)/form && travis_retry $*"
  else
    docker exec -i -t build_test /bin/bash -c ". $(pwd)/scripts/bash/travis_retry.bash && cd $(pwd)/form && $*"
  fi
}

. ./scripts/bash/travis_retry.bash

travis_install() {
  travis_retry docker run -d --name build_test -v "$(pwd):$(pwd)" "$IMAGE" tail -f /dev/null

  case $TARGET-$IMAGE in
    build-*)
      travis_retry wget https://github.com/vermaseren/form/releases/download/v$VERSION/form-$VERSION.tar.gz
      tar xfz form-*.tar.gz
      rm form-*.tar.gz
      mv form-* form
      ;;
    devel-*)
      travis_retry git clone https://github.com/vermaseren/form.git
      if [ -n "${REVISION+x}" ]; then
        travis_retry git -C form checkout $REVISION
      fi
      ;;
  esac

  case $TARGET-$IMAGE in
    build-debian:*|build-ubuntu:*)
      docker_exec travis_retry sudo apt -q -y update
      docker_exec travis_retry sudo apt -q -y install build-essential libgmp-dev zlib1g-dev
      ;;
    devel-debian:*|devel-ubuntu:*)
      docker_exec travis_retry sudo apt -q -y update
      docker_exec travis_retry sudo apt -q -y install build-essential libgmp-dev zlib1g-dev
      docker_exec travis_retry sudo apt -q -y install automake git ruby
      ;;
    build-fedora:*)
      docker_exec travis_retry sudo dnf -q -y install gcc-c++ gmp-devel make zlib-devel
      ;;
    devel-fedora:*)
      docker_exec travis_retry sudo dnf -q -y install gcc-c++ gmp-devel make zlib-devel
      docker_exec travis_retry sudo dnf -q -y install automake git ruby rubygem-test-unit
      ;;
    build-centos:*)
      docker_exec travis_retry sudo yum -q -y install gcc-c++ gmp-devel make zlib-devel
      ;;
    devel-centos:*)
      docker_exec travis_retry sudo yum -q -y install gcc-c++ gmp-devel make zlib-devel
      docker_exec travis_retry sudo yum -q -y install automake git ruby rubygem-minitest
      ;;
  esac
}

travis_env() {
  docker_exec $(pwd)/scripts/print_env.sh
}

travis_script() {
  case $TARGET-$IMAGE in
    build-*)
      docker_exec ./configure
      docker_exec make
      docker_exec sudo make install
      ;;
    devel-*)
      docker_exec autoreconf -i
      docker_exec ./configure
      docker_exec make
      docker_exec make check
      docker_exec sudo make install
      ;;
  esac
}

case "$1" in
  install|env|script)
    travis_$1
    ;;
  *)
    echo "Error: unknown command $1" >&2
    exit 1
    ;;
esac
