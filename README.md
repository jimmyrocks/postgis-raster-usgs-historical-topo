This is a collection of bash scripts used to extract USGS Historical Topo maps and insert them into PostGIS as rasters.

The USGS Historical Topo Maps can be downloaded from:
* [The National Map Viewer](http://viewer.nationalmap.gov)
* [The USGS ScienceBase Catalog](https://www.sciencebase.gov/catalog/)

The USGS has a [great document (pdf)](http://nationalmap.gov/ustopo/documents/ustopo2gtif_current.pdf) explaining how to use GDAL to work with the USGS Topo Maps.
This document helped me get a start on this project.

# Usage
1. Install GDAL/ogr tools, I created [a script](https://github.com/jimmyrocks/dotfiles/blob/master/geo_install.sh) to do this
2. Install PostgreSQL 9.4 with PostGIS 2.1 (other versions may work, but that's what I'm running).
   You can probably do this with the command: `sudo apt-get install postgresql-9.4-postgis-2.1`
3. Create your database for all your rasters:
   `sudo -u postgres psql -c "CREATE DATABASE topo;"`
4. Geospatially enabled this database:
   `sudo -u postgres psql -d topo -c "CREATE EXTENSION postgis;"`
5. You need to enable the gdal drivers, which was a little hard to figure out, but there's a discussion on how to do it [here](http://comments.gmane.org/gmane.comp.gis.postgis/37510).
6. Now you're ready to start adding some topos! If you haven't already, clone this repository.
7. Download a USGS topo map (you can use [this one of Lambertville, NJ](http://ims.er.usgs.gov/gda_services/download?item_id=5377298) if you'd like)
8. Run the import_zip.sh script on the zip file. Example:
   `bash ./import_zip.sh ./NJ_Lambertville_255237_1890_62500_geo.zip`
9. The raster should now be in your database! Getting the data out can be tricky, but there's [a guide](http://postgis.net/docs/using_raster_dataman.html#RasterOutput_PSQL) on it.

Enjoy!
