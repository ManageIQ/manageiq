set -e

git clone https://github.com/ManageIQ/manageiq.git --depth 1 spec/manageiq

cd spec/manageiq
source tools/ci/setup_vmdb_configs.sh
source tools/ci/setup_js_env.sh
cd -

source spec/manageiq/tools/ci/setup_ruby_env.sh

set +v
