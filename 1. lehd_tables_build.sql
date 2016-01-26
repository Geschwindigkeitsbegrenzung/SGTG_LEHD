-- Table: lehd_rac "Residence Area Characteristics (RAC)"

-- DROP TABLE lehd_rac;

CREATE TABLE lehd_rac
(
  h_geocode double precision,
  "C000" integer,
  "CA01" integer,
  "CA02" integer,
  "CA03" integer,
  "CE01" integer,
  "CE02" integer,
  "CE03" integer,
  "CNS01" integer,
  "CNS02" integer,
  "CNS03" integer,
  "CNS04" integer,
  "CNS05" integer,
  "CNS06" integer,
  "CNS07" integer,
  "CNS08" integer,
  "CNS09" integer,
  "CNS10" integer,
  "CNS11" integer,
  "CNS12" integer,
  "CNS13" integer,
  "CNS14" integer,
  "CNS15" integer,
  "CNS16" integer,
  "CNS17" integer,
  "CNS18" integer,
  "CNS19" integer,
  "CNS20" integer,
  "CR01" integer,
  "CR02" integer,
  "CR03" integer,
  "CR04" integer,
  "CR05" integer,
  "CR07" integer,
  "CT01" integer,
  "CT02" integer,
  "CD01" integer,
  "CD02" integer,
  "CD03" integer,
  "CD04" integer,
  "CS01" integer,
  "CS02" integer,
  createdate integer,
  year integer,
  jt integer,
  seg character varying(10)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE lehd_rac
  OWNER TO postgres;


-- Table: lehd_wac "Workplace Area Characteristics (WAC)"

-- DROP TABLE lehd_wac;

CREATE TABLE lehd_wac
(
  w_geocode double precision,
  "C000" integer,
  "CA01" integer,
  "CA02" integer,
  "CA03" integer,
  "CE01" integer,
  "CE02" integer,
  "CE03" integer,
  "CNS01" integer,
  "CNS02" integer,
  "CNS03" integer,
  "CNS04" integer,
  "CNS05" integer,
  "CNS06" integer,
  "CNS07" integer,
  "CNS08" integer,
  "CNS09" integer,
  "CNS10" integer,
  "CNS11" integer,
  "CNS12" integer,
  "CNS13" integer,
  "CNS14" integer,
  "CNS15" integer,
  "CNS16" integer,
  "CNS17" integer,
  "CNS18" integer,
  "CNS19" integer,
  "CNS20" integer,
  "CR01" integer,
  "CR02" integer,
  "CR03" integer,
  "CR04" integer,
  "CR05" integer,
  "CR07" integer,
  "CT01" integer,
  "CT02" integer,
  "CD01" integer,
  "CD02" integer,
  "CD03" integer,
  "CD04" integer,
  "CS01" integer,
  "CS02" integer,
  "CFA01" integer,
  "CFA02" integer,
  "CFA03" integer,
  "CFA04" integer,
  "CFA05" integer,
  "CFS01" integer,
  "CFS02" integer,
  "CFS03" integer,
  "CFS04" integer,
  "CFS05" integer,
  createdate integer,
  year integer,
  jt integer,
  seg character varying(10)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE lehd_wac
  OWNER TO postgres;


-- Table: lehd_od "Origin-Destination (OD)"

-- DROP TABLE lehd_od;

CREATE TABLE lehd_od
(
  h_geocode double precision,
  w_geocode double precision,
  "S000" integer,
  "SA01" integer,
  "SA02" integer,
  "SA03" integer,
  "SE01" integer,
  "SE02" integer,
  "SE03" integer,
  "SI01" integer,
  "SI02" integer,
  "SI03" integer,
  createdate integer,
  year integer,
  jt integer,
  seg character varying(10)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE lehd_od
  OWNER TO postgres;
  

-- Table: tx_xwalk "Geography Crosswalk"

-- DROP TABLE ca_xwalk;

CREATE TABLE ca_xwalk
(
  "tabblk2010" double precision,
  "st" integer,
  "stusps" character varying(2),
  "stname" character varying(100),
  "cty" integer,
  "ctyname" character varying(100),
  "trct" double precision,
  "trctname" character varying(100),
  "bgrp" double precision,
  "bgrpname" character varying(100),
  "cbsa" integer,
  "cbsaname" character varying(100),
  "zcta" integer,
  "zctaname" character varying(100),
  "stplc" integer,
  "stplcname" character varying(100),
  "ctycsub" double precision,
  "ctycsubname" character varying(100),
  "stcd114" integer,
  "stcd114name" character varying(100),
  "stsldl" integer,
  "stsldlname" character varying(100),
  "stsldu" integer,
  "stslduname" character varying(100),
  "stschool" integer,
  "stschoolname" character varying(100),
  "stsecon" integer,
  "stseconname" character varying(100),
  "trib" character varying(100),
  "tribname" character varying(100),
  "tsub" integer,
  "tsubname" character varying(100),
  "stanrc" integer,
  "stanrcname" character varying(100),
  "mil" double precision,
  "milname" character varying(100),
  "stwib" integer,
  "stwibname" character varying(100),
  "createdate" integer
)
WITH (
  OIDS=FALSE
);
ALTER TABLE ca_xwalk
  OWNER TO postgres;

