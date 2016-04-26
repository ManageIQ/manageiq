set -v

if [[ -n "$TEST_SUITE" ]]; then
  bundle exec rake test:$TEST_SUITE:teardown
fi

set +v
