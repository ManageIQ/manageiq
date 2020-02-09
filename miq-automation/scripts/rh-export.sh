BUILDDIR="$1"
DOMAIN_EXPORT="$2"

rm -fR ${BUILDDIR}
mkdir -p ${BUILDDIR}/{service_dialogs,buttons,domains}

miqexport domain $DOMAIN_EXPORT $BUILDDIR/domains
miqexport service_dialogs $BUILDDIR/service_dialogs
miqexport buttons $BUILDDIR/buttons/buttons.yml
