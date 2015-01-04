#!/bin/bash

# ##############
# SETTINGS #####
# ##############
geodatabase_name="topo"
epsg_srs="3857"
tile="64x64"
meter_pixelsX=25
meter_pixelsY=25
# ##############
# ##############
# ##############

if [ -n "$1"]; then
  echo "USAGE: import_raster.sh GeoPDF_FILE"
  exit 1;
fi

# Setting up paths #
original_path="$1"
raster_filename="${original_path##*/}"
tablename="${raster_filename%.*}"
tablename="${tablename,,}"

function get_neatline {
  # The USGS files have a "neatline" that can be used to clip the polygon
  # This extracts it from the metadata
  neatline=`gdalinfo "$original_path" | grep NEATLINE | perl -p -e 's/\s+?NEATLINE=//g'`
}

function create_current_file {
  echo -e "\n*** CREATING A TEMP FILE ***"
  # Making a duplicate file to prevent destroying the original
  current_file_path="${original_path%.*}"_tmp."${original_path##*.}"
  cp "$original_path" "$current_file_path"
}

function clip_neatline {
  echo -e "\n*** CLIPPING NEATLINE EXTENT ***\n"

  # SQL statement used to ask PostGIS to convert the neatline into an extent
  extent_sql="SELECT ST_Extent(ST_PolygonFromText('$neatline'));"
  # Run the SQL statement against the database
  st_extent=`sudo -u postgres psql -d "$geodatabase_name" -Atc "$extent_sql"`
  # Convert the extent from postgis to the format used by gdal_translate
  extent=`echo "$st_extent" | perl -p -e 's/BOX\(([0-9.-]{1,})\s([0-9.-]{1,}),([0-9.-]{1,}) ([0-9.-]{1,})\)/$1 $4 $3 $2/g'`

  clipped_filename="${original_path%.*}"_clip.tif

  # the -projwin parameter allows us to clip based on a projected extent
  # -of GTiff tells gdal_translate that our output should be in GeoTIFF format
  gdal_translate -projwin $extent -of GTiff "$current_file_path" "$clipped_filename"
  rm "$current_file_path"
  current_file_path="$clipped_filename"
}

function project_file {
  echo -e "\n*** PROJECTING INTO "$epsg_srs" ***\n"

  projected_filename="${original_path%.*}"_utm.tif
  # project the file into the specified SRS
  # -tap is important, it makes sure that our map is aligned to our pixel size
  # -tr x,y allows us to specify how many projection units / pixel. In many cases the default units are meters
  # -t_srs is how we specify our target SRS
  gdalwarp -tap -tr $meter_pixelsX $meter_pixelsY -t_srs EPSG:"$epsg_srs" "$current_file_path" "$projected_filename"
  rm "$current_file_path"
  current_file_path="$projected_filename"
}

function insert_map {
  echo -e "\n*** ADDING TABLE ("$tablename") TO DATABASE ($geodatabase_name) ***\n"

  # raster2pgsql splits our map into tiles based on the $tile parameter at the top of this document
  # -d Drops any existing table and will recreate it (c for create new, a for append)
  # -I creates a spatial index (GiST index on the raster column)
  # -M Runs a vacuum / analyze on the table after it's created
  # -t $tile is how we specify the size of the tiles (in pixels)
  raster2pgsql -s $epsg_srs -d -I -M -t $tile "$current_file_path" "public"."$tablename" | sudo -u postgres psql -d "$geodatabase_name"
  rm "$current_file_path"
  current_file_path=""
}

function detail_neatline_clip {
  echo -e "\n*** CLIPPING BY THE NEATLINE DETAIL ***\n"


  # Determine the source projection from the gdalinfo
  source_proj4=`gdalinfo -proj4 "$original_path" | grep -A 1 PROJ\.4 | tail -n 1 | perl -p -e "s/'//g"`

  # Create a GeoJSON version of the neatline for ogr2ogr to reproject
  neatline_sql="SELECT ST_AsGeoJSON(ST_PolygonFromText('$neatline'))"
  neatline_geojson=`sudo -u postgres psql -d $geodatabase_name -Atc "$neatline_sql"`

  # This is a cool trick to get ogr2ogr to output a geometry in WKT format, it also projects the neatline into our target SRS
  # reprojected_neatline cleans up some headers from the CSV output above
  csv_neatline=`ogr2ogr -f CSV -s_srs "$source_proj4" -t_srs "EPSG:$epsg_srs" -lco "GEOMETRY=AS_WKT" /dev/stdout /dev/stdin <<< $neatline_geojson`
  reprojected_neatline=`echo $csv_neatline | perl -p -e "s/^WKT \"|\"$/'/g"`

  # The SQL commands that will be run
  # Clip any raster tiles that extent beyond the neatline
  clip_sql="UPDATE \"$tablename\" SET rast = ST_Clip(rast, ST_PolygonFromText($reprojected_neatline, $epsg_srs), true);"
  # Delete any raster tiles that are empty (in the case that they are entirely beyond the neatline)
  remove_sql="DELETE FROM \"$tablename\" WHERE ST_IsEmpty(rast);"

  # Run the SQL commands
  sudo -u postgres psql -d $geodatabase_name -Atc "$clip_sql"
  sudo -u postgres psql -d $geodatabase_name -Atc "$remove_sql"
}

# Run the functions
create_current_file
get_neatline
clip_neatline
project_file
insert_map
detail_neatline_clip

echo -e "\n*** COMPLETED ***\n"
