create database postgis;
-- \c postgis
create SCHEMA postgis;
CREATE EXTENSION postgis SCHEMA postgis;
-- setting postgis db as template
UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'postgis';
-- 
create database mono template postgis;
ALTER DATABASE mono SET search_path='$user', public, postgis;
--
select srid, proj4text from spatial_ref_sys where srtext like '%WGS_1984%';
--
shp2pgsql -s 4326 -g geom -I .\regions.shp regions | psql -U elfarissi -d mono
shp2pgsql -s 4326 -g geom -I .\provinces.shp provinces | psql -U elfarissi -d mono
shp2pgsql -s 4326 -g geom -I .\communes.shp communes | psql -U elfarissi -d mono
-- update statistics
vacuum analyze regions, provinces, communes;
--
delete from regions where code_regio is null;
--
ALTER TABLE regions
RENAME COLUMN code_regio TO r_code;
--
ALTER TABLE regions
RENAME COLUMN nom_region TO r_nom;
--
ALTER TABLE regions
DROP COLUMN gid,
DROP COLUMN objectid,
DROP COLUMN population,
DROP COLUMN menages,
DROP COLUMN etrangers,
DROP COLUMN marocains,
DROP COLUMN ruleid,
DROP COLUMN shape__are,
DROP COLUMN shape__len;
--
alter table regions
alter column r_code type varchar(3);
--
ALTER TABLE regions ADD COLUMN id serial primary key;
--
update communes
set nom_commun = upper(nom_commun);
--
select * 
into c_09
from communes where c_code like '09.%';
--
select * 
into p_09
from provinces where p_code like '09.%';
--
select * 
into r_09
from regions
where r_code = '09.';
--
CREATE INDEX r_09_geom_idx
ON r_09
USING gist(geom);
--
update p_09 set menages = case
when p_nom = 'AGADIR IDA OU TANAN' then 163283
when p_nom = 'CHTOUKA AIT BAHA' then 99852
when p_nom = 'INEZGANE AIT MELLOUL' then 142549
when p_nom = 'TAROUDANNT' then 180895
when p_nom = 'TATA' then 22675
when p_nom = 'TIZNIT' then 52671
end;
-- Q1
select p_nom, menages from p_09
order by menages desc
limit 1;
--
ALTER TABLE p_09
ALTER COLUMN geom TYPE geometry(MULTIPOLYGON, 26192) USING ST_Transform(ST_SetSRID(geom,4326),26192);
--
ALTER TABLE p_09
ADD COLUMN menages_04 integer;
--
update p_09 set menages_04 = case
when p_nom = 'AGADIR IDA OU TANAN' then 103395
when p_nom = 'CHTOUKA AIT BAHA' then 61419
when p_nom = 'INEZGANE AIT MELLOUL' then 87786
when p_nom = 'TAROUDANNT' then 138054
when p_nom = 'TATA' then 20349
when p_nom = 'TIZNIT' then 45188
end;
-- Q2
select sum(menages_04) menages_04, sum(menages_14) menages_14 from p_09;

 menages_04 | menages_14
------------+------------
     456191 |     601511

-- Q3
SELECT
	SubStr(c.c_code,1,7) AS p_id,
	p.p_nom,
 	count(*) AS c_nbre,
	ST_Union(c.geom) AS geom
FROM c_09 c
JOIN p_09 p
ON SubStr(c_code,1,7) = p_code
GROUP BY p_id, p.p_nom
order by c_nbre desc
limit 1;

  p_id   |   p_nom    | c_nbre
---------+------------+--------
 09.541. | TAROUDANNT |     89

 -- Q4
 SELECT
	SubStr(p.p_code,1,3) AS r_id,
	r.r_nom,
 	count(*) AS p_nbre,
	ST_Equals(ST_Union(p.geom), r.geom),
	ST_Union(p.geom) AS geom
FROM p_09 p
JOIN r_09 r
ON SubStr(p_code,1,3) = r_code
GROUP BY r_id, r.r_nom, r.geom
order by p_nbre desc;

r_id |    r_nom    | p_nbre | st_equals
------+-------------+--------+-----------
 09.  | SOUSS-MASSA |      6 | t

 -- Other method

 -- Make the region table
CREATE TABLE r_geoms AS
SELECT
  ST_Union(geom) AS geom,
  SubStr(p_code,1,3) AS r_id
FROM p_09
GROUP BY r_id;

-- Index the r_id
CREATE INDEX r_geoms_r_id_idx
  ON r_geoms (r_id);

-- Test equality of geoms
select st_equals(r.geom, g.geom)
from r_09 r, r_geoms g
where r.r_code = g.r_id;

 st_equals
-----------
 t