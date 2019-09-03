# -*- coding: utf-8 -*-
# pylint: disable=unused-argument

from __future__ import absolute_import

import argparse
import csv
import itertools
import re

from io import open

import yaml

VIEW_TEMPLATE = """DROP VIEW IF EXISTS  %(view_schema)s.%(view_name)s;
CREATE VIEW %(view_schema)s.%(view_name)s AS SELECT \n%(columns)s \n\tFROM %(source)s;\n"""

REDIRECT_VIEW_TEMPLATE = """DROP VIEW IF EXISTS  %(view_schema)s.%(view_name)s;
CREATE VIEW %(view_schema)s.%(view_name)s AS SELECT * FROM %(osm_schema)s.%(osm_table)s;\n"""


def source_table_exist(cursor, schema, table):
    query = """SELECT EXISTS (
        SELECT 1
        FROM   pg_catalog.pg_class c
        JOIN   pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE  n.nspname = %(schema)s
        AND    c.relname = %(table)s
    );"""

    cursor.execute(query, {'schema': schema, 'table': table})
    return cursor.fetchone()[0]

def osm_tables_from_db(cursor, schema):
    query = """SELECT table_name
        FROM information_schema.tables
        WHERE table_schema=%(schema)s
        AND table_type='BASE TABLE';"""
    cursor.execute(query, {'schema': schema})
    return [r[0] for r in cursor.fetchall()]

def read_type_mapping(type_mapping_file):
    mapping = {}

    with open(type_mapping_file, 'r', encoding='utf-8') as csv_file:
        reader = csv.DictReader(csv_file, delimiter=';')
        for row in reader:
            source_table = row['objektart']

            short_source = row['short_source']
            source_attribute = row['attribut']
            source_value = row['wert']

            target_table = row['osm_tabelle']
            target_value = row['styled_osm_type']

            # list of additional columns with their target name and source SQL
            extra_columns = dict(zip(
                [c for c in row.get('extra_columns', '').split(',') if c],
                [c for c in row.get('extra_columns_sql', '').split(',') if c],
            ))

            if target_value == '':
                continue

            if target_table not in mapping:
                mapping[target_table] = {
                    'sources': {}
                }

            if source_table not in mapping[target_table]['sources']:
                mapping[target_table]['sources'][source_table] = {
                    'short_source': short_source,
                    'type_mapping': {},
                    'extra_columns': extra_columns,
                }

            if source_attribute == '':
                mapping[target_table]['sources'][source_table] = {
                    'short_source': short_source,
                    'type': target_value,
                    'type_mapping': {},
                    'extra_columns': {},
                }
                continue

            mapping[target_table]['sources'][source_table]['type_mapping'].setdefault(source_attribute, []).append((source_value, target_value))
            mapping[target_table]['sources'][source_table]['extra_columns'].update(extra_columns)

    return mapping

def fnk_read_type_mapping(type_mapping_file):
    mapping = {}

    with open(type_mapping_file, 'rb') as csv_file:
        reader = csv.DictReader(csv_file, delimiter=';')
        for row in reader:
            source_table = 'fnk'
            source_attribute = row['attribut']
            source_value = row['wert']

            target_table = row['osm_tabelle']
            target_value = row['styled_osm_type']

            # list of additional columns with their target name and source SQL
            extra_columns = dict(zip(
                [c for c in row.get('extra_columns', '').split(',') if c],
                [c for c in row.get('extra_columns_sql', '').split(',') if c],
            ))

            if target_value == '':
                continue

            if target_table not in mapping:
                mapping[target_table] = {
                    'sources': {}
                }

            if source_table not in mapping[target_table]['sources']:
                mapping[target_table]['sources'][source_table] = {
                    'type_mapping': {},
                    'extra_columns': extra_columns,
                }

            if source_attribute == '':
                mapping[target_table]['sources'][source_table] = {
                    'type': target_value,
                    'type_mapping': {},
                    'extra_columns': {},
                }
                continue

            mapping[target_table]['sources'][source_table]['type_mapping'].setdefault(source_attribute, []).append((source_value, target_value))
            mapping[target_table]['sources'][source_table]['extra_columns'].update(extra_columns)

    return mapping

