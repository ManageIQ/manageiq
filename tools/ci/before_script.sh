if [[ -f ${TRAVIS_BUILD_DIR}/.skip-ci ]] ; then
  echo "skipping before_script"
  cat ${TRAVIS_BUILD_DIR}/.skip-ci
elif [[ -n "$TEST_SUITE" ]] ; then
  if [[ -n "$SPA_UI" ]] ; then
    pushd spa_ui/$SPA_UI
      npm install bower gulp -g
      npm install
      npm version
    popd
  fi
  bundle exec rake test:$TEST_SUITE:setup
fi
