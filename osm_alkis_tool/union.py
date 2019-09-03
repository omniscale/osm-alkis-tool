# -*- coding: utf-8 -*-

from __future__ import absolute_import

import argparse
import logging
import sys
import uuid

from contextlib import contextmanager

import psycopg2
import psycopg2.extensions



class Mapping(object):
    source_table = None
    srid = -1

    def __init__(self, table, group_by, union_buffer=0.0, srid=-1,
                 geometry_type='geometry', union_columns=None, extra_columns=None,
                 postfix='union',
                 tolerances=None, _filter=None, schema='public'):
        self.source_table = '%s.%s' % (schema, table)
        self.table = table
        self.schema = schema
        self.group_by = group_by
        self.union_buffer = union_buffer
        self.srid = srid
        self.geometry_type = geometry_type
        self.union_columns = union_columns or []
        self.extra_columns = extra_columns or []
        self.postfix = postfix
        self.tolerances = tolerances
        self.filter = _filter

    @property
    def target_table(self):
        return '%s.%s_%s' % (self.schema, self.table, self.postfix)

    @property
    def columns(self):
        return ['id'] + [c[0] for c in self.union_columns + self.extra_columns]

    @property
    def column_names(self):
        return [c[0] for c in self.union_columns + self.extra_columns]

    @property
    def column_types(self):
        return ['%s %s' % (c[0], c[2]) for c in self.union_columns + self.extra_columns]

    @property
    def column_mapping(self):
        return ['%s AS %s' % (c[1], c[0]) for c in self.union_columns + self.extra_columns]

    @property
    def union_mapping(self):
        return ['%s AS %s' % (c[1], c[0]) for c in self.union_columns]

