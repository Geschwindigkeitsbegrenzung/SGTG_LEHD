
--Transform from NAD83 (4269) to NAD_1983_UTM_Zone_11N (26911)
ALTER TABLE tl_2010_06_bg10 
  ALTER COLUMN bg_geom TYPE geometry(MultiPolygon,26911) 
    USING ST_Transform(bg_geom,26911);

DROP INDEX tl_2010_06_bg10_gist;
CREATE INDEX tl_2010_06_bg10_gist
  ON tl_2010_06_bg10
  USING gist
  (bg_geom);

--Transform from NAD83 (4269) to NAD_1983_UTM_Zone_11N (26911)
ALTER TABLE final_30_site_points 
  ALTER COLUMN site_geom TYPE geometry(PointZM,26911) 
    USING ST_Transform(site_geom,26911);

DROP INDEX final_30_site_points_gist;
CREATE INDEX final_30_site_points_gist
  ON final_30_site_points
  USING gist
  (site_geom);


------------------------------------------------Build table for Census 2010 total population data and import-------------------------------------------

--DROP TABLE DEC_10_SF1_P1_total_pop;

CREATE TABLE DEC_10_SF1_P1_total_pop
	(
	  "census_geoid"	character varying(11),
	  "label"		character varying(100),
	  "total_pop"		integer
	)
	WITH (
	  OIDS=FALSE
	);
ALTER TABLE DEC_10_SF1_P1_total_pop
OWNER TO postgres;

--Importing the ACS data from csv file.
COPY DEC_10_SF1_P1_total_pop
  (
  census_geoid,label,total_pop
  )
FROM 'C:/lehd_data_ca/DEC_10_SF1_P1_total_pop.csv'
WITH CSV HEADER;


------------------------------------------------Join ACS data to the 2010 BLOCK GROUP shapefile----------------------------------------------------------

--Add new geoid column.
ALTER TABLE tl_2010_06_bg10
  ADD COLUMN bg_geoid 	character varying(11);

--Calculate new geoid in the census_geoid column (this is done since the geoid in the 2010 BLOCK GROUP shapefile has an extra '0' at the beginning).
UPDATE tl_2010_06_bg10
  SET bg_geoid = RIGHT("geoid10", 11);

--DROP TABLE tl_2010_06_bg10_tot_pop;

--Create new table with ACS total population joined to the block group shapefile.
CREATE TABLE tl_2010_06_bg10_tot_pop AS
  SELECT tl_2010_06_bg10.*, DEC_10_SF1_P1_total_pop.census_geoid, DEC_10_SF1_P1_total_pop.total_pop
  FROM tl_2010_06_bg10
  INNER JOIN DEC_10_SF1_P1_total_pop
  ON tl_2010_06_bg10.bg_geoid = DEC_10_SF1_P1_total_pop.census_geoid;


------------------------------------------------Calculate the area in terms of square meters for each 2010 BLOCK GROUP------------------------------------------------

--Add new geoid column.
ALTER TABLE tl_2010_06_bg10_tot_pop
  ADD COLUMN bg_sqmeters 	double precision;

--Calculate the area in terms of square meters for each 2010 BLOCK GROUP
UPDATE tl_2010_06_bg10_tot_pop
  SET bg_sqmeters = ST_Area(ST_Transform(tl_2010_06_bg10_tot_pop.bg_geom,4269), TRUE);


------------------------------------------------Create 1/2 mile buffers for each site------------------------------------------------

--DROP TABLE final_30_site_buffers;

CREATE TABLE final_30_site_buffers
	(
	  name 		character varying(254),
	  latitude	double precision,
	  longitude	double precision,
	  buff_geom 	geometry	(Polygon,26911)  --NAD_1983_UTM_Zone_11N (26911)
	)
	WITH (
	  OIDS=FALSE
	);
ALTER TABLE final_30_site_buffers
OWNER TO postgres;

INSERT INTO final_30_site_buffers (name, latitude, longitude, buff_geom) 
  SELECT name, latitude, longitude, ST_Buffer(site_geom, 804.672)   --0.5 mile = 804.672 meters
  FROM final_30_site_points;

--DROP INDEX final_30_site_buffers_gist;
CREATE INDEX final_30_site_buffers_gist
  ON final_30_site_buffers
  USING gist
  (buff_geom);


------------------------------------------------Clip only the BLOCK GROUPS that intersect the site buffer zones------------------------------------------------

