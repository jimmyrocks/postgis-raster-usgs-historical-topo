#!/bin/bash

# ##############
# SETTINGS #####
# ##############
geodatabase_name="topo"
utmZone="18"
srs="+proj=utm +zone=$utmZone +datum=NAD83"
epsg_srs="26918"
tile="256x256"
dpi=75
# ##############
# ##############
# ##############

# Setting up paths #
original_path="$1"
raster_filename="${original_path##*/}"
tablename="${raster_filename%.*}"
tablename="${tablename,,}"

neatline=`gdalinfo "$original_path" | grep NEATLINE | perl -p -e 's/\s+?NEATLINE=//g'`
extent_sql="SELECT ST_Extent(ST_PolygonFromText('$neatline'));"
st_extent=`sudo -u postgres psql -d "$geodatabase_name" -Atc "$extent_sql"`
extent=`echo "$st_extent" | perl -p -e 's/BOX\(([0-9.-]{1,})\s([0-9.-]{1,}),([0-9.-]{1,}) ([0-9.-]{1,})\)/$1 $4 $3 $2/g'`

function create_current_file {
  echo -e "\n*** CREATING A TEMP FILE ***"
  # Making a duplicate file to prevent destroying the original
  current_file_path="${original_path%.*}"_tmp"${original_path##*.}"
  cp "$original_path" "$current_file_path"
}

function clip_neatline {
  echo -e "\n*** CLIPPING NEATLINE EXTENT ***\n"

  clipped_filename="${original_path%.*}"_clip.tif
  gdal_translate -projwin $extent -of GTiff "$current_file_path" "$clipped_filename" --config GDAL_PDF_DPI $dpi
  rm "$current_file_path"
  current_file_path="$clipped_filename"
}

function project_file {
  echo -e "\n*** PROJECTING INTO "$srs" ***\n"

  projected_filename="${original_path%.*}"_utm.tif
  gdalwarp -t_srs "$srs" "$current_file_path" "$projected_filename"
  rm "$current_file_path"
  current_file_path="$projected_filename"
}

function insert_map {
  echo -e "\n*** ADDING TABLE ("$tablename") TO DATABASE ($geodatabase_name) ***\n"

  raster2pgsql -s $epsg_srs -d -I -M -t $tile "$current_file_path" "public"."$tablename" | sudo -u postgres psql -d "$geodatabase_name"
  rm "$current_file_path"
  current_file_path=""
}

function detail_neatline_clip {
  echo -e "\n*** CLIPPING BY THE NEATLINE DETAIL ***\n"

  source_proj4=`gdalinfo -proj4 "$original_path" | grep -A 1 PROJ\.4 | tail -n 1 | perl -p -e "s/'//g"`
  neatline_sql="SELECT ST_AsGeoJSON(ST_PolygonFromText('$neatline'))"
  neatline_geojson=`sudo -u postgres psql -d $geodatabase_name -Atc "$neatline_sql"`
  csv_neatline=`ogr2ogr -f CSV -s_srs "$source_proj4" -t_srs "EPSG:$epsg_srs" -lco "GEOMETRY=AS_WKT" /dev/stdout /dev/stdin <<< $neatline_geojson`
  reprojected_neatline=`echo $csv_neatline | perl -p -e "s/^WKT \"|\"$/'/g"`

  clip_sql="UPDATE \"$tablename\" SET rast = ST_Clip(rast, ST_PolygonFromText($reprojected_neatline, $epsg_srs), true);"
  remove_sql="DELETE FROM \"$tablename\" WHERE ST_IsEmpty(rast);"

  # Run the SQL commands
  sudo -u postgres psql -d $geodatabase_name -Atc "$clip_sql";
  sudo -u postgres psql -d $geodatabase_name -Atc "$remove_sql"
}

# Run the functions
create_current_file
clip_neatline
project_file
insert_map
detail_neatline_clip

echo -e "\n*** COMPLETED ***\n"
