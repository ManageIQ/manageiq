set -v

source $TRAVIS_BUILD_DIR/tools/ci/setup_vmdb_configs.sh
source $TRAVIS_BUILD_DIR/tools/ci/setup_ruby_env.sh

# suites that need bower assets to work: javascript, vmdb
if [[ "$TEST_SUITE" = "javascript" ]] || [[ "$TEST_SUITE" = "vmdb" ]]; then
  source $TRAVIS_BUILD_DIR/tools/ci/setup_js_env.sh
fi

set +v
