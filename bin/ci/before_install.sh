#!/bin/bash
set -ev

if [ -n "$CI" ]; then
  git config --global user.name "ManageIQ"
  git config --global user.email "contact@manageiq.org"
fi

if [ $TRAVIS_BRANCH != "master" ]; then
  cp $TRAVIS_BUILD_DIR/Gemfile.lock{.release,}
fi
./bin/ci/before_install.rb

export BUNDLE_WITHOUT=development
export BUNDLE_GEMFILE=${PWD}/Gemfile

set +ev
