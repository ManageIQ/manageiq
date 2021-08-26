#!/bin/bash
set -v

if [ -n "$CI" ]; then
  git config --global user.name "ManageIQ"
  git config --global user.email "contact@manageiq.org"
fi

if [ $TRAVIS_BRANCH != "master" ]; then
  cp $TRAVIS_BUILD_DIR/Gemfile.lock{.release,}
fi

source $TRAVIS_BUILD_DIR/bin/ci/setup_vmdb_configs.sh
source $TRAVIS_BUILD_DIR/bin/ci/setup_ruby_env.sh

set +v