--DROP TABLE tl_2010_06_bg10_tot_pop_clipped;

CREATE TABLE tl_2010_06_bg10_tot_pop_clipped AS 
   SELECT tl_2010_06_bg10_tot_pop.bg_geoid, tl_2010_06_bg10_tot_pop.bg_sqmeters, tl_2010_06_bg10_tot_pop.total_pop, final_30_site_buffers.name, ST_Intersection(ST_Transform(tl_2010_06_bg10_tot_pop.bg_geom,4269), ST_Transform(final_30_site_buffers.buff_geom,4269)) geom
   FROM tl_2010_06_bg10_tot_pop 
   JOIN final_30_site_buffers
   ON ST_Intersects(ST_Transform(tl_2010_06_bg10_tot_pop.bg_geom,4269), ST_Transform(final_30_site_buffers.buff_geom,4269)); 


------------------------------------------------Calculate the area (square meters) for each newly clipped 2013 BLOCK GROUP------------------------------------------------

--Add new geoid column.
ALTER TABLE tl_2010_06_bg10_tot_pop_clipped
  ADD COLUMN new_bg_sqmeters 	double precision;

--Calculate the area in terms of square meters for each 2010 BLOCK
UPDATE tl_2010_06_bg10_tot_pop_clipped
  SET new_bg_sqmeters = ST_Area(ST_Transform(tl_2010_06_bg10_tot_pop_clipped.geom,4269), TRUE);


------------------------------------------------Calculate the proportion of area for the newly clipped 2013 BLOCK GROUPS------------------------------------------------

--Add new geoid column.
ALTER TABLE tl_2010_06_bg10_tot_pop_clipped
  ADD COLUMN area_proportion 	double precision;

--Calculate the area in terms of square meters for each 2010 BLOCK
UPDATE tl_2010_06_bg10_tot_pop_clipped
  SET area_proportion = (new_bg_sqmeters/bg_sqmeters);


------------------------------------------------Calculate the new population based on the proportion of area------------------------------------------------

--Add new geoid column.
ALTER TABLE tl_2010_06_bg10_tot_pop_clipped
  ADD COLUMN new_total_pop 	integer;

--Calculate the area in terms of square meters for each 2010 BLOCK
UPDATE tl_2010_06_bg10_tot_pop_clipped
  SET new_total_pop = (total_pop*area_proportion);


------------------------------------------------Sum the total population per site----------------------------------------------------------------------------

--DROP TABLE tot_2010_pop_per_site;

CREATE TABLE tot_2010_pop_per_site AS
  SELECT SUM(tl_2010_06_bg10_tot_pop_clipped.new_total_pop) AS total_population_per_site, tl_2010_06_bg10_tot_pop_clipped.name
  FROM tl_2010_06_bg10_tot_pop_clipped
  GROUP BY tl_2010_06_bg10_tot_pop_clipped.name;


------------------------------------------------Export tables to csv files------------------------------------------------------------------------------------------------

--population csv file
COPY 	(	
	  SELECT SUM(tl_2010_06_bg10_tot_pop_clipped.new_total_pop) AS total_population_per_site, tl_2010_06_bg10_tot_pop_clipped.name
	  FROM tl_2010_06_bg10_tot_pop_clipped
	  GROUP BY tl_2010_06_bg10_tot_pop_clipped.name
	)
TO 'C:/lehd_data_ca/results/total_2010_population_per_site.csv' CSV HEADER;


------------------------------------------------Transform 2013 BLOCK GROUP shapefile and site points back to NAD83 (4269)------------------------------------------------


--Transform from NAD_1983_UTM_Zone_11N (26911) to NAD83 (4269)
ALTER TABLE tl_2010_06_bg10 
  ALTER COLUMN bg_geom TYPE geometry(MultiPolygon,4269) 
    USING ST_Transform(bg_geom,4269);

DROP INDEX tl_2010_06_bg10_gist;
CREATE INDEX tl_2010_06_bg10_gist
  ON tl_2010_06_bg10
  USING gist
  (bg_geom);

--Transform from NAD_1983_UTM_Zone_11N (26911) to NAD83 (4269)
ALTER TABLE final_30_site_points 
  ALTER COLUMN site_geom TYPE geometry(PointZM,4269) 
    USING ST_Transform(site_geom,4269);

DROP INDEX final_30_site_points_gist;
CREATE INDEX final_30_site_points_gist
  ON final_30_site_points
  USING gist
  (site_geom);
