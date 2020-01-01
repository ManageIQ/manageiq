./tools/ci/setup_ruby_environment.rb
bundle config --local build.sassc --disable-march-tune-native
export BUNDLE_WITHOUT=development
export BUNDLE_GEMFILE=${PWD}/Gemfile
