set -v

echo "gem: --no-ri --no-rdoc --no-document" > ~/.gemrc
travis_retry gem install bundler -v ">= 1.11.1"

if [[ -n "${GEM}" ]] ; then
  cd gems/${GEM}
else
  echo "1" > REGION
  cp certs/v2_key.dev certs/v2_key
  cp config/database.pg.yml config/database.yml
  cp config/cable.yml.sample config/cable.yml
  psql -c "CREATE USER root SUPERUSER PASSWORD 'smartvm';" -U postgres
  export BUNDLE_WITHOUT=development
fi
export BUNDLE_GEMFILE=${PWD}/Gemfile

# suites that need bower assets to work: javascript, vmdb
if [[ "$TEST_SUITE" = "javascript" ]] || [[ "$TEST_SUITE" = "vmdb" ]]; then
  source $TRAVIS_BUILD_DIR/tools/ci/setup_js_env.sh
fi

set +v
