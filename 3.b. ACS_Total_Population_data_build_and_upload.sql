
--Transform from NAD83 (4269) to NAD_1983_UTM_Zone_11N (26911)
ALTER TABLE tl_2013_06_bg 
  ALTER COLUMN bg_geom TYPE geometry(MultiPolygon,26911) 
    USING ST_Transform(bg_geom,26911);

--DROP INDEX tl_2013_06_bg_gist;
CREATE INDEX tl_2013_06_bg_gist
  ON tl_2013_06_bg
  USING gist
  (bg_geom);

--Transform from NAD83 (4269) to NAD_1983_UTM_Zone_11N (26911)
ALTER TABLE final_30_site_points 
  ALTER COLUMN site_geom TYPE geometry(PointZM,26911) 
    USING ST_Transform(site_geom,26911);

--DROP INDEX final_30_site_points_gist;
CREATE INDEX final_30_site_points_gist
  ON final_30_site_points
  USING gist
  (site_geom);


------------------------------------------------Build table for ACS 2013 5-year total population data and import-------------------------------------------

--DROP TABLE acs_13_5yr_b01003_total_pop;

CREATE TABLE acs_13_5yr_b01003_total_pop
	(
	  "acs_geoid"	character varying(11),
	  "label"	character varying(100),
	  "pop_tot"	integer,
	  "moe"		integer
	)
	WITH (
	  OIDS=FALSE
	);
ALTER TABLE acs_13_5yr_b01003_total_pop
OWNER TO postgres;

--Importing the ACS data from csv file.
COPY acs_13_5yr_b01003_total_pop
  (
  acs_geoid,label,pop_tot,moe
  )
FROM 'C:/lehd_data_ca/acs_13_5yr_b01003_total_pop.csv'
WITH CSV HEADER;


------------------------------------------------Join ACS data to the 2013 BLOCK GROUP shapefile----------------------------------------------------------

--Add new geoid column.
ALTER TABLE tl_2013_06_bg
  ADD COLUMN bg_geoid 	character varying(11);

--Calculate new geoid in the acs_geoid column (this is done since the geoid in the 2013 BLOCK GROUP shapefile has an extra '0' at the beginning).
UPDATE tl_2013_06_bg
  SET bg_geoid = RIGHT("geoid", 11);

--DROP TABLE tl_2013_06_bg_tot_pop;

--Create new table with ACS total population joined to the block group shapefile.
CREATE TABLE tl_2013_06_bg_tot_pop AS
  SELECT tl_2013_06_bg.*, acs_13_5yr_b01003_total_pop.acs_geoid, acs_13_5yr_b01003_total_pop.pop_tot, acs_13_5yr_b01003_total_pop.moe
  FROM tl_2013_06_bg
  INNER JOIN acs_13_5yr_b01003_total_pop
  ON tl_2013_06_bg.bg_geoid = acs_13_5yr_b01003_total_pop.acs_geoid;


------------------------------------------------Calculate the area in terms of square meters for each 2013 BLOCK GROUP------------------------------------------------

--Add new geoid column.
ALTER TABLE tl_2013_06_bg_tot_pop
  ADD COLUMN bg_sqmeters 	double precision;

--Calculate the area in terms of square meters for each 2010 BLOCK
UPDATE tl_2013_06_bg_tot_pop
  SET bg_sqmeters = ST_Area(ST_Transform(tl_2013_06_bg_tot_pop.bg_geom,4269), TRUE);


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

--DROP TABLE tl_2013_06_bg_tot_pop_clipped;

CREATE TABLE tl_2013_06_bg_tot_pop_clipped AS 
   SELECT tl_2013_06_bg_tot_pop.bg_geoid, tl_2013_06_bg_tot_pop.bg_sqmeters, tl_2013_06_bg_tot_pop.pop_tot, final_30_site_buffers.name, ST_Intersection(ST_Transform(tl_2013_06_bg_tot_pop.bg_geom,4269), ST_Transform(final_30_site_buffers.buff_geom,4269)) geom
   FROM tl_2013_06_bg_tot_pop 
   JOIN final_30_site_buffers
   ON ST_Intersects(ST_Transform(tl_2013_06_bg_tot_pop.bg_geom,4269), ST_Transform(final_30_site_buffers.buff_geom,4269)); 


------------------------------------------------Calculate the area (square meters) for each newly clipped 2013 BLOCK GROUP------------------------------------------------

--Add new geoid column.
ALTER TABLE tl_2013_06_bg_tot_pop_clipped
  ADD COLUMN new_bg_sqmeters 	double precision;

--Calculate the area in terms of square meters for each 2010 BLOCK
UPDATE tl_2013_06_bg_tot_pop_clipped
  SET new_bg_sqmeters = ST_Area(ST_Transform(tl_2013_06_bg_tot_pop_clipped.geom,4269), TRUE);


------------------------------------------------Calculate the proportion of area for the newly clipped 2013 BLOCK GROUPS------------------------------------------------

--Add new geoid column.
ALTER TABLE tl_2013_06_bg_tot_pop_clipped
  ADD COLUMN area_proportion 	double precision;

--Calculate the area in terms of square meters for each 2010 BLOCK
UPDATE tl_2013_06_bg_tot_pop_clipped
  SET area_proportion = (new_bg_sqmeters/bg_sqmeters);


------------------------------------------------Calculate the new population based on the proportion of area------------------------------------------------

--Add new geoid column.
ALTER TABLE tl_2013_06_bg_tot_pop_clipped
  ADD COLUMN new_pop_tot 	integer;

--Calculate the area in terms of square meters for each 2010 BLOCK
UPDATE tl_2013_06_bg_tot_pop_clipped
  SET new_pop_tot = (pop_tot*area_proportion);


------------------------------------------------Sum the total population per site----------------------------------------------------------------------------

--DROP TABLE tot_2013_pop_per_site;

CREATE TABLE tot_pop_per_site AS
  SELECT SUM(tl_2013_06_bg_tot_pop_clipped.new_pop_tot) AS total_population_per_site, tl_2013_06_bg_tot_pop_clipped.name
  FROM tl_2013_06_bg_tot_pop_clipped
  GROUP BY tl_2013_06_bg_tot_pop_clipped.name;


------------------------------------------------Export tables to csv files------------------------------------------------------------------------------------------------

--population csv file
COPY 	(	
	  SELECT SUM(tl_2013_06_bg_tot_pop_clipped.new_pop_tot) AS total_population_per_site, tl_2013_06_bg_tot_pop_clipped.name
	  FROM tl_2013_06_bg_tot_pop_clipped
	  GROUP BY tl_2013_06_bg_tot_pop_clipped.name
	)
TO 'C:/lehd_data_ca/results/total_2013_population_per_site.csv' CSV HEADER;


------------------------------------------------Transform 2013 BLOCK GROUP shapefile and site points back to NAD83 (4269)------------------------------------------------


--Transform from NAD_1983_UTM_Zone_11N (26911) to NAD83 (4269)
ALTER TABLE tl_2013_06_bg 
  ALTER COLUMN bg_geom TYPE geometry(MultiPolygon,4269) 
    USING ST_Transform(bg_geom,4269);

DROP INDEX tl_2013_06_bg_gist;
CREATE INDEX tl_2013_06_bg_gist
  ON tl_2013_06_bg
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
