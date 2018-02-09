# PostgreSQL Tutorials

## Category Trees
A proof of concept category tree implementation showcasing amongst other things:
* CHECK constraints
* VIEWs
* CTEs (Common Table Expressions)/WITH clauses
* Use of RECURSIVE in CTEs
* WINDOW functions
* Stored procedures

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

## Tips

### pgadmin4 quickstart
```bash
./venv/bin/pip install https://ftp.postgresql.org/pub/pgadmin/pgadmin4/v1.6/pip/pgadmin4-1.6-py2.py3-none-any.whl
./venv/bin/python ./venv/lib/python2.7/site-packages/pgadmin4/pgAdmin4.py
```
