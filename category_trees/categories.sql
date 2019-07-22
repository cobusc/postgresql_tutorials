--
-- Example category tree implementation
--

--
-- DB: cattest
--

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
    slug TEXT UNIQUE NOT NULL,

    CHECK ((parent_id IS NULL AND department_id IS NOT NULL)
        OR (parent_id IS NOT NULL AND department_id IS NULL))
);

CREATE INDEX ON category(parent_id);


-- Add some test data

INSERT INTO category (id, parent_id, department_id, name, slug) VALUES
(0, NULL, 0, '0:0', '0:0'),
(1, 0, NULL, '0:0.1', '0:0.1'),
(2, 1, NULL, '0:0.1.2', '0:0.1.2'),
(3, 1, NULL, '0:0.1.3', '0:0.1.3'),
(4, NULL, 1, '1:4', '1:4'),
(5, 4, NULL, '1:4.5', '1:4.5'),
(6, 5, NULL, '1:4.5.6', '1:4.5.6'),
(7, 6, NULL, '1:4.5.6.7', '1:4.5.6.7'),
(8, 7, NULL, '1:4.5.6.7.8', '1:4.5.6.7.8');

--
-- Create a view containing all the leaf categories.
--

CREATE VIEW leaf_category AS
SELECT id
  FROM category
EXCEPT
SELECT DISTINCT parent_id
  FROM category;

-- Test it

SELECT * FROM leaf_category;

--
-- Function returning the tree associated with a category
--

CREATE OR REPLACE
FUNCTION category_tree(_category_id INTEGER)
    RETURNS TABLE(id INTEGER, parent_id INTEGER, department_id INTEGER, name TEXT, slug TEXT)
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE _category_tree AS (
        SELECT *
          FROM category
         WHERE category.id = _category_id
        UNION ALL
        SELECT category.*
          FROM category, _category_tree
         WHERE category.parent_id = _category_tree.id
    )
    SELECT *
      FROM _category_tree;
END;
$$ LANGUAGE plpgsql;

--
-- Function returning the tree associated with a category, limited to a specified depth
--

CREATE OR REPLACE
FUNCTION category_tree(_category_id INTEGER, _max_depth INTEGER)
    RETURNS TABLE(id INTEGER, parent_id INTEGER, department_id INTEGER, name TEXT, slug TEXT, depth INTEGER)
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

--
-- Department tree
--

WITH RECURSIVE _department_tree AS (
    SELECT *
      FROM category
     WHERE category.department_id = 1
    UNION ALL
    SELECT category.*
      FROM category, _department_tree
     WHERE category.parent_id = _department_tree.id
)
SELECT *
  FROM _department_tree;

--
-- Category lineage
--

WITH RECURSIVE _lineage AS (
    SELECT *
      FROM category
     WHERE category.id = 8
    UNION ALL
   SELECT category.*
     FROM category, _lineage
    WHERE category.id = _lineage.parent_id
)
SELECT *
  FROM _lineage;

--
-- Category level
--
WITH RECURSIVE _lineage AS (
    SELECT *
      FROM category
     WHERE category.id = 8
     UNION ALL
    SELECT category.*
      FROM category, _lineage
     WHERE category.id = _lineage.parent_id
)
SELECT COUNT(*)-1 AS cat_level
  FROM _lineage;

--
-- Category department
--
WITH RECURSIVE _lineage AS (
    SELECT *
      FROM category
     WHERE category.id = 8
     UNION ALL
    SELECT category.*
      FROM category, _lineage
     WHERE category.id = _lineage.parent_id
)
SELECT department_id
  FROM _lineage
 WHERE department_id IS NOT NULL;

--
-- Combined lineage and tree.
-- Note the use of "UNION DISTINCT" which removes the duplicate row
-- for the category_id specified in the query.
--

WITH RECURSIVE _category_tree AS (
    SELECT *
      FROM category
     WHERE category.id = 5
     UNION ALL
    SELECT category.*
      FROM category, _category_tree
     WHERE category.parent_id = _category_tree.id
), _lineage AS (
    SELECT *
      FROM category
     WHERE category.id = 5
     UNION ALL
    SELECT category.*
      FROM category, _lineage
     WHERE category.id = _lineage.parent_id
)
SELECT *
  FROM _category_tree
 UNION DISTINCT
SELECT *
  FROM _lineage;


-- A materialized view containing each category, its lineage and depth.
-- All fields are indexed for fast lookups.
-- Add awesome abilities: https://www.postgresql.org/docs/current/intarray.html
CREATE EXTENSION intarray;

CREATE MATERIALIZED VIEW category_lineage AS
    WITH RECURSIVE _lineage AS (
        SELECT id, ARRAY[id]::int[] AS lineage
          FROM category
         WHERE parent_id IS NULL
         UNION ALL
        SELECT category.id, array_prepend(category.id, _lineage.lineage)
          FROM category, _lineage
         WHERE category.parent_id = _lineage.id
    )
    SELECT id, lineage, array_length(lineage, 1) - 1 AS depth
      FROM _lineage;

CREATE UNIQUE INDEX category_lineage_pk ON category_lineage(id);
CREATE INDEX category_lineage_depth_index ON category_lineage(depth);
-- This enables us to quickly do queries like "return all categories which are ancestors of category N".
CREATE INDEX category_lineage_index ON category_lineage USING GIN(lineage gin__int_ops);

-- After new categories are added, or parent_ids changed, refresh the view using the following command:
REFRESH MATERIALIZED VIEW CONCURRENTLY category_lineage;

-- Find all categories with category 0 in its lineage
SELECT * 
  FROM category_lineage 
 WHERE lineage @> '{0}';

