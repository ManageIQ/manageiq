which bower || npm install -g bower
bower install --allow-root -F --config.analytics=false
STATUS=$?
echo bower exit code: $STATUS

# fail the whole test suite if bower install failed
[ $STATUS = 0 ] || exit 1
[ -d vendor/assets/bower_components ] || exit 1