class Transaction(object):
    SIMPLIFY_QUERY = """
        INSERT INTO %s (%s, geometry) SELECT * FROM (SELECT %s,
        ST_Buffer(ST_SimplifyPreserveTopology(geometry, %f), 0) FROM %s) AS sub
        %s;
    """

    ST_BUFFER_REDUCE_QUERY = """
        INSERT INTO %(target_tablename)s (%(column_name)s, geometry)
        SELECT %(column_mapping)s, geometry FROM (
            SELECT %(union_mapping)s,
                (ST_Dump(ST_Buffer(ST_UNION(ST_Buffer(geometry, 0)), -%(buffer_size)s, 2))).geom
                AS geometry
            FROM (
                SELECT %(column_name)s, ST_BUFFER(geometry, %(buffer_size)s, 1)
                AS geometry FROM %(source_tablename)s
                WHERE %(group_by)s = %%(batch)s
            ) as b
            GROUP BY %(group_by)s, ST_SnapToGrid(ST_Centroid(geometry), 5000)
        ) AS sub;
    """

    REDUCE_QUERY = """
        INSERT INTO %(target_tablename)s (%(column_name)s, geometry)
        SELECT %(column_mapping)s, geometry FROM (
            SELECT %(union_mapping)s,
                (ST_Dump(ST_Buffer(ST_UNION(ST_Buffer(geometry, 0)), 0))).geom
                AS geometry
            FROM %(source_tablename)s
            WHERE %(group_by)s = %%(batch)s
            GROUP BY %(group_by)s, ST_SnapToGrid(ST_Centroid(geometry), 5000)
        ) AS sub;
    """

    def __init__(self, connection, mappings, postfix='union'):
        self.mappings = mappings
        self.postfix = postfix
        try:
            self.conn = psycopg2.connect(connection)
        except psycopg2.OperationalError as e:
            exit(e.message)
            exit(0)
        self.conn.set_isolation_level(
            psycopg2.extensions.ISOLATION_LEVEL_READ_COMMITTED
        )
        self.cur = self.conn.cursor()

    def process(self):
        for mapping in self.mappings:
            logging.info('start union process for %s', mapping.source_table)
            self.reduce_polygons(mapping)
            self.create_simplified_tables(mapping)

    @contextmanager
    def savepoint(self, raise_errors=False):
        savepoint_name = 'savepoint' + uuid.uuid4().hex
        try:
            self.cur.execute('SAVEPOINT %s' % savepoint_name)
            yield
        except psycopg2.ProgrammingError:
            self.cur.execute('ROLLBACK TO SAVEPOINT %s' % savepoint_name)
            if raise_errors:
                raise

    def create_table(self, table_name, columns, srid, geometry_type):
        """
        Create a new table or delete all data if the table already exists.
        """

        if self.table_exists(table_name):
            self.drop_table(table_name)

        logging.info('Create table %s', table_name)
        self.cur.execute("""
            CREATE TABLE %s (id serial PRIMARY KEY, %s);
            """ % (table_name, ', '.join(columns)))
        self.cur.execute("""
            SELECT AddGeometryColumn (
                '%(schema)s', '%(table_name)s', 'geometry', %(srid)s, '%(type)s', 2
            );
            """ % dict(
                schema=table_name.split('.')[0],
                table_name=table_name.split('.')[1],
                srid=srid,
                type=geometry_type
            ))
        self.cur.execute("""CREATE INDEX %(index_name)s_gist
            ON %(table_name)s USING GIST (geometry);""" % dict(
                table_name=table_name,
                index_name=table_name.split('.')[1] # remove schema
        ))

    def table_exists(self, table_name):
        with self.savepoint():
            self.cur.execute('SELECT 1 FROM %s' % table_name)
            # execute did not raise an error, so table exists
            return True
        return False

    def drop_table(self, table_name):
        logging.info('Drop table %s', table_name)
        with self.savepoint():
            self.cur.execute('DROP TABLE %s' % table_name)

    def reduce_polygons(self, mapping):
        # process merging in batches, otherwise postgres will group the whole
        # table at once before starting to insert
        # we group our batch operations by group by column
        self.cur.execute("""
            SELECT DISTINCT %(column_name)s FROM %(tablename)s;
        """ % dict(
            tablename=mapping.source_table,
            column_name=mapping.group_by)
        )
        batches = self.cur.fetchall()

        self.create_table(mapping.target_table, mapping.column_types,
                          mapping.srid, mapping.geometry_type)

        for _, batch in enumerate(batches):
            # prepare querys
            st_buffer_reduce_query = self.ST_BUFFER_REDUCE_QUERY % dict(
                target_tablename=mapping.target_table,
                source_tablename=mapping.source_table,
                column_name=', '.join(mapping.column_names),
                column_mapping=', '.join(mapping.column_mapping),
                union_mapping=', '.join(mapping.union_mapping),
                buffer_size=mapping.union_buffer,
                group_by=mapping.group_by,
            )

            # Used ST_Dump to get polygons instead of one multipolygon
            normal_reduce_query = self.REDUCE_QUERY % dict(
                target_tablename=mapping.target_table,
                source_tablename=mapping.source_table,
                column_name=', '.join(mapping.column_names),
                column_mapping=', '.join(mapping.column_mapping),
                union_mapping=', '.join(mapping.union_mapping),
                group_by=mapping.group_by,
            )
            query = (
                st_buffer_reduce_query
                if mapping.union_buffer != 0.0 else
                normal_reduce_query
            )
            # do insert
            self.cur.execute(query, {'batch': batch})
        logging.info('union table %s created', mapping.target_table)

    def create_simplified_tables(self, mapping):
        for suffix, tolerance in mapping.tolerances:
            logging.info('Simplifing %s to %s with tolerance %f',
                mapping.target_table,
                mapping.target_table + suffix,
                tolerance,
            )
            self.create_table(mapping.target_table + suffix, mapping.column_types,
                              mapping.srid, mapping.geometry_type)
            filter_ = ''
            if mapping.filter is not None:
                filter_ = 'WHERE %s' % mapping.filter

            stmt = self.SIMPLIFY_QUERY % (
                mapping.target_table + suffix,
                ','.join(mapping.columns),
                ','.join(mapping.columns),
                tolerance,
                mapping.target_table,
                filter_,
            )
            self.cur.execute(stmt)

    def vacuum_table(self, table_name):
        logging.info('Vacuum analyze %s', table_name)
        old_isolation_level = self.conn.isolation_level
        self.conn.set_isolation_level(
            psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT
        )
        self.cur.execute("VACUUM ANALYZE %s;" % table_name)
        self.conn.set_isolation_level(old_isolation_level)

    def finish(self, with_vacuum=False):
        self.conn.commit()
        if with_vacuum:
            self.cur = self.conn.cursor()
            for mapping in self.mappings:
                self.vacuum_table(mapping.target_table)
                if mapping.tolerances:
                    for suffix, _ in mapping.tolerances:
                        self.vacuum_table(mapping.target_table + suffix)
            self.conn.commit()
        self.conn.close()


def main(argv=None):
    """
    Creates union table for given table.
    """
    parser = argparse.ArgumentParser(
        description=main.__doc__, add_help=False,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        '--help', dest='help', action='store_true',
        default=False, help='show this help message and exit')
    parser.add_argument('--connection',
        dest='connection',
        help='Database connection string (dbname=osm_alkis user=osm password=osm host=localhost)',
        default='',
    )
    parser.add_argument(
        '-m', '--mapping',
        dest='mapping', metavar='<mapping>', required=True)
    parser.add_argument(
        '-v', '--vacuum',
        dest='vacuum', action='store_true')

    logging.basicConfig(level=logging.DEBUG)

    if len(sys.argv) == 1:
        parser.print_help()
        sys.exit(1)

    options = parser.parse_args(argv)

    if options.help:
        parser.print_help()
        sys.exit(1)

    mappings_ns = {'Mapping': Mapping}
    with open(options.mapping) as f:
        code = compile(f.read(), options.mapping, 'exec')
        _ = exec(code, mappings_ns)  # pylint: disable=exec-used
    mappings = mappings_ns['mappings']

    transaction = Transaction(options.connection, mappings)

    transaction.process()
    transaction.finish(options.vacuum)


if __name__ == '__main__':
    main()
