#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Usage: makecore.sh <version> <arch>"
fi

mkdir -p screeninvader-core/DEBIAN
chmod -R 0755 screeninvader-core
./makecontrol.sh core $1 > screeninvader-core/DEBIAN/control
rm -fr screeninvader-core/root screeninvader-core/lounge screeninvader-core/setup
cp -a ../src/setup ../src/lounge ../src/root screeninvader-core/
chown -R root:root screeninvader-core/root
chown -R 1000:1000 screeninvader-core/lounge
dpkg-deb -b screeninvader-core/ screeninvader-core-all.deb
dpkg-sig --sign builder screeninvader-core-all.deb
