# PostgreSQL Tutorials

## Category Trees
A proof of concept category tree implementation showcasing amongst other things:
* CHECK constraints
* VIEWs
* CTEs (Common Table Expressions)/WITH clauses
* Use of RECURSIVE in CTEs
* WINDOW functions
* Stored procedures
* MATERIALIZED VIEWs

## Momoko

Asynchronous all the way with Tornado and Momoko, a library exposing Psycopg2's asynchronous functionality for use with Tornado's eventloop.

## Links

* PostgreSQL: https://www.postgresql.org/
* PostgreSQL Exercises: https://pgexercises.com/
* pgcli (CLI for PostgreSQL with auto-completion and syntax highlighting): http://pgcli.com/
* PostgreSQL vs MS SQL: http://www.pg-versus-ms.com/
* WITH-clause performance considerations: http://modern-sql.com/feature/with/performance
* Ways to paginate: https://www.citusdata.com/blog/2016/03/30/five-ways-to-paginate/
* Modern SQL Window Function Questions: http://www.windowfunctions.com/
* Temporal Tables (SQL `AS OF`): http://clarkdave.net/2015/02/historical-records-with-postgresql-and-temporal-tables-and-sql-2011/
* Histograms: https://tapoueh.org/blog/2014/02/postgresql-aggregates-and-histograms/
* Low level PostgreSQL info: https://erthalion.info/2019/12/06/postgresql-stay-curious/
* Odyssey - Advanced multi-threaded PostgreSQL connection pooler and request router: https://github.com/yandex/odyssey
* pgwatch2 - Metrics collector and dashboard for PostgreSQL: https://github.com/cybertec-postgresql/pgwatch2 https://demo.pgwatch.com/
* Excellent documentation regarding PostgrSQL indexes: https://habr.com/en/company/postgrespro/blog/441962/
* Automated failover: https://github.com/citusdata/pg_auto_failover
* Distributed PostgreSQL: https://www.citusdata.com/
* Regression testing: https://github.com/dimitri/regresql


## Tips

### pgadmin4 quickstart
```bash
virtualenv venv --python=python3.6
./venv/bin/pip install https://ftp.postgresql.org/pub/pgadmin/pgadmin4/v2.1/pip/pgadmin4-2.1-py2.py3-none-any.whl
./venv/bin/python ./venv/lib/python3.6/site-packages/pgadmin4/pgAdmin4.py
```

### Index-related info
From https://wiki.postgresql.org/wiki/Index_Maintenance

#### Index summary
```
SELECT pg_class.relname,
       pg_size_pretty(pg_class.reltuples::BIGINT) AS rows_in_bytes,
       pg_class.reltuples AS num_rows,
       COUNT(indexname) AS number_of_indexes,
       CASE WHEN x.is_unique = 1 THEN 'Y' ELSE 'N' END AS UNIQUE,
       SUM(CASE WHEN number_of_columns = 1 THEN 1 ELSE 0 END) AS single_column,
       SUM(CASE 
           WHEN number_of_columns IS NULL THEN 0
           WHEN number_of_columns = 1 THEN 0
           ELSE 1
           END) AS multi_column
  FROM pg_namespace 
  LEFT OUTER JOIN pg_class 
    ON pg_namespace.oid = pg_class.relnamespace
  LEFT OUTER JOIN (
      SELECT indrelid,
             MAX(CAST(indisunique AS INTEGER)) AS is_unique
        FROM pg_index
       GROUP BY indrelid) x 
    ON pg_class.oid = x.indrelid
  LEFT OUTER JOIN (
      SELECT c.relname AS ctablename, 
             ipg.relname AS indexname, 
             x.indnatts AS number_of_columns 
        FROM pg_index x
        JOIN pg_class c ON c.oid = x.indrelid
        JOIN pg_class ipg ON ipg.oid = x.indexrelid) AS foo 
    ON pg_class.relname = foo.ctablename
 WHERE pg_namespace.nspname='public'
   AND pg_class.relkind = 'r'
 GROUP BY pg_class.relname, pg_class.reltuples, x.is_unique
 ORDER BY 2;
```

#### Index size/usage
```
SELECT t.schemaname,
       t.tablename,
       indexname,
       c.reltuples AS num_rows,
       pg_size_pretty(pg_relation_size(quote_ident(t.schemaname)::text || '.' || quote_ident(t.tablename)::text)) AS table_size,
       pg_size_pretty(pg_relation_size(quote_ident(t.schemaname)::text || '.' || quote_ident(indexrelname)::text)) AS index_size,
       CASE WHEN indisunique THEN 'Y' ELSE 'N' END AS UNIQUE,
       number_of_scans,
       tuples_read,
       tuples_fetched
  FROM pg_tables t
  LEFT OUTER JOIN pg_class c ON t.tablename = c.relname
  LEFT OUTER JOIN (
      SELECT c.relname AS ctablename,
             ipg.relname AS indexname,
             x.indnatts AS number_of_columns,
             idx_scan AS number_of_scans,
             idx_tup_read AS tuples_read,
             idx_tup_fetch AS tuples_fetched,
             indexrelname,
             indisunique,
             schemaname
        FROM pg_index x
        JOIN pg_class c ON c.oid = x.indrelid
        JOIN pg_class ipg ON ipg.oid = x.indexrelid
        JOIN pg_stat_all_indexes psai ON x.indexrelid = psai.indexrelid) AS foo 
          ON t.tablename = foo.ctablename AND t.schemaname = foo.schemaname
       WHERE t.schemaname NOT IN ('pg_catalog', 'information_schema')
 ORDER BY 1,2;
```

#### Duplicate indexes
```
SELECT pg_size_pretty(SUM(pg_relation_size(idx))::BIGINT) AS SIZE,
       (array_agg(idx))[1] AS idx1, (array_agg(idx))[2] AS idx2,
       (array_agg(idx))[3] AS idx3, (array_agg(idx))[4] AS idx4
  FROM (
      SELECT indexrelid::regclass AS idx, (indrelid::text ||E'\n'|| indclass::text ||E'\n'|| indkey::text ||E'\n'||
                                         COALESCE(indexprs::text,'')||E'\n' || COALESCE(indpred::text,'')) AS KEY
        FROM pg_index) sub
 GROUP BY KEY HAVING COUNT(*)>1
 ORDER BY SUM(pg_relation_size(idx)) DESC;
```

#### Vacuum/Analyze info
```
SELECT schemaname, 
       relname, 
       n_live_tup, 
       n_dead_tup, 
       last_analyze,
       last_vacuum 
  FROM pg_stat_all_tables 
 ORDER BY schemaname, relname, last_vacuum DESC NULLS LAST;
```

