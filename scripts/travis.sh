#!/bin/bash

# Usage:
#   travis.sh install  # Install required software
#   travis.sh env      # Print build environment
#   travis.sh script   # Test the build
#
# Variables:
#   IMAGE (e.g., "debian:stretch") is a docker image and must be set.
#   VERSION (e.g., "4.2.0", "HEAD") or REVISION (<commit-ish>) must be set.

set -eu
set -o pipefail

# Load "travis_retry".
. ./scripts/bash/travis_retry.bash

# TARGET = "release" or "devel" determined from $VERSION or $REVISION.
if [ -n "${VERSION+x}" ]; then
  if [ -n "${REVISION+x}" ]; then
    echo "Error: both VERSION and REVISION given" >&2
    exit 1
  fi
  if [ "$VERSION" == HEAD ]; then
    TARGET=devel
  else
    TARGET=release
  fi
elif [ -n "${REVISION+x}" ]; then
  TARGET=devel
else
  echo "Error: neither VERSION nor REVISION given" >&2
  exit 1
fi

# Execute a command in the test container. This function can be called as
#   docker_exec sudo <command...>
#   docker_exec travis_retry sudo <command...>
#   docker_exec <command...>
#   docker_exec travis_retry <command...>
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

travis_install() {
  # First, make a test container. The current directory is shared with the container.
  travis_retry docker run -d --name build_test -v "$(pwd):$(pwd)" "$IMAGE" tail -f /dev/null

  # Fetch the FORM source.
  case $TARGET-$IMAGE in
    release-*)
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

  # Install required packages.
  case $TARGET-$IMAGE in
    *-debian:*|*-ubuntu:*)
      docker_exec travis_retry sudo apt-get -q -y update
      docker_exec travis_retry sudo apt-get -q -y install build-essential libgmp-dev ruby zlib1g-dev
      ;;
    *-fedora:*)
      docker_exec travis_retry sudo dnf -q -y install gcc-c++ gmp-devel make ruby rubygem-test-unit zlib-devel
      ;;
    *-centos:*)
      docker_exec travis_retry sudo yum -q -y install gcc-c++ gmp-devel make ruby rubygem-minitest zlib-devel
      ;;
  esac
  case $TARGET-$IMAGE in
    devel-debian:*|devel-ubuntu:*)
      docker_exec travis_retry sudo apt-get -q -y install automake git
      ;;
    devel-fedora:*)
      docker_exec travis_retry sudo dnf -q -y install automake git
      ;;
    devel-centos:*)
      docker_exec travis_retry sudo yum -q -y install automake git
      ;;
  esac
}

travis_env() {
  # Print information of the test container.
  docker_exec $(pwd)/scripts/print_env.sh
}

travis_script() {
  # Run the test.
  case $TARGET-$IMAGE in
    devel-*)
      docker_exec autoreconf -i
      ;;
  esac
  case $TARGET-$IMAGE in
    *)
      docker_exec ./configure
      docker_exec make
      docker_exec make check
      docker_exec sudo make install
      docker_exec ls -l /usr/local/bin/form
      docker_exec ls -l /usr/local/bin/tform
      docker_exec ls -l /usr/local/share/man/man1/form.1
      ;;
  esac
}

# The entry point.
case "$1" in
  install|env|script)
    travis_$1
    ;;
  *)
    echo "Error: unknown command $1" >&2
    exit 1
    ;;
esac
