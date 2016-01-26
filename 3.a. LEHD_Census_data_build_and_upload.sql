
--Transform from NAD83 (4269) to NAD_1983_UTM_Zone_11N (26911)
ALTER TABLE tl_2010_06_tabblock10 
  ALTER COLUMN blk_geom TYPE geometry(MultiPolygon,26911) 
    USING ST_Transform(blk_geom,26911);

DROP INDEX tl_2010_06_tabblock10_gist;
CREATE INDEX tl_2010_06_tabblock10_gist
  ON tl_2010_06_tabblock10
  USING gist
  (blk_geom);

--Transform from NAD83 (4269) to NAD_1983_UTM_Zone_11N (26911)
ALTER TABLE final_30_site_points 
  ALTER COLUMN site_geom TYPE geometry(PointZM,26911) 
    USING ST_Transform(site_geom,26911);

DROP INDEX final_30_site_points_gist;
CREATE INDEX final_30_site_points_gist
  ON final_30_site_points
  USING gist
  (site_geom);


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


------------------------------------------------Create the BLOCK ID------------------------------------------------------------------------------------------------

--Add new geoid column.
ALTER TABLE tl_2010_06_tabblock10
  ADD COLUMN blk_geoid 	character varying(14);

--Calculate new geoid in the blk_geoid column (this is done since the geoid10 in the 2010 BLOCK shapefile has an extra '0' at the beginning).
UPDATE tl_2010_06_tabblock10
  SET blk_geoid = RIGHT("geoid10", 14);


------------------------------------------------Calculate the area in terms of square meters for each 2010 BLOCK------------------------------------------------

--Add new geoid column.
ALTER TABLE tl_2010_06_tabblock10
  ADD COLUMN blk_sqmeters 	double precision;

--Calculate the area in terms of square meters for each 2010 BLOCK
UPDATE tl_2010_06_tabblock10
  SET blk_sqmeters = ST_Area(ST_Transform(tl_2010_06_tabblock10.blk_geom,4269), TRUE);


------------------------------------------------Clip only the BLOCKS that intersect the site buffer zones------------------------------------------------

DROP TABLE tl_2010_06_tabblock10_clipped;

CREATE TABLE tl_2010_06_tabblock10_clipped AS 
   SELECT tl_2010_06_tabblock10.blk_geoid, tl_2010_06_tabblock10.blk_sqmeters, final_30_site_buffers.name, ST_Intersection(ST_Transform(tl_2010_06_tabblock10.blk_geom,4269), ST_Transform(final_30_site_buffers.buff_geom,4269)) geom
   FROM tl_2010_06_tabblock10 
   JOIN final_30_site_buffers
   ON ST_Intersects(ST_Transform(tl_2010_06_tabblock10.blk_geom,4269), ST_Transform(final_30_site_buffers.buff_geom,4269)); 


------------------------------------------------Calculate the area (square meters) for each newly clipped 2010 BLOCKS------------------------------------------------

--Add new geoid column.
ALTER TABLE tl_2010_06_tabblock10_clipped
  ADD COLUMN new_blk_sqmeters 	double precision;

--Calculate the area in terms of square meters for each 2010 BLOCK.
UPDATE tl_2010_06_tabblock10_clipped
  SET new_blk_sqmeters = ST_Area(ST_Transform(tl_2010_06_tabblock10_clipped.geom,4269), TRUE);


------------------------------------------------Calculate the proportion of area for the newly clipped 2010 BLOCKS------------------------------------------------

--Add new geoid column.
ALTER TABLE tl_2010_06_tabblock10_clipped
  ADD COLUMN area_proportion 	double precision;

--Calculate the area in terms of square meters for each 2010 BLOCK.
UPDATE tl_2010_06_tabblock10_clipped
  SET area_proportion = (new_blk_sqmeters/blk_sqmeters);


------------------------------------------------Create the BLOCK GROUP ID for the LEHD RAC and WAC tables------------------------------------------------

--Change the h_geocode column data type to character varying(14).
--ALTER TABLE lehd_rac
--  ALTER COLUMN h_geocode TYPE character varying(14)
--  USING h_geocode::character varying(14);

--Change the w_geocode column data type to character varying(14).
--ALTER TABLE lehd_wac
--  ALTER COLUMN w_geocode TYPE character varying(14)
--  USING w_geocode::character varying(14);


------------------------------------------------Join LEHD data to the newly clipped 2010 BLOCK shapefile----------------------------------------------------------

DROP TABLE tl_2010_06_tabblock10_clipped_tot_rac;

--Create new table with LEHD total residents (RAC) joined to the 2010 BLOCK shapefile.
CREATE TABLE tl_2010_06_tabblock10_clipped_tot_rac AS
  SELECT tl_2010_06_tabblock10_clipped.*, lehd_rac.h_geocode, lehd_rac."C000" AS residents
  FROM tl_2010_06_tabblock10_clipped
  LEFT JOIN lehd_rac
  ON tl_2010_06_tabblock10_clipped.blk_geoid = lehd_rac.h_geocode
  WHERE seg = 'S000' AND jt = 0;  --"seg=S000" is the total number of jobs & "jt=0" is for all jobs.

