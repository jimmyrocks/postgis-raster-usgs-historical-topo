#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
zip_path="$1"
import_raster="$DIR"/import_raster.sh
zip_name="${zip_path##*/}"
temp_path="${zip_path%/*}"/.tmp_"${zip_name%.*}"

unzip "$zip_path" -d "$temp_path" && \
  /bin/bash "$import_raster" "`ls | /bin/grep .pdf`" && \
  rm -rf $temp_path
