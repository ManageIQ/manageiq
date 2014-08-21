#!/bin/bash

# shell script to create a CA

usage() {
  echo "usage: so_ca.sh [-v] -C 'company' -r '/home/caroot' " >&2
  exit 1
}

while getopts ":C:hr:v" o ; do
  case "${o}" in
    # company name
    C)
      COMPANY="${OPTARG}"
      ;;
    # ca root
    r)
      CAROOT="${OPTARG}"
      ;;
    # verbose
    v)
      VERBOSE=true
      ;;
    # unknown (or -h for help)
    *)
      usage
      ;;
  esac
done


mkdir -p ${CAROOT}/ca.db.certs   # Signed certificates storage
touch ${CAROOT}/ca.db.index      # Index of signed certificates
echo 01 > ${CAROOT}/ca.db.serial # Next (sequential) serial number

if [ ! -f ${CAROOT}/ca.conf ] ; then
    [ -z "$VERBOSE" ] && echo "creating ${CAROOT}/ca.conf" >&2
# ca configuration file
cat <<'EOF' | sed "s|REPLACE_LATER|${CAROOT}|" > ${CAROOT}/ca.conf
[ ca ]
default_ca = ca_default

[ req ]
distinguished_name = req_distinguished_name
#default_ca = ca_default
x509_extensions = v3_ca


[ ca_default ]
dir = REPLACE_LATER
certs = $dir
new_certs_dir = $dir/ca.db.certs
database = $dir/ca.db.index
serial = $dir/ca.db.serial
RANDFILE = $dir/ca.db.rand
certificate = $dir/ca.crt
private_key = $dir/ca.key
default_days = 365
default_crl_days = 30
default_md = md5
preserve = no
policy = generic_policy

# Values to ask the user
[ req_distinguished_name ]
0.organizationName    = Organization Name (e.g.: cfme)
0.organizationName_default  = Snake Oil, Inc.
organizationalUnitName    = Organizational Unit Name (e.g. )
commonName                      = >> Common Name (e.g. server FQDN or YOUR name)
commonName_max                  = 64

# For the CA policy
[ generic_policy ]
organizationName  = match
organizationalUnitName  = optional
commonName    = supplied

# These extensions are added when 'ca' signs a request.
[ usr_cert ]
basicConstraints=CA:FALSE
# This is OK for an SSL server.
# nsCertType      = server

# For an object signing certificate this would be used.
# nsCertType = objsign

# For normal client use this is typical
# nsCertType = client, email

# and for everything including object signing:
# nsCertType = client, email, objsign

# This is typical in keyUsage for a client certificate.
# keyUsage = nonRepudiation, digitalSignature, keyEncipherment

# PKIX recommendations harmless if included in all certificates.
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always

[ v3_req ]
# Extensions to add to a certificate request

basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment

[ v3_ca ]
# Extensions for a typical CA

subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer:always

# This is what PKIX recommends but some broken software chokes on critical
# extensions.
#basicConstraints = critical,CA:true
# So we do this instead.
basicConstraints = CA:true

EOF

echo "${COMPANY}" > ${CAROOT}/COMPANY_NAME
fi

cd ${CAROOT}

[ -n "$VERBOSE" ] && echo -e "\n >>>Generate private key for CA\n" >&2
openssl genrsa -out ca.key 2048

# Create Certificate Signing Request
[ -n "$VERBOSE" ] && echo -e "\n >>>Create certificate signing request for CA\n" >&2
openssl req -new -key ca.key  \
                 -subj "${COMPANY}/CN=CA" \
                 -out ca.csr  \
                 -config ${CAROOT}/ca.conf

[ -n "$VERBOSE" ] && echo -e "\n >>>Self sign CA key\n" >&2
openssl x509 -req -days 10000 \
             -in ca.csr       \
             -out ca.crt      \
             -signkey ca.key
[ -n "$VERBOSE" ] && echo -e "\n ca created" >&2
exit 0
