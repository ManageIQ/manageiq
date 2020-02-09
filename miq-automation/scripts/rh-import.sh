
DOMAIN_IMPORT="$2"
BUILDDIR="$1"

miqimport --overwrite domain "$DOMAIN_IMPORT" "$BUILDDIR/domains"
miqimport service_dialogs "$BUILDDIR/service_dialogs/"
miqimport buttons "$BUILDDIR/buttons/buttons.yml"