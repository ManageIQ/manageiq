


BUILDDIR="$1"
DOMAIN_IMPORT="$2"

echo "DIR: $BUILDDIR"
echo "DOMAIN: $DOMAIN_IMPORT"

pushd /var/www/miq/vmdb

echo "Importing domain $DOMAIN_IMPORT from $BUILDDIR"
bundle exec rake evm:automate:import DOMAIN=$DOMAIN_IMPORT IMPORT_DIR=$BUILDDIR/domains PREVIEW=false ENABLED=true OVERWRITE=true

echo "importing service dialogs from $BUILDDIR/service_dialogs"
bundle exec rake evm:import:service_dialogs -- --source $BUILDDIR/service_dialogs

echo "importing buttons from $BUILDDIR/buttons/CustomButtons.yaml"
bundle exec rake evm:import:custom_buttons -- --source $BUILDDIR/buttons --overwrite

popd