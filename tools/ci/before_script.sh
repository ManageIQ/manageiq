set -v

if [[ -n "$TEST_SUITE" ]]; then
  bundle exec rake test:$TEST_SUITE:setup
fi

set +v
