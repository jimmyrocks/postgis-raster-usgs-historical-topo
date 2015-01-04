#!/bin/bash

if [ -n "$1"]; then
  echo "USAGE: import_all_zips.sh DIRECTORY_WITH_ZIP_FILES"
  exit 1;
fi

# Determine the name of the directory where this script resides
# this is used to run other scripts in the same directory
# https://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# Loop through all the zip files and import them one by one
find "$1" -type f -name '*.zip' -exec sh -c '/bin/bash '"$DIR"'/import_zip.sh "{}"' \;
