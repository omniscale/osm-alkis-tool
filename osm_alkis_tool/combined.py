# -*- coding: utf-8 -*-

from __future__ import absolute_import

def create_combined_tables(conn, tables, dst_schema):
    with conn.cursor() as cur:
        for table, src_schemas in tables:
            # do not use DROP TABLE or TRUNCATE for table recreation as this would block
            # any read access to the destination table till the transaction is committed
            cur.execute('''CREATE TABLE IF NOT EXISTS "%s"."%s" (LIKE "%s"."%s");''' % (dst_schema, table, src_schemas[0], table))

            columns = []
            cur.execute('''SELECT column_name FROM information_schema.columns
                WHERE table_schema = %s
                AND table_name   = %s
                ORDER BY ordinal_position''',
            [dst_schema, table])
            columns = ['"' + row[0] + '"' for row in cur.fetchall()]
            columns = ', '.join(columns)

            cur.execute('''SELECT COUNT(*) > 0 FROM pg_indexes WHERE schemaname = %s AND indexname = %s''', [dst_schema, table + '_geom'])
            row = cur.fetchone()
            if not row[0]:
                cur.execute('''CREATE INDEX "%s_geom" ON "%s"."%s" USING GIST(geometry);''' % (table, dst_schema, table))
            cur.execute('''DELETE FROM "%s"."%s";''' % (dst_schema, table))

            for schema in src_schemas:
                cur.execute('''INSERT INTO "%s"."%s" (%s) SELECT %s FROM "%s"."%s";''' % (
                    dst_schema, table, columns, columns, schema, table))

    conn.commit()
