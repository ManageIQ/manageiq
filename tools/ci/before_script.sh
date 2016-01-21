set -v

if [[ -n "$TEST_SUITE" ]]; then
  REGION=1 bundle exec rake test:$TEST_SUITE:setup
fi

set +v
