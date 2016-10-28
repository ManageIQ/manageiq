echo "gem: --no-ri --no-rdoc --no-document" > ~/.gemrc
travis_retry gem install bundler -v ">= 1.11.1"
export BUNDLE_WITHOUT=development
export BUNDLE_GEMFILE=${PWD}/Gemfile
