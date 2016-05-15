import psycopg2
import pprint

CONN = psycopg2.connect(host="ec2-23-21-166-16.compute-1.amazonaws.com",
                        database="d64t2ttilgljcl", user="bmvujhiwgqaotb",
                        password="plcaholder", sslmode="require")
cur = CONN.cursor()
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

