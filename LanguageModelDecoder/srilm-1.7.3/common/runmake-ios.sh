#!/bin/sh

# Set SDK_VERSIONS to ios sdks you have installed and want to build for
# but Apple defaults to only include latest 8.1.
#SDK_VERSIONS="7.1 8.0 8.1"
SDK_VERSIONS="11.3"


for SDK_VERSION in ${SDK_VERSIONS}; do 

	for MT in iPhoneOS-${SDK_VERSION}-armv7 iPhoneOS-${SDK_VERSION}-armv7s iPhoneOS-${SDK_VERSION}-arm64 iPhoneSimulator-${SDK_VERSION}-i386 iPhoneSimulator-${SDK_VERSION}-x86_64; do

	  make -j 8 MACHINE_TYPE=${MT} OPTION=_c "$@"

	done 

done
