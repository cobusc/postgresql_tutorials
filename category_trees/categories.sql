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
-- Example Python code to construct tree from results
--
-- def category_tree(id):
--   _tree = None
--   _category_by_id = {}
--
--   def make_cat(row):
--       return {
--           "id": row.id,
--           "parent_id": row.parent_id,
--           "department_id": row.department_id,
--           "name": row.name,
--           "slug": row.slug
--           "children": []
--       }
--
--   for row in results:
--     cat = make_cat(row)
--     _category_by_id[row.id] = cat
--
--     if _tree:
--         _category_by_id[row.parent_id].children.add(cat)
--     else:
--         _tree = cat
--
--   return _tree
--

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

-- mysql> desc cats;
-- --------------
-- desc cats
-- --------------
--
-- +------------------------+---------------------------------------------------+------+-----+---------+----------------+
-- | Field                  | Type                                              | Null | Key | Default | Extra          |
-- +------------------------+---------------------------------------------------+------+-----+---------+----------------+
-- | idCat                  | smallint(6)                                       | NO   | PRI | NULL    | auto_increment |
-- | idType                 | tinyint(4)                                        | NO   | MUL | 0       |                |
-- | CatName                | varchar(50)                                       | YES  | MUL | NULL    |                |
-- | CatLevel               | tinyint(4)                                        | YES  |     | NULL    |                |
-- | idParent               | smallint(6)                                       | YES  |     | NULL    |                |
-- | ProductCount           | int(11)                                           | YES  |     | NULL    |                |
-- | InactiveProductCount   | int(11)                                           | YES  |     | NULL    |                |
-- | slug                   | varchar(255)                                      | YES  |     | NULL    |                |
-- | SeoCatName             | varchar(255)                                      | YES  |     | NULL    |                |
-- | ProductSize            | enum('Light','Medium','Heavy','Very Heavy')       | YES  | MUL | NULL    |                |
-- | IsPubliclyHidden       | tinyint(1)                                        | NO   |     | 0       |                |
-- | MarketPlaceEligibility | enum('Available','Not Available','Default')       | YES  |     | NULL    |                |
-- | InvitedSellers         | enum('Dummy value to key on. Should not be set.') | YES  |     | NULL    |                |
-- +------------------------+---------------------------------------------------+------+-----+---------+----------------+
-- 13 rows in set (0.00 sec)

