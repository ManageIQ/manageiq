#!/bin/bash

# shell script to create signed keys / crts
# tar option allows them to be run from a separate server

VERBOSE=${VERBOSE:-false}
KEY_DIR=${KEY_DIR:-/var/www/miq/vmdb/certs}

# sample company: /C=US/ST=Massachusetts/L=Westford}
# sample company: /O=redhat cfme
# sample fqdn: "OU=postgres server 1/CN=fqdn" OR "CN=root"

usage() {
  echo "usage: so_sign.sh [-v] [-t file.tgz] [-k] [ -c root.crt] subject alt_subject filename [subject2 filename2 ...]" >&2
  exit 1
}

# tar up the results and stream the tar (to work over ssh)
enable_tar() {
  # if they pass in a target file, set the tar target
  [ -n "$1" ] && TAR="$1"

  if [ -z "${TAR_DIR}" ] ; then
    TAR_DIR=`mktemp -d -t so_sign.XXX`
    cd ${TAR_DIR}
    cleanup() {
      [ -n "${TAR_DIR}" -a -d "${TAR_DIR}" ] && rm -rf "${TAR_DIR}"
      true
    }
    trap cleanup EXIT
  fi
}

sign() {
  #subject part
  fqdn="${1}"
  #base filename
  name="${2}"

  # Create private/public key pair
  if [ ! -s "${name}.key" ] ; then
    [ -z "$VERBOSE" ] && echo -e "\n>>creating key ${name}.key<<\n" >&2
    #TODO: specify ca.conf file, put 1024 into conf.
    openssl genrsa -out ${name}.key 1024
  fi
  [ ! -s ${name}.key ] && echo -e "\nbad key" >&2 && exit 1

  # Create Certificate Signing Request
  if [ ! -s "${name}.csr" ] ; then
    [ -z "$VERBOSE" ] && echo -e "\n>>creating signing request ${name}.csr (${COMPANY}/${fqdn})<<\n" >&2
    openssl req -new -key ${name}.key \
      -subj "${COMPANY}/${fqdn}" \
      -out ${name}.csr \
      -config ${CAROOT}/ca.conf
  fi
  [ ! -s "${name}.csr" ] && echo -e "\nbad csr" >&2 && exit 2

  # Sign key
  if [ ! -s "${name}.crt" ] ; then
    [ -z "$VERBOSE" ] && echo -e "\n>>signing key ${name}.crt<<\n" >&2
    openssl ca -config ${CAROOT}/ca.conf   \
      -batch \
      -in ${name}.csr              \
      -cert ${CAROOT}/ca.crt      \
      -keyfile ${CAROOT}/ca.key   \
      -out ${name}.crt
  fi

  [ ! -s ${name}.crt ] && echo -e "\nbad crt" >&2 && exit 3
  rm ${name}.csr
}

############# parse arguments ########################

while getopts ":c:C:hkr:t:v" o ; do
  case "${o}" in
    # add cert file
    c)
      enable_tar
      cp "${CAROOT}/ca.crt" "${OPTARG-root.crt}"
      ;;
    # company name
    C)
      COMPANY="${OPTARG}"
      ;;
    # include secret keys
    k)
      cp ${KEY_DIR}/v*_key* .
      ;;
    # ca root
    r)
      CAROOT="${OPTARG}"
      ;;
    # output to tar file
    t)
      enable_tar ${OPTARG}
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

shift $((OPTIND-1))
[ $# -lt 2 ] && usage

############# main ########################

# default the company name to the version stored in the file
[ -z "$COMPANY" -a -f ${CAROOT}/COMPANY_NAME ] && COMPANY="$(cat ${CAROOT}/COMPANY_NAME)"

while [ $# -gt 0 ] ; do
  sign "${1}" "${2}"
  shift 2
done

# tar up the results and output them into stdout
if [ -n "${TAR_DIR}" ] ; then
  tar -C "${TAR_DIR}" -czf ${TAR--} *
fi

[ -n "$VERBOSE" ] && echo "done" >&2
exit 0
