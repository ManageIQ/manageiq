set -v

if [[ -n "$TEST_SUITE" ]] ; then
  if [[ -n "$SPA_UI" ]] ; then
    pushd spa_ui/$SPA_UI
      npm set progress=false
      npm install bower gulp -g
      npm install
      npm version
    popd
  fi
  bundle exec rake test:$TEST_SUITE:setup
fi

set +v
