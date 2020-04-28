#!/bin/bash
./tools/ci/setup_ruby_environment.rb
bundle config --local build.sassc --disable-march-tune-native
bundle config --local build.unf_ext --with-cxxflags=-fsigned-char
export BUNDLE_WITHOUT=development
export BUNDLE_GEMFILE=${PWD}/Gemfile