def atkis_read_type_mapping(type_mapping_file):
    mapping = {}

    with open(type_mapping_file, 'rb') as csv_file:
        reader = csv.DictReader(csv_file, delimiter=';')
        for row in reader:
            source_table = row['tabelle']
            source_attribute = row['attribut']
            source_value = row['wert']

            target_table = row['osm_tabelle']
            target_value = row['styled_osm_type']

            # list of additional columns with their target name and source SQL
            extra_columns = dict(zip(
                [c for c in row.get('extra_columns', '').split(',') if c],
                [c for c in row.get('extra_columns_sql', '').split(',') if c],
            ))

            if target_value == '':
                continue

            if target_table not in mapping:
                mapping[target_table] = {
                    'sources': {}
                }

            if source_table not in mapping[target_table]['sources']:
                mapping[target_table]['sources'][source_table] = {
                    'type_mapping': {},
                    'extra_columns': extra_columns,
                }

            if source_attribute == '':
                mapping[target_table]['sources'][source_table] = {
                    'type': target_value,
                    'type_mapping': {},
                    'extra_columns': {},
                }
                continue

            mapping[target_table]['sources'][source_table]['type_mapping'].setdefault(source_attribute, []).append((source_value, target_value))
            mapping[target_table]['sources'][source_table]['extra_columns'].update(extra_columns)
    return mapping

def indent_lines(lines, tabs=1):
    return ['\t'*tabs + l for l in lines]

def create_views(type_mapping, mappings, alkis_schema, view_schema, alkis_srid=25832):
    views = []
    typed_views = mappings.define_typed_views()
    single_table_views = mappings.define_single_table_views()

    for view in single_table_views:
        views.append(view)

    for name, view in typed_views.items():
        views.append(typed_view(
            name=name,
            view=view,
            mapping=type_mapping[name],
            alkis_schema='{{alkis_schema}}',
            view_schema='{{view_schema}}',
        ))
    return ''.join(views)

def create_fnk_views(type_mapping, mappings, fnk_schema, view_schema, fnk_srid=25832):
    views = []
    typed_views = mappings.define_typed_views()

    for name, view in typed_views.items():
        views.append(fnk_typed_view(
            name=name,
            view=view,
            mapping=type_mapping[name],
            fnk_schema='{{fnk_schema}}',
            view_schema='{{view_schema}}',
        ))
    return ''.join(views)

def create_atkis_views(type_mapping, mappings, atkis_schema, view_schema, atkis_srid=25832):
    views = []
    typed_views = mappings.define_typed_views()
    for name, view in typed_views.items():
        views.append(atkis_typed_view(
            name=name,
            view=view,
            mapping=type_mapping[name],
            atkis_schema='{{atkis_schema}}',
            view_schema='{{view_schema}}',
        ))
    return ''.join(views)

def create_osm_views(osm_schema, view_schema, osm_tables=None):
    views = []
    for table in osm_tables or []:
        views.append(REDIRECT_VIEW_TEMPLATE % {
            'view_schema': view_schema,
            'view_name': table,
            'osm_schema': osm_schema,
            'osm_table': table
        })
    return ''.join(views)

def typed_view(name, view, mapping, alkis_schema, view_schema):
    column_defs = ['\ttype::VARCHAR AS "type"']

    columns = {}

    for column, value in view['columns'].items():
        column_defs.append('''\t%(value)s::%(type)s AS "%(column)s"''' % {
            'value': value[1],
            'type': value[0],
            'column': column
        })
        if value[1] not in ('NULL', '0'):
            columns[value[1]] = value[0]

    # remove 'special' columns to get all additional columns
    additional_columns = dict(columns)
    for c in [
        'short_source',
        'type',
        'code',
        'gml_id',
        'wkb_geometry',
    ]:
        additional_columns.pop(c, None)

    # also remove columns that contain wkb_geometry, for columns like
    # `ST_Area(wkb_geometry)`
    for c in list(additional_columns.keys()):
        if re.match(r'.*\bwkb_geometry\b', c):
            additional_columns.pop(c, None)

    queries = []
    for source_table, mapping_data in mapping['sources'].items():
        source_columns = []
        code_column = None

        if 'type' in mapping_data:
            source_columns.append("'%s' AS type" % mapping_data['type'])
        else:
            type_mapping = []
            for source_column in mapping_data['type_mapping']:
                code_column = source_column
                for values in mapping_data['type_mapping'][source_column]:
                    source_value, target_value = values
                    type_mapping.append((source_column, source_value, target_value))
            source_columns.append(type_case_mapping(type_mapping, default='NULL', name='type'))

        if 'short_source' in mapping_data:
            source_columns.append("'%s' AS short_source" % mapping_data['short_source'])
        else:
            source_columns.append("NULL::VARCHAR AS short_source")

        if code_column:
            source_columns.append("%s.%s AS code" % (source_table, code_column))
        else:
            source_columns.append("NULL::INT AS code")

        for col, typ in additional_columns.items():
            if col in mapping_data['extra_columns']:
                sql = mapping_data['extra_columns'][col]
                source_columns.append('%s::%s AS %s' % (sql, typ, col))
            else:
                source_columns.append('NULL AS ' + col)

        source_columns.append('gml_id')
        source_columns.append('wkb_geometry')

        filters = [geom_type_filter(view)]
        if 'filter' in view:
            for exclude_table, f in view['filter']:
                if exclude_table == source_table:
                    filters.append(f)

        source_columns = indent_lines(source_columns, 2)

        query = "\tSELECT\n %s \n\tFROM %s.%s\n" % (',\n'.join(source_columns), alkis_schema, source_table)

        if len(filters) > 0:
            query += "\tWHERE %s\n" % '\n\tAND '.join(filters)

        queries.append(query)

    return VIEW_TEMPLATE % {
        'view_schema': view_schema,
        'view_name': name,
        'columns': ',\n'.join(column_defs),
        'source': '( %s ) as data WHERE type IS NOT NULL' % '\tUNION ALL\n'.join(queries)
    }

