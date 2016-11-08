which bower || npm install -g bower

# Check if the bower cache is valid, otherwise delete it
if ! cmp --silent bower.json vendor/assets/bower_components/bower.json; then
  rm -rf vendor/assets/bower_components
fi

if [ -d vendor/assets/bower_components ]; then
  echo "bower assets installed... moving on."
else
  bower install --allow-root -F --config.analytics=false
  STATUS=$?
  echo bower exit code: $STATUS

  # fail the whole test suite if bower install failed
  [ $STATUS = 0 ] || exit 1
  [ -d vendor/assets/bower_components ] || exit 1
fi
