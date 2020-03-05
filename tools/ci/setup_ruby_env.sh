#!/bin/bash
./tools/ci/setup_ruby_environment.rb
export BUNDLE_WITHOUT=development
export BUNDLE_GEMFILE=${PWD}/Gemfile
