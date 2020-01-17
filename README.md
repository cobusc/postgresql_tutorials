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

## Tips

### pgadmin4 quickstart
```bash
virtualenv venv --python=python3.6
./venv/bin/pip install https://ftp.postgresql.org/pub/pgadmin/pgadmin4/v2.1/pip/pgadmin4-2.1-py2.py3-none-any.whl
./venv/bin/python ./venv/lib/python3.6/site-packages/pgadmin4/pgAdmin4.py
```
