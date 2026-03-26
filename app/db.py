import psycopg2
from psycopg2.extras import RealDictCursor

DB = {
    "host": "localhost",
    "dbname": "Hotel-Flight-DB",
    "user": "ahmed",
}


def conn():
    return psycopg2.connect(**DB)


def fetch(sql, params=None):
    c = conn()
    try:
        with c.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params or ())
            return cur.fetchall()
    finally:
        c.close()


def fetch_one(sql, params=None):
    c = conn()
    try:
        with c.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params or ())
            return cur.fetchone()
    finally:
        c.close()


def execute(sql, params=None):
    # for writes — commits on success, rolls back and re-raises on failure
    c = conn()
    try:
        with c.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, params or ())
            c.commit()
            try:
                return cur.fetchone()
            except Exception:
                return None
    except Exception:
        c.rollback()
        raise
    finally:
        c.close()
