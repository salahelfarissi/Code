# r_tree.py
"""Display r-tree bboxes"""
from psycopg2 import connect
from func import *  # user defined functions

# Use connect class to establish connection to PostgreSQL
conn = connect("""
    host=localhost
    dbname=nyc
    user=postgres
    """)

cur = conn.cursor()

cur.execute("""
    WITH gt_name AS (
        SELECT
            f_table_name AS t_name
        FROM geometry_columns
    )
    SELECT
        CAST(c.oid AS INTEGER) as "OID",
        c.relname as "INDEX"
    FROM pg_class c, pg_index i
    WHERE c.oid = i.indexrelid
    AND c.relname IN (
        SELECT
            relname
        FROM pg_class, pg_index
        WHERE pg_class.oid = pg_index.indexrelid
        AND pg_class.oid IN (
            SELECT
                indexrelid
            FROM pg_index, pg_class
            WHERE pg_class.relname IN (
                SELECT t_name
                FROM gt_name)
            AND pg_class.oid = pg_index.indrelid
            AND indisunique != 't'
            AND indisprimary != 't' ));
            """)

indices = cur.fetchall()

# Display a two column table with index and oid
w1, w2 = field_width(indices)

print(f'\n{"Index":>{w1}}{"OID":>{w2}}', '-'*(w1 + w2), sep='\n')

for oid, name in indices:
    print(f'{name:>{w1}}{oid:>{w2}}')

# Ask the user which index to visualize
try:
    idx_oid = int(input("""
        \nWhich GiST index do you want to visualize?\nOID → """))
except ValueError:
    idx_oid = int(input("""
        \nYou must enter an integer value!\nOID → """))

cur.execute("""
    SELECT 
        srid
    FROM geometry_columns
    WHERE f_table_name IN (
	    SELECT tablename FROM indices
	    JOIN pg_indexes
        ON idx_name = indexname
	    WHERE idx_oid::integer = %s);
    """,
            [idx_oid])

g_srid = cur.fetchone()

cur.execute(f"SELECT gist_stat({idx_oid});")
stat = cur.fetchone()

stat = unpack(stat)

print(f"\nNumber of levels → {stat['Levels']}\n")
level = int(input("Level to visualize \n↳ "))

cur.execute("""
    DROP TABLE IF EXISTS r_tree;
    """)

cur.execute("""
    CREATE TABLE r_tree (
        id serial primary key,
        geom geometry(POLYGON, %s));
    """,
    [g_srid[0]])

cur.execute("""
    INSERT INTO r_tree (geom)
    SELECT st_setsrid(replace(a::text, '2DF', '')::box2d::geometry, %s)
    FROM (SELECT * FROM gist_print(%s) as t(level int, valid bool, a box2df) WHERE level = %s) AS subq
    """,
            [g_srid[0], idx_oid, level])

conn.commit()

cur.execute("END TRANSACTION;")
cur.execute("VACUUM ANALYZE r_tree;")
cur.execute("NOTIFY qgis;")

cur.close()
conn.close()
