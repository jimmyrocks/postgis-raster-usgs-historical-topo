#!/bin/bash

if [ -n "$1"]; then
  echo "USAGE: import_zip.sh ZIP_FILE"
  exit 1;
fi

# Determine the directory where this script resides
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
zip_path="$1"
import_raster="$DIR"/import_raster.sh
zip_name="${zip_path##*/}"
temp_path="${zip_path%/*}"/.tmp_"${zip_name%.*}"

# Unzip the file, and find the first .pdf file inside the zip directory
# TODO: this can be changed to deal with more files, but the USGS zip files only contain a single pdf
unzip "$zip_path" -d "$temp_path" && \
  /bin/bash "$import_raster" "$temp_path"/"`ls \"$temp_path\" | /bin/grep .pdf | head -n 1`"

# Remove the unzipped file after we're done processing it
rm -rf "$temp_path"