def fnk_typed_view(name, view, mapping, fnk_schema, view_schema):
    column_defs = ['\ttype::VARCHAR AS "type"']

    columns = {}

    for column, value in view['columns'].items():
        column_defs.append('''\t%(value)s::%(type)s AS "%(column)s"''' % {
            'value': value[1],
            'type': value[0],
            'column': column
        })
        if value[1] not in ('NULL', '0'):
            columns[value[1]] = value[0]

    # remove 'special' columns to get all additional columns
    additional_columns = dict(columns)
    for c in [
        'short_source',
        'type',
        'code',
        'wkb_geometry',
        'objectid',
    ]:
        additional_columns.pop(c, None)

    # also remove columns that contain wkb_geometry, for columns like
    # `ST_Area(wkb_geometry)`
    for c in list(additional_columns.keys()):
        if re.match(r'.*\bwkb_geometry\b', c):
            additional_columns.pop(c, None)

    queries = []
    for source_table, mapping_data in mapping['sources'].items():
        source_columns = []
        code_column = None

        if 'type' in mapping_data:
            source_columns.append("'%s' AS type" % mapping_data['type'])
        else:
            type_mapping = []
            for source_column in mapping_data['type_mapping']:
                code_column = source_column
                for values in mapping_data['type_mapping'][source_column]:
                    source_value, target_value = values
                    type_mapping.append((source_column, source_value, target_value))
            source_columns.append(type_case_mapping(type_mapping, default='NULL', name='type'))

        source_columns.append("NULL::VARCHAR AS short_source")

        if code_column:
            source_columns.append("%s.%s AS code" % (source_table, code_column))
        else:
            source_columns.append("NULL::INT AS code")

        for col, typ in additional_columns.items():
            if col in mapping_data['extra_columns']:
                sql = mapping_data['extra_columns'][col]
                source_columns.append('%s::%s AS %s' % (sql, typ, col))
            else:
                source_columns.append('NULL AS ' + col)

        source_columns.append('objectid')
        source_columns.append('wkb_geometry')

        filters = [geom_type_filter(view)]
        if 'filter' in view:
            for exclude_table, f in view['filter']:
                if exclude_table == source_table:
                    filters.append(f)

        source_columns = indent_lines(source_columns, 2)

        query = "\tSELECT\n %s \n\tFROM %s.%s\n" % (',\n'.join(source_columns), fnk_schema, source_table)

        if len(filters) > 0:
            query += "\tWHERE %s\n" % '\n\tAND '.join(filters)

        queries.append(query)

    return VIEW_TEMPLATE % {
        'view_schema': view_schema,
        'view_name': name,
        'columns': ',\n'.join(column_defs),
        'source': '( %s ) as data WHERE type IS NOT NULL' % '\tUNION ALL\n'.join(queries)
    }

