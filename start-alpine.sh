#!/usr/bin/bash
# this FILE is public domain, by @ryancnelson on github, 2023
# to be used with a tarball ryan is currently providing at 
# licenses on stuff in that tarball are still their own, from the original source

## bail out if error:
set -e


mychrootdir=/storage/ryanstuff/alpine-chroot

mkdir -p $mychrootdir
cd $mychrootdir


# fetch the 'xpkg' aarch64 binary that we'd expect to run on your powkiddy x55
curl -L  -O https://github.com/pkgxdev/pkgx/releases/download/v1.1.1/pkgx-1.1.1+linux+aarch64.tar.xz
tar -xvf pkgx-1.1.1+linux+aarch64.tar.xz
chmod +x pkgx


mkdir /storage/${mychrootdir}/dev
mkdir /storage/${mychrootdir}/proc
mkdir /storage/${mychrootdir}/sys

mount -o bind /dev /storage/${mychrootdir}/dev
mount -o bind /proc /storage/${mychrootdir}/proc
mount -o bind /sys /storage/${mychrootdir}/sys

cp -L /etc/resolv.conf /storage/${mychrootdir}/etc/resolv.conf


## i have hardcoded "http://mirror.clarkson.edu/alpine/latest-stable/main" in 
# /etc/apk/repositories , as this script is intended to work with a tarball of my 
# own creation, which is where this bit is hardcoded.
# So, do nothing re: apk here




