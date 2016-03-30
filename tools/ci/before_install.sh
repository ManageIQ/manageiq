set -v

echo "gem: --no-ri --no-rdoc --no-document" > ~/.gemrc
travis_retry gem install bundler -v ">= 1.11.1"

if [[ -n "${GEM}" ]] ; then
  cd gems/${GEM}
else
  echo "1" > REGION
  cp certs/v2_key.dev certs/v2_key
  cp config/database.pg.yml config/database.yml
  psql -c "CREATE USER root SUPERUSER PASSWORD 'smartvm';" -U postgres
  export BUNDLE_WITHOUT=development
fi
export BUNDLE_GEMFILE=${PWD}/Gemfile

# suites that need bower assets to work: javascript, vmdb
if [[ "$TEST_SUITE" = "javascript" ]] || [[ "$TEST_SUITE" = "vmdb" ]]; then
  which bower || npm install -g bower
  bower install --allow-root -F --config.analytics=false
fi

set +v