DROP TABLE tl_2010_06_tabblock10_clipped_tot_wac;

--Create new table with LEHD total employees (WAC) joined to the 2010 BLOCK shapefile.
CREATE TABLE tl_2010_06_tabblock10_clipped_tot_wac AS
  SELECT tl_2010_06_tabblock10_clipped.*, lehd_wac.w_geocode, lehd_wac."C000" AS employees
  FROM tl_2010_06_tabblock10_clipped
  LEFT JOIN lehd_wac
  ON tl_2010_06_tabblock10_clipped.blk_geoid = lehd_wac.w_geocode
  WHERE seg = 'S000' AND jt = 0;  --"seg=S000" is the total number of jobs & "jt=0" is for all jobs.


------------------------------------------------Calculate the remaining residents and employees totals based on the proportion of area------------------------------------------------

--Add new remaining residents total column.
ALTER TABLE tl_2010_06_tabblock10_clipped_tot_rac
  ADD COLUMN remaining_residents_total 	integer;

--Calculate the new remaining residents totals based on the proportion of area per site.
UPDATE tl_2010_06_tabblock10_clipped_tot_rac
  SET remaining_residents_total = (residents*area_proportion);

--Add new remaining employees totalcolumn.
ALTER TABLE tl_2010_06_tabblock10_clipped_tot_wac
  ADD COLUMN remaining_employees_total 	integer;

--Calculate the new remaining employees totals based on the proportion of area per site.
UPDATE tl_2010_06_tabblock10_clipped_tot_wac
  SET remaining_employees_total = (employees*area_proportion);


------------------------------------------------Sum the total residents and employees per site----------------------------------------------------------------------------

DROP TABLE tot_rac_per_site;

CREATE TABLE tot_rac_per_site AS
  SELECT SUM(tl_2010_06_tabblock10_clipped_tot_rac.remaining_residents_total) AS total_residents_per_site, tl_2010_06_tabblock10_clipped_tot_rac.name
  FROM tl_2010_06_tabblock10_clipped_tot_rac
  GROUP BY tl_2010_06_tabblock10_clipped_tot_rac.name;

DROP TABLE tot_wac_per_site;

CREATE TABLE tot_wac_per_site AS
  SELECT SUM(tl_2010_06_tabblock10_clipped_tot_wac.remaining_employees_total) AS total_employees_per_site, tl_2010_06_tabblock10_clipped_tot_wac.name
  FROM tl_2010_06_tabblock10_clipped_tot_wac
  GROUP BY tl_2010_06_tabblock10_clipped_tot_wac.name;


------------------------------------------------Export tables to csv files------------------------------------------------------------------------------------------------

--residents csv file
COPY 	(	
	  SELECT SUM(tl_2010_06_tabblock10_clipped_tot_rac.remaining_residents_total) AS total_residents_per_site, tl_2010_06_tabblock10_clipped_tot_rac.name
	  FROM tl_2010_06_tabblock10_clipped_tot_rac
	  GROUP BY tl_2010_06_tabblock10_clipped_tot_rac.name
	)
TO 'C:/lehd_data_ca/results/total_residents_per_site.csv' CSV HEADER;

--employees csv file
COPY 	(	
	  SELECT SUM(tl_2010_06_tabblock10_clipped_tot_wac.remaining_employees_total) AS total_employees_per_site, tl_2010_06_tabblock10_clipped_tot_wac.name
	  FROM tl_2010_06_tabblock10_clipped_tot_wac
	  GROUP BY tl_2010_06_tabblock10_clipped_tot_wac.name
	)
TO 'C:/lehd_data_ca/results/total_employees_per_site.csv' CSV HEADER;


------------------------------------------------Transform 2010 BLOCK shapefile and site points back to NAD83 (4269)------------------------------------------------

--Transform from NAD_1983_UTM_Zone_11N (26911) to NAD83 (4269).
ALTER TABLE tl_2010_06_tabblock10 
  ALTER COLUMN blk_geom TYPE geometry(MultiPolygon,4269) 
    USING ST_Transform(blk_geom,4269);

DROP INDEX tl_2010_06_tabblock10_gist;
CREATE INDEX tl_2010_06_tabblock10_gist
  ON tl_2010_06_tabblock10
  USING gist
  (blk_geom);

--Transform from NAD_1983_UTM_Zone_11N (26911) to NAD83 (4269).
ALTER TABLE final_30_site_points 
  ALTER COLUMN site_geom TYPE geometry(PointZM,4269) 
    USING ST_Transform(site_geom,4269);

DROP INDEX final_30_site_points_gist;
CREATE INDEX final_30_site_points_gist
  ON final_30_site_points
  USING gist
  (site_geom);
