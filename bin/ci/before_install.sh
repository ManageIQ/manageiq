#!/bin/bash
set -ev

if [ -n "$CI" ]; then
  git config --global user.name "ManageIQ"
  git config --global user.email "contact@manageiq.org"
fi

./bin/ci/before_install.rb

export BUNDLE_WITHOUT=development
export BUNDLE_GEMFILE=${PWD}/Gemfile

set +ev
