#!/bin/bash
set -v

git config --global user.name "ManageIQ"
git config --global user.email "contact@manageiq.org"
source $TRAVIS_BUILD_DIR/bin/ci/setup_vmdb_configs.sh
source $TRAVIS_BUILD_DIR/bin/ci/setup_ruby_env.sh

set +v