def atkis_typed_view(name, view, mapping, atkis_schema, view_schema):
    column_defs = ['\ttype::VARCHAR AS "type"']

    columns = {}

    for column, value in view['columns'].items():
        column_defs.append('''\t%(value)s::%(type)s AS "%(column)s"''' % {
            'value': value[1],
            'type': value[0],
            'column': column
        })
        if value[1] not in ('NULL', '0'):
            columns[value[1]] = value[0]

    # remove 'special' columns to get all additional columns
    additional_columns = dict(columns)
    for c in [
        'short_source',
        'nam',
        'code',
        'wkb_geometry',
        'type',
        'objid',
    ]:
        additional_columns.pop(c, None)

    # also remove columns that contain wkb_geometry, for columns like
    # `ST_Area(wkb_geometry)`
    for c in list(additional_columns.keys()):
        if re.match(r'.*\bwkb_geometry\b', c):
            additional_columns.pop(c, None)

    queries = []
    for source_table, mapping_data in mapping['sources'].items():
        source_columns = []
        code_column = None

        if 'type' in mapping_data:
            source_columns.append("'%s' AS type" % mapping_data['type'])
        else:
            type_mapping = []
            for source_column in mapping_data['type_mapping']:
                code_column = source_column
                for values in mapping_data['type_mapping'][source_column]:
                    source_value, target_value = values
                    type_mapping.append((source_column, source_value, target_value))
            source_columns.append(type_case_mapping(type_mapping, default='NULL', name='type'))

        source_columns.append("NULL::VARCHAR AS short_source")

        if code_column:
            source_columns.append("%s.%s AS code" % (source_table, code_column))
        else:
            source_columns.append("NULL::INT AS code")

        for col, typ in additional_columns.items():
            if col in mapping_data['extra_columns']:
                sql = mapping_data['extra_columns'][col]
                source_columns.append('%s::%s AS %s' % (sql, typ, col))
            else:
                source_columns.append('NULL AS ' + col)

        source_columns.append('nam')
        source_columns.append('objid')
        source_columns.append('wkb_geometry')

        filters = [geom_type_filter(view)]
        if 'filter' in view:
            for exclude_table, f in view['filter']:
                if exclude_table == source_table:
                    filters.append(f)

        source_columns = indent_lines(source_columns, 2)

        query = "\tSELECT\n %s \n\tFROM %s.%s\n" % (',\n'.join(source_columns), atkis_schema, source_table)

        if len(filters) > 0:
            query += "\tWHERE %s\n" % '\n\tAND '.join(filters)

        queries.append(query)

    return VIEW_TEMPLATE % {
        'view_schema': view_schema,
        'view_name': name,
        'columns': ',\n'.join(column_defs),
        'source': '( %s ) as data WHERE type IS NOT NULL' % '\tUNION ALL\n'.join(queries)
    }

def type_case_mapping(checks, default=None, name=None):
    """
    >>> type_case_mapping([('foo', 1, 'bar')])
    "CASE\\n\\t\\t\\tWHEN foo = 1 THEN 'bar'\\n\\t\\tEND"
    >>> type_case_mapping([('foo', 1, 'bar'), ('foo', 4, 'bar')], 'baz', 'type')
    "CASE\\n\\t\\t\\tWHEN foo IN (1, 4) THEN 'bar'\\n\\t\\t\\tELSE baz\\n\\t\\tEND AS type"
    """
    whens = []
    checks.sort(key=lambda x: (x[0], x[2]))
    for group, it in itertools.groupby(checks, lambda x: (x[0], x[2])):
        check = list(it)
        if len(check) == 1:
            whens.append("WHEN %s = %s THEN '%s'" % check[0])
        else:
            ins = ', '.join(str(c[1]) for c in check)
            whens.append("WHEN %s IN (%s) THEN '%s'" % (group[0], ins, group[1]))

    whens = indent_lines(whens, 3)
    result = 'CASE\n' + '\n'.join(whens)
    if default:
        result += '\n\t\t\tELSE %s' % default
    result += '\n\t\tEND'
    if name:
        result += ' AS %s' % name

    return result


def geom_type_filter(view):
    geom_type = view.get('geometry_type')

    if geom_type == 'Point':
        filter_types = "'ST_Point'"
    elif geom_type == 'Line':
        filter_types = "'ST_LineString', 'ST_MultiLineString'"
    elif geom_type in ('Polygon', None):
        filter_types = "'ST_Polygon','ST_MultiPolygon'"
    else:
        raise ValueError("unsupported geometry_type %s" % geom_type)
    return "ST_GeometryType(wkb_geometry) IN (%s)" % filter_types


def prepare_options(argv=None):
    parser = argparse.ArgumentParser(description='Create views for combining OSM with ALKIS data')

    parser.add_argument('--alkis-srid',
        help='SRID of alkis tables',
        default='25832',
    )
    parser.add_argument('--alkis-schema',
        help='Schema alkis tables are in',
        default='alkis',
    )
    parser.add_argument('--osm-schema',
        help='Schema osm tables are in',
        default='osm',
    )
    parser.add_argument('--view-schema',
        help='Target schema for created views',
        default='public',
    )
    parser.add_argument('--type-mapping',
        dest='type_mapping_file',
        help='CSV file mapping alkis values to osm values',
        default='type_mapping.csv',
    )
    parser.add_argument('--osm-mapping',
        help='Imposm3 mapping JSON',
    )

    options = parser.parse_args(argv)
    return options

def osm_tables_from_imposm_mapping(imposm_mapping):
    with open(imposm_mapping) as f:
        osm_mapping = yaml.safe_load(f)
    osm_tables = osm_mapping['tables'].keys() + osm_mapping['generalized_tables'].keys()
    osm_tables = ['osm_' + t for t in osm_tables] # use default prefix
    return osm_tables

