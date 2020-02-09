BUILDDIR="$1"
DOMAIN_EXPORT="$2"

rm -fR ${BUILDDIR}
mkdir -p ${BUILDDIR}/{service_dialogs,buttons,domains}

pushd /var/www/miq/vmdb

bundle exec rake evm:automate:export DOMAIN=$DOMAIN_EXPORT EXPORT_DIR=$BUILDDIR/domains
bundle exec rake evm:export:service_dialogs -- --directory $BUILDDIR/service_dialogs
bundle exec rake evm:export:custom_buttons -- --directory $BUILDDIR/buttons

popd
