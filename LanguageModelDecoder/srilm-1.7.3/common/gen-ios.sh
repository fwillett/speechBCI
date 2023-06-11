#!/bin/bash

# This just needs to be some existing version to use as template
TEMPL=10.3

SDK_DIR=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs

if [ ! -d "${SDK_DIR}" ]; then
  (1>&2 echo "Can't find installed iOS SDK at: ${SDK_DIR}")
  exit 1
fi

# Should of form: iPhoneOS11.2.sdk
# and current should soft-link as iPhoneOS.sdk.
SDK_VERS=`cd $SDK_DIR && find . -name "iPhoneOS*.*.sdk"`

if [ "${SDK_VERS}" = "" ]; then
  (1>&2 echo "No iPhoneOS SDK found in directory: ${SDK_DIR}")
  exit 1
fi

echo "Found SDKs: ${SDK_VERS}"

for SDK_VER in "${SDK_VERS}"; do
  echo "Enter to generate Makefiles for ${SDK_VER}; CTRL-c to quit."
  read ANS

  VID=`echo $SDK_VER | sed 's/^[^0-9]*//' | sed 's/[^0-9]*$//'`

  # Make iPhone and simulator versions
  for MT in iPhoneOS-VVV-armv7 iPhoneOS-VVV-armv7s iPhoneOS-VVV-arm64 iPhoneSimulator-VVV-i386 iPhoneSimulator-VVV-x86_64; do
    MT_FILE="Makefile.machine.${MT}"
    INFILE=`echo $MT_FILE | sed "s/VVV/$TEMPL/"`
    OUTFILE=`echo $MT_FILE | sed "s/VVV/$VID/"`
    if [ ! -f "$INFILE" ]; then
      (1>&2 echo "Couldn't find template input file: $INFILE")
    else
      if [ -f "$OUTFILE" ]; then
        (1>&2 echo "Already exists, not changing: $OUTFILE")
      else
        cat $INFILE \
            | sed "s/^XCODE_SDK_VERSION.*/XCODE_SDK_VERSION = ${VID}/" \
            | sed "s/^#.*File:.*/#    File:   ${OUTFILE}/" \
            | sed "s/^#.*Date:.*/#    Date:   `date`/" \
            > $OUTFILE
        echo "Created: $OUTFILE"
      fi
    fi
  done

done
