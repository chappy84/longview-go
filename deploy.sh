#!/bin/bash

# For now this will do
ARCH=x86_64

PACKDIR="./package"
TEMPDIR="${PACKDIR}/out"

VERSION=$(cat ${PACKDIR}/VAR_VERSION | perl -ne 'chomp and print')
BUILD=$(cat ${PACKDIR}/VAR_BUILD | perl -ne 'chomp and print')

if [[ "$ARCH" == "i686" ]]; then
    DEB_ARCH=i386
elif [[ "$ARCH" == "x86_64" ]]; then
    DEB_ARCH=amd64
else
    echo "*** Unknown arch $ARCH"
    exit 1
fi

OUT_DEB="longview-go_${VERSION}-${BUILD}_$DEB_ARCH.deb"

echo "*** Building Debian package ..."

if ! ./package/package.sh amd64
then
	echo "*** Error"
	exit 1
fi

if [[ "$ARCH" == "i686" ]]; then
    DEB_ARCH=i386
elif [[ "$ARCH" == "x86_64" ]]; then
    DEB_ARCH=amd64
else
    echo "*** Unknown arch $ARCH"
    exit 1
fi

echo "*** Version : ${VERSION}-${BUILD}"
echo "*** Arch    : ${DEB_ARCH}"

SERVER_LIST="$*"
if [[ $# -eq 0 ]]
then
    SERVER_LIST="kman.mobi clearview.rocks node-eu-0001.email2-cloud.com node-na-0001.email2-cloud.com"
fi

for SERVER in $SERVER_LIST
do

  KEY=""
  case "$SERVER" in
      "kman.mobi")
          KEY="2C6F9D8D-068A-D23C-1B87639441717CB1"
          ;;
      "clearview.rocks")
          KEY="B6EEAB78-DAC1-12BB-55A06A8AD70521FF"
          ;;
      "node-eu-0001.email2-cloud.com")
          KEY="BE99CFCC-EAEC-4B75-B7B2E2768C2C30D5"
          ;;
      "node-na-0001.email2-cloud.com")
          KEY="21F055CB-B819-4455-A358308A6B5FC173"
          ;;
      *)
          echo "Unknown server ${SERVER}"
          exit 1
  esac

  echo "*** Copying to ${SERVER} ..."

  if ! rsync -acv "${TEMPDIR}/${OUT_DEB}" "root@${SERVER}:"
  then
    echo "*** Error"
    exit 1
  fi

  echo "*** Installing ..."

  ssh -t "root@${SERVER}" "apt-get install --reinstall ./${OUT_DEB} && \
      mkdir -p /etc/linode &&
      printf '$KEY\n' > /etc/linode/longview.key &&
      printf 'username linode-longview\npassword longview\n' > /etc/linode/longview.d/MySQL.conf"

  echo "*** Restarting ..."

  systemctl --host "root@${SERVER}" daemon-reload
  systemctl --host "root@${SERVER}" restart longview-go

done
