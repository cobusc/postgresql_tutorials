Category trees revisited
========================

Introduction
------------

Category trees are an important classification utility for e-commerce sites. It is allows similar products to be grouped in a single category and related categories to be grouped together, e.g.

```
Games + Platform + Xbox
      |          |
      |          + PS4
      |
      + Genre + Adventure
              |
              + Fighting
```

At the top of the tree we have a `department` with associated category trees below it.

This document contains a _proof-of-concept_ implementation with some technical bits that people may find interesting. This is for informational purposes only.

Representing the tree in an RDBMS
---------------------------------

The typical representation of a category tree is a `category` table where each entry has a unique `id` and a `parent_id` pointing to the category directly above it in the tree. If the `parent_id` is `NULL` the category is considered a top-level category.

This definition is sound and changing the `parent_id` of a category effectively means unlinking an relinking a subtree.

For the purposes of this document I will be adding a `department` table and modifying the typical representation slighty:
* A top-level category _must_ have a `parent_id` that is `NULL` and it _must_ have an associated `department_id`.
* A category that is not at the top level _must_ have a `parent_id` and it _must_ have a `department_id` that is `NULL`.

Why the condition that a category with a `parent_id` may not have a `department_id`? Well, the department is implied by the ancestor. Duplicating it at lower levels complicates moving categories around and can lead to inconsistencies. (I've seen this in TAL.)

Let's write some code:
```sql
CREATE TABLE department (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
);

-- Add some test data

INSERT INTO department(id, name) VALUES
(0, 'Department0'),
(1, 'Department1'),
(2, 'Department2');

-- A category can only be linked to a department (i.e. a top-level category)
-- or to another category, in which case the department is implied
-- by the ancestor.

CREATE TABLE category (
    id SERIAL PRIMARY KEY,
    parent_id INTEGER REFERENCES category(id),
    department_id INTEGER REFERENCES department(id),
    name TEXT NOT NULL,

    CHECK ((parent_id IS NULL AND department_id IS NOT NULL)
        OR (parent_id IS NOT NULL AND department_id IS NULL))
);

CREATE INDEX ON category(parent_id);

-- Add some test data

INSERT INTO category(id, parent_id, department_id, name) VALUES
(0, NULL, 0, '0:0'),
(1, 0, NULL, '0:0.1'),
(2, 1, NULL, '0:0.1.2'),
(3, 1, NULL, '0:0.1.3'),
(4, NULL, 1, '1:4'),
(5, 4, NULL, '1:4.5'),
(6, 5, NULL, '1:4.5.6'),
(7, 6, NULL, '1:4.5.6.7'),
(8, 7, NULL, '1:4.5.6.7.8'),
(9, NULL, 1, '1:9'),
(10, 9, NULL, '1:9.10');
```

The `name` of a category was crafted to represent the position in the tree for the purposes of this document. It has the format: `department_id:category_id.category_id...`, which will be useful to eyeball the correctness of the results in the following sections.

Leaf categories
---------------
Leaf categories are the categories at the bottom of the category tree. From the way we defined a category in the RDMS, it is not easy to construct a query to answer "give me all categories without children". It is simple, however, to say "give me all categories that are not parents". We create a view for this:

```sql
--
-- Create a view containing all the leaf categories.
--

CREATE VIEW leaf_category AS
SELECT id
  FROM category
EXCEPT
SELECT DISTINCT parent_id
  FROM category;
```

Note that we have a unique index on the `id` column (via the primary key) as well as an index on the `parent_id` column. Let's try it out:

```
# select * from leaf_category;
 id
----
 10
  8
  2
  3
(4 rows)
```

Category trees
--------------
To build a category tree for category `id`, a naive implemetation would
1. select information for the category with the `id`,
2. select information of categories with `parent_id` equal to `id`,
3. select information of categories with `parent_id` in the list of ids return in step 2.

Step 3 is repeated until no more results are returned. If this is done at the application level, it can lead to a large amount of calls to the database, which is not efficient.

Postresql extends the SQL standard definition for Common Table Expressions (CTEs), also known as "WITH clauses", to support recursive query definitions. It enables a query to refer to its own output when using the `RECURSIVE` keyword.

Here is an example which will return the category tree associated with category `4`:
```sql
WITH RECURSIVE _category_tree AS (
    SELECT *
      FROM category
     WHERE category.id = 4
     UNION ALL
    SELECT category.*
      FROM category, _category_tree
     WHERE category.parent_id = _category_tree.id
)
SELECT *
  FROM _category_tree;
```

```
 id | parent_id | department_id |    name
----+-----------+---------------+-------------
  4 |           |             1 | 1:4
  5 |         4 |               | 1:4.5
  6 |         5 |               | 1:4.5.6
  7 |         6 |               | 1:4.5.6.7
  8 |         7 |               | 1:4.5.6.7.8
(5 rows)
```

Nice. A single database call to return the tree. But we want to refine this a bit. Category trees can be quite large and sometimes we want to only have a partial view. For this we can specify a depth to the query. Let's repeat the query for category `4` with a maximum depth of `2`.

```sql
WITH RECURSIVE _category_tree AS (
    SELECT *, 0 AS depth
      FROM category
     WHERE category.id = 4
     UNION ALL
    SELECT category.*, _category_tree.depth + 1 AS depth
      FROM category, _category_tree
     WHERE category.parent_id = _category_tree.id
       AND _category_tree.depth < 2
)
SELECT *
  FROM _category_tree;
```

```
 id | parent_id | department_id |  name   | depth
----+-----------+---------------+---------+-------
  4 |           |             1 | 1:4     |     0
  5 |         4 |               | 1:4.5   |     1
  6 |         5 |               | 1:4.5.6 |     2
(3 rows)
```

Note that I now return the `depth` in the result as well. The specified category (`4` in this case) is at level `0`. What is also interesting is that the results are return in _breadth-first traversal order_.

Further down this post I will show how the results of these queries (which are lists) can be used to construct tree structures in your Python code.

Department trees
----------------

Department trees are similar to category trees, with the exception that multiple category trees may be returned. Consider the following query to fetch the department category trees for department `1`:

```
WITH RECURSIVE _department_tree AS (
    SELECT *, 0 AS depth
      FROM category
     WHERE category.department_id = 1
     UNION ALL
    SELECT category.*, _department_tree.depth + 1 AS depth
      FROM category, _department_tree
     WHERE category.parent_id = _department_tree.id
       AND _department_tree.depth < 100
)
SELECT *
  FROM _department_tree;
```

```
 id | parent_id | department_id |    name     | depth
----+-----------+---------------+-------------+-------
  4 |           |             1 | 1:4         |     0
  9 |           |             1 | 1:9         |     0
  5 |         4 |               | 1:4.5       |     1
 10 |         9 |               | 1:9.10      |     1
  6 |         5 |               | 1:4.5.6     |     2
  7 |         6 |               | 1:4.5.6.7   |     3
  8 |         7 |               | 1:4.5.6.7.8 |     4
(7 rows)
```

Once again the _breadth-first traversal_ of the tree is evident.

Category lineage
----------------

Where category trees provide a view of a category and everything _below_ it, sometimes one wants an _upward_ view. Once again, this can be accomplished with single recursive query.

The following query gets the lineage of category `8`. The `depth` can only be determined when complete resultset has been returned, so we keep a relative `distance` count, which we then use afterwards to compute the `depth`.

```sql
--
-- Category lineage
--

WITH RECURSIVE _lineage AS (
    SELECT *, 0 AS distance
      FROM category
     WHERE category.id = 8
    UNION ALL
   SELECT category.*, _lineage.distance + 1 AS distance
     FROM category, _lineage
    WHERE category.id = _lineage.parent_id
)
SELECT *, COUNT(*) OVER () - distance AS depth
  FROM _lineage;
```

```
 id | parent_id | department_id |    name     | distance | depth
----+-----------+---------------+-------------+----------+-------
  8 |         7 |               | 1:4.5.6.7.8 |        0 |     5
  7 |         6 |               | 1:4.5.6.7   |        1 |     4
  6 |         5 |               | 1:4.5.6     |        2 |     3
  5 |         4 |               | 1:4.5       |        3 |     2
  4 |           |             1 | 1:4         |        4 |     1
(5 rows)
```

As can be seen from the results, the first row return is the category specified, then its parent, then granparent and so on until the top-level category gets reached.

> Note: the `COUNT(*) OVER ()` is a `WINDOW` function, which computes an aggregate over a part of the resultset (in this case everything) without the need for an explicit `GROUP BY` clause.

The lineage can thus be used to determine the depth of a category in the category tree, but more importantly, it can be used to determine the `department_id` associated with the category.

Everything all at once
----------------------

To show off some more SQL goodness, let's combine our _tree_ and _lineage_ queries for a consolidated view. Getting a combined view for category `6` would look like this:

```sql
--
-- Combined lineage and tree.
-- Note the use of "UNION DISTINCT" which removes the duplicate row
-- for the category_id specified in the query.
--

WITH RECURSIVE _category_tree AS (
    SELECT *, 0 AS rel_depth
      FROM category
     WHERE category.id = 6
     UNION ALL
    SELECT category.*, _category_tree.rel_depth + 1 AS rel_depth
      FROM category, _category_tree
     WHERE category.parent_id = _category_tree.id
), _lineage AS (
    SELECT *, 0 AS rel_depth
      FROM category
     WHERE category.id = 6
     UNION ALL
    SELECT category.*, _lineage.rel_depth - 1 AS rel_depth
      FROM category, _lineage
     WHERE category.id = _lineage.parent_id
), _combined AS (
    SELECT *
      FROM _category_tree
     UNION DISTINCT
    SELECT *
      FROM _lineage
)
SELECT *, rel_depth - MIN(rel_depth) OVER () as depth
  FROM _combined
 ORDER BY rel_depth ASC;
```

```
 id | parent_id | department_id |    name     | rel_depth | depth
----+-----------+---------------+-------------+-----------+-------
  4 |           |             1 | 1:4         |        -2 |     0
  5 |         4 |               | 1:4.5       |        -1 |     1
  6 |         5 |               | 1:4.5.6     |         0 |     2
  7 |         6 |               | 1:4.5.6.7   |         1 |     3
  8 |         7 |               | 1:4.5.6.7.8 |         2 |     4
(5 rows)
```

Wrapping things up (in functions)
---------------------------------
No, this is not quite the end. The queries we have seen in this document is quite big. For reasons of simplicity and performance, one may consider wrapping them in functions in the database:

```sql
--
-- Function returning the tree associated with a category, limited to a specified depth
--

CREATE OR REPLACE
FUNCTION category_tree(_category_id INTEGER, _max_depth INTEGER)
    RETURNS TABLE(id INTEGER, parent_id INTEGER, department_id INTEGER, name TEXT, depth INTEGER)
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE _category_tree AS (
        SELECT *, 0 AS depth
          FROM category
         WHERE category.id = _category_id
        UNION ALL
        SELECT category.*, _category_tree.depth + 1 AS depth
          FROM category, _category_tree
         WHERE category.parent_id = _category_tree.id
           AND _category_tree.depth < _max_depth
    )
    SELECT *
      FROM _category_tree;
END;
$$ LANGUAGE plpgsql;
```

Usage examples:
```
cattest=# select * from category_tree(6, 100);
 id | parent_id | department_id |    name     | depth
----+-----------+---------------+-------------+-------
  6 |         5 |               | 1:4.5.6     |     0
  7 |         6 |               | 1:4.5.6.7   |     1
  8 |         7 |               | 1:4.5.6.7.8 |     2
(3 rows)

cattest=# select * from category_tree(0, 100);
 id | parent_id | department_id |  name   | depth
----+-----------+---------------+---------+-------
  0 |           |             0 | 0:0     |     0
  1 |         0 |               | 0:0.1   |     1
  2 |         1 |               | 0:0.1.2 |     2
  3 |         1 |               | 0:0.1.3 |     2
(4 rows)
```

From list to tree
-----------------

Defining the position of a category in a tree purely based on its parent is sound. When viewing a category from an application's perspective, however, it is convenient to have its children directly accessible.

As mentioned earlier in the document, the results of the category tree is request is returned in _breadth-first_ traversal order. This means that the fist row returned will be the top of the tree and subsequent rows will be children or grandchildren.

Below is a function implemented in Python which will construct a tree. We construct a `dictionary` containing the categories returned and use this to update the `children` attribute associated with the `parent_id` for each category we process (except the first one, which is the head of the tree and has no parent).


```python
CATTREE_SQL = """
SELECT id, parent_id, department_id, name, depth
  FROM category_tree(%(id)s, %(max_depth)s)
"""

def category_tree(_id, max_depth=100):
    tree = None
    category_by_id = {}

    cur = CONN.cursor()
    cur.execute(CATTREE_SQL, {"id": _id, "max_depth": max_depth})

    for cat_id, parent_id, dept_id, name, depth in cur.fetchall():
        cat = {
            "id": cat_id,
            "parent_id": parent_id,
            "department_id": dept_id,
            "depth": depth,
            "name": name,
            "children": []
        }

        category_by_id[cat_id] = cat
        if tree:
            category_by_id[parent_id]["children"].append(cat)
        else:
            tree = cat

    return tree
```

The code for a `department_tree` would be similar, with the exception that it would return a list of category trees.

Conclusion
----------
I hope you enjoyed reading this. If you are curious and want more information, please chat to me. Or read the [documentation](http://www.postgresql.org/docs/9.4/static/queries-with.html)

Addendum
--------

Here is a Python program that prints the category tree for all 10 categories we defined. The result can be seen below. I prefixed the `children` field with `x_` so that it is the last field pretty-printed.

```python
import psycopg2
import pprint

CONN = psycopg2.connect(database="cattest", user="cobusc", password="")
assert CONN, "Not connected"
CATTREE_SQL = """
SELECT id, parent_id, department_id, name, depth
  FROM category_tree(%(id)s, %(max_depth)s)
"""

def category_tree(_id, max_depth=100):

    tree = None
    category_by_id = {}

    cur = CONN.cursor()
    assert cur, "Could not get cursor"
    cur.execute(CATTREE_SQL, {"id": _id, "max_depth": max_depth})

    for cat_id, parent_id, dept_id, name, depth in cur.fetchall():
        cat = {
            "id": cat_id,
            "parent_id": parent_id,
            "department_id": dept_id,
            "depth": depth,
            "name": name,
            "x_children": []
        }

        category_by_id[cat_id] = cat
        if tree:
            # Inherit the department from the parent
            cat["department_id"] = category_by_id[parent_id]["department_id"]
            category_by_id[parent_id]["x_children"].append(cat)
        else:
            tree = cat

    return tree


if __name__ == "__main__":
    for i in xrange(0,11):
        print("category_tree({}) = ".format(i))
        pprint.pprint(category_tree(i))
        print("="*20)
```

```
category_tree(0) =
{'department_id': 0,
 'depth': 0,
 'id': 0,
 'name': '0:0',
 'parent_id': None,
 'x_children': [{'department_id': 0,
                 'depth': 1,
                 'id': 1,
                 'name': '0:0.1',
                 'parent_id': 0,
                 'x_children': [{'department_id': 0,
                                 'depth': 2,
                                 'id': 2,
                                 'name': '0:0.1.2',
                                 'parent_id': 1,
                                 'x_children': []},
                                {'department_id': 0,
                                 'depth': 2,
                                 'id': 3,
                                 'name': '0:0.1.3',
                                 'parent_id': 1,
                                 'x_children': []}]}]}
====================
category_tree(1) =
{'department_id': None,
 'depth': 0,
 'id': 1,
 'name': '0:0.1',
 'parent_id': 0,
 'x_children': [{'department_id': None,
                 'depth': 1,
                 'id': 2,
                 'name': '0:0.1.2',
                 'parent_id': 1,
                 'x_children': []},
                {'department_id': None,
                 'depth': 1,
                 'id': 3,
                 'name': '0:0.1.3',
                 'parent_id': 1,
                 'x_children': []}]}
====================
category_tree(2) =
{'department_id': None,
 'depth': 0,
 'id': 2,
 'name': '0:0.1.2',
 'parent_id': 1,
 'x_children': []}
====================
category_tree(3) =
{'department_id': None,
 'depth': 0,
 'id': 3,
 'name': '0:0.1.3',
 'parent_id': 1,
 'x_children': []}
====================
category_tree(4) =
{'department_id': 1,
 'depth': 0,
 'id': 4,
 'name': '1:4',
 'parent_id': None,
 'x_children': [{'department_id': 1,
                 'depth': 1,
                 'id': 5,
                 'name': '1:4.5',
                 'parent_id': 4,
                 'x_children': [{'department_id': 1,
                                 'depth': 2,
                                 'id': 6,
                                 'name': '1:4.5.6',
                                 'parent_id': 5,
                                 'x_children': [{'department_id': 1,
                                                 'depth': 3,
                                                 'id': 7,
                                                 'name': '1:4.5.6.7',
                                                 'parent_id': 6,
                                                 'x_children': [{'department_id': 1,
                                                                 'depth': 4,
                                                                 'id': 8,
                                                                 'name': '1:4.5.6.7.8',
                                                                 'parent_id': 7,
                                                                 'x_children': []}]}]}]}]}
====================
category_tree(5) =
{'department_id': None,
 'depth': 0,
 'id': 5,
 'name': '1:4.5',
 'parent_id': 4,
 'x_children': [{'department_id': None,
                 'depth': 1,
                 'id': 6,
                 'name': '1:4.5.6',
                 'parent_id': 5,
                 'x_children': [{'department_id': None,
                                 'depth': 2,
                                 'id': 7,
                                 'name': '1:4.5.6.7',
                                 'parent_id': 6,
                                 'x_children': [{'department_id': None,
                                                 'depth': 3,
                                                 'id': 8,
                                                 'name': '1:4.5.6.7.8',
                                                 'parent_id': 7,
                                                 'x_children': []}]}]}]}
====================
category_tree(6) =
{'department_id': None,
 'depth': 0,
 'id': 6,
 'name': '1:4.5.6',
 'parent_id': 5,
 'x_children': [{'department_id': None,
                 'depth': 1,
                 'id': 7,
                 'name': '1:4.5.6.7',
                 'parent_id': 6,
                 'x_children': [{'department_id': None,
                                 'depth': 2,
                                 'id': 8,
                                 'name': '1:4.5.6.7.8',
                                 'parent_id': 7,
                                 'x_children': []}]}]}
====================
category_tree(7) =
{'department_id': None,
 'depth': 0,
 'id': 7,
 'name': '1:4.5.6.7',
 'parent_id': 6,
 'x_children': [{'department_id': None,
                 'depth': 1,
                 'id': 8,
                 'name': '1:4.5.6.7.8',
                 'parent_id': 7,
                 'x_children': []}]}
====================
category_tree(8) =
{'department_id': None,
 'depth': 0,
 'id': 8,
 'name': '1:4.5.6.7.8',
 'parent_id': 7,
 'x_children': []}
====================
category_tree(9) =
{'department_id': 1,
 'depth': 0,
 'id': 9,
 'name': '1:9',
 'parent_id': None,
 'x_children': [{'department_id': 1,
                 'depth': 1,
                 'id': 10,
                 'name': '1:9.10',
                 'parent_id': 9,
                 'x_children': []}]}
====================
category_tree(10) =
{'department_id': None,
 'depth': 0,
 'id': 10,
 'name': '1:9.10',
 'parent_id': 9,
 'x_children': []}
====================
```
