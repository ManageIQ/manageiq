set -v

if [[ -n "$TEST_SUITE" ]]; then
  if [[ -n "$PARALLEL" ]]; then
    bundle exec parallel_test -e "bundle exec rake test:$TEST_SUITE:setup"
  else
    bundle exec rake test:$TEST_SUITE:setup
  fi
fi

set +v
