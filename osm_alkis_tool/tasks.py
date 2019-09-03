# -*- coding: utf-8 -*-
# pylint: disable=global-statement, unused-argument

from __future__ import absolute_import

import codecs
import glob
import logging
import os
import re
import subprocess

import psycopg2

from . zip import dir_reader

log = logging.getLogger(__name__)

def drop_db(db):
    subprocess.call('''
        dropdb %(db_name)s || echo 'db already dropped'
        ''' % {
            'db_name': db.name
        },
        shell=True,
    )


def create_db(db):
    subprocess.call('''
        createuser %(db_username)s --no-createrole --no-superuser --no-createdb || echo 'user exists'
        createdb %(db_name)s -O %(db_username)s
        psql -d %(db_name)s -c "CREATE EXTENSION postgis;"
        psql -d %(db_name)s -c "CREATE EXTENSION hstore;"
        psql -d %(db_name)s -c "ALTER USER %(db_username)s WITH PASSWORD '%(db_password)s';"
        ''' % {
            'db_name': db.name,
            'db_username': db.username,
            'db_password': db.password,
        },
        shell=True,
    )

def init_alkis_schema(db, schema, srid):
    env = os.environ.copy()
    env['PGPASSWORD'] = db.password
    subprocess.check_call('''
        echo "CREATE SCHEMA IF NOT EXISTS \"%(alkis_schema)s\";" | psql -d %(db_name)s -U %(db_username)s -h %(db_host)s -p %(db_port)s
        (echo "SET search_path TO '%(alkis_schema)s', 'public';" && cat alkis_PostNAS_schema.sql) \
            | psql -d %(db_name)s -U %(db_username)s -h %(db_host)s -p %(db_port)s -v alkis_epsg=%(alkis_srid)s
        ''' % {
            'db_name': db.name,
            'db_host': db.host,
            'db_port': db.port,
            'db_username': db.username,
            'alkis_schema': schema,
            'alkis_srid': srid,
        },
        shell=True,
        env=env,
        cwd=os.path.join(os.path.dirname(__file__), 'postnas'),
    )

def init_fnk_schema(db, schema):
    env = os.environ.copy()
    env['PGPASSWORD'] = db.password
    subprocess.check_call('''
        echo "CREATE SCHEMA IF NOT EXISTS \"%(fnk_schema)s\";" | psql -d %(db_name)s -U %(db_username)s -h %(db_host)s -p %(db_port)s
        ''' % {
            'db_name': db.name,
            'db_host': db.host,
            'db_port': db.port,
            'db_username': db.username,
            'fnk_schema': schema
        },
        shell=True,
        env=env,
    )

def init_atkis_schema(db, schema):
    env = os.environ.copy()
    env['PGPASSWORD'] = db.password
    subprocess.check_call('''
        echo "CREATE SCHEMA IF NOT EXISTS \"%(atkis_schema)s\";" | psql -d %(db_name)s -U %(db_username)s -h %(db_host)s -p %(db_port)s
        ''' % {
            'db_name': db.name,
            'db_host': db.host,
            'db_port': db.port,
            'db_username': db.username,
            'atkis_schema': schema
        },
        shell=True,
        env=env,
    )

def drop_alkis_schema(db, schema):
    env = os.environ.copy()
    env['PGPASSWORD'] = db.password
    subprocess.check_call('''
        echo "DROP SCHEMA IF EXISTS \"%(alkis_schema)s\" CASCADE;" | psql -d %(db_name)s -U %(db_username)s -h %(db_host)s -p %(db_port)s
        ''' % {
            'db_name': db.name,
            'db_host': db.host,
            'db_port': db.port,
            'db_username': db.username,
            'alkis_schema': schema,
        },
        shell=True,
        env=env,
    )

def drop_fnk_schema(db, schema):
    env = os.environ.copy()
    env['PGPASSWORD'] = db.password
    subprocess.check_call('''
        echo "DROP SCHEMA IF EXISTS \"%(fnk_schema)s\" CASCADE;" | psql -d %(db_name)s -U %(db_username)s -h %(db_host)s -p %(db_port)s
        ''' % {
            'db_name': db.name,
            'db_host': db.host,
            'db_port': db.port,
            'db_username': db.username,
            'fnk_schema': schema,
        },
        shell=True,
        env=env,
    )

def drop_atkis_schema(db, schema):
    env = os.environ.copy()
    env['PGPASSWORD'] = db.password
    subprocess.check_call('''
        echo "DROP SCHEMA IF EXISTS \"%(atkis_schema)s\" CASCADE;" | psql -d %(db_name)s -U %(db_username)s -h %(db_host)s -p %(db_port)s
        ''' % {
            'db_name': db.name,
            'db_host': db.host,
            'db_port': db.port,
            'db_username': db.username,
            'atkis_schema': schema,
        },
        shell=True,
        env=env,
    )

def imposm_import(db, config):
    env = os.environ.copy()
    subprocess.check_call('''
        %(binary)s import \
            -config %(imposm_config)s \
            -read %(osm_extract)s \
            -write \
            -diff \
            -quiet \
            -overwritecache
        ''' % {
            'binary': config['imposm']['binary'],
            'osm_extract': config['imposm']['initial_extract'],
            'imposm_config': config['imposm']['config'],
        },
        shell=True,
        env=env,
    )

def imposm_deploy(db, config):
    env = os.environ.copy()
    subprocess.check_call('''
        %(binary)s import \
            -config %(imposm_config)s \
            -deployproduction
        ''' % {
            'binary': config['imposm']['binary'],
            'imposm_config': config['imposm']['config'],
        },
        shell=True,
        env=env,
    )

def imposm_revert(db, config):
    env = os.environ.copy()
    subprocess.check_call('''
        %(binary)s import \
            -config %(imposm_config)s \
            -revertdeploy
        ''' % {
            'binary': config['imposm']['binary'],
            'imposm_config': config['imposm']['config'],
        },
        shell=True,
        env=env,
    )

def imposm_run(db, config):
    env = os.environ.copy()
    subprocess.check_call('''
        %(binary)s run \
            -config %(config)s
        ''' % {
            'binary': config['imposm']['binary'],
            'config': config['imposm']['config'],
        },
        shell=True,
        env=env,
    )


alkis_import_called = False
alkis_import_did_imports = False

def alkis_import(db, config, schema, nas_dir, force=False):

    global alkis_import_called
    alkis_import_called = True

    create_alkis_version_table(db, schema=schema)

    env = os.environ.copy()
    # extend list of valid NAS XML schemas to improve OGR's format detection
    # otherwise it will use GML format and not fill the ax_*-tables
    env['NAS_INDICATOR'] = 'NAS-Operationen.xsd;NAS-Operationen_optional.xsd;AAA-Fachschema.xsd;ASDKOM-NAS-Operationen_1_1_NRW.xsd;aaa.xsd'
    # disable GML format: NAS or exit
    env['OGR_SKIP'] = 'GML'
    # currupted geometries should not stop the import
    env['NAS_SKIP_CORRUPTED_FEATURES'] = 'YES'

    def do_import(filename):
        # -skipfailures \
        subprocess.check_call('''
            %(ogr2ogr)s \
                -append \
                -update \
                -s_srs EPSG:%(nas_srid)s \
                -t_srs EPSG:%(alkis_srid)s \
                -f PostgreSQL \
                -ds_transaction \
                -nlt CONVERT_TO_LINEAR \
                --config PG_USE_COPY YES \
                PG:"host=%(db_host)s port=%(db_port)s user=%(db_username)s password=%(db_password)s dbname=%(db_name)s active_schema=%(alkis_schema)s" \
                '%(file)s'
            ''' % {
                'ogr2ogr': config['alkis'].get('ogr2ogr', 'ogr2ogr'),
                'db_name': db.name,
                'db_username': db.username,
                'db_password': db.password,
                'db_host': db.host,
                'db_port': db.port,
                'alkis_schema': schema,
                'nas_srid': config['alkis']['nas_srid'],
                'alkis_srid': config['alkis']['srid'],
                'file': filename,
            },
            shell=True,
            env=env,
        )

    def check_file(fname):
        fname = os.path.basename(fname)
        if fname.endswith('.gz'):
            fname = fname[:-3]
        imported = check_alkis_file_imported(db, schema=schema, filename=fname)
        if imported and not force:
            return False
        return True

    global alkis_import_did_imports  #
    for fname in dir_reader(nas_dir, check_file=check_file):
        alkis_import_did_imports = True
        log.info("importing %s", fname)
        do_import(fname)
        mark_alkis_file_imported(db, schema=schema, filename=os.path.basename(fname))
        alkis_truncate_delete_table(db, schema)

def fnk_import(db, config, schema, sqlite_file):
    env = os.environ.copy()

    subprocess.check_call('''
        %(ogr2ogr)s -overwrite \
            -s_srs EPSG:%(fnk_srid)s \
            -t_srs EPSG:%(db_srid)s \
            -f PostgreSQL \
            -ds_transaction \
            -gt unlimited \
            --config PG_USE_COPY YES \
            PG:"host=%(db_host)s port=%(db_port)s user=%(db_user)s password=%(db_password)s dbname=%(db_name)s active_schema=%(fnk_schema)s" \
            '%(file)s'
        ''' % {
            'ogr2ogr': config['fnk'].get('ogr2ogr', 'ogr2ogr'),
            'db_name': config['database']['name'],
            'db_user': config['database']['username'],
            'db_password': config['database']['password'],
            'db_host': config['database']['host'],
            'db_port': config['database']['port'],
            'fnk_schema': config['fnk']['import_schema'],
            'fnk_srid': config['fnk']['source_srid'],
            'db_srid': config['fnk']['srid'],
            'file': sqlite_file,
        },
        shell=True,
        env=env,
    )

def atkis_import(db, config, schema, shp_dir):
    env = os.environ.copy()

    shp_files = glob.glob(os.path.join(shp_dir, '*.shp'))

    for shp_file in shp_files:
        subprocess.check_call('''
            %(ogr2ogr)s -overwrite \
                -s_srs EPSG:%(atkis_srid)s \
                -t_srs EPSG:%(db_srid)s \
                -f PostgreSQL \
                -ds_transaction \
                --config PG_USE_COPY YES \
                PG:"host=%(db_host)s port=%(db_port)s user=%(db_user)s password=%(db_password)s dbname=%(db_name)s active_schema=%(atkis_schema)s" \
                '%(file)s'
            ''' % {
                'ogr2ogr': config['atkis'].get('ogr2ogr', 'ogr2ogr'),
                'db_name': config['database']['name'],
                'db_user': config['database']['username'],
                'db_password': config['database']['password'],
                'db_host': config['database']['host'],
                'db_port': config['database']['port'],
                'atkis_schema': config['atkis']['import_schema'],
                'atkis_srid': config['atkis']['source_srid'],
                'db_srid': config['atkis']['srid'],
                'file': shp_file,
            },
            shell=True,
            env=env,
        )

def build_views(config, mappings):
    from . import views

    type_mapping = config.type_mappings()

    sql = views.create_views(type_mapping,
        mappings,
        alkis_srid=config['alkis']['srid'],
        alkis_schema=config['alkis']['schema'],
        view_schema='public',
    )

    if 'mapping_file' in config['imposm']:
        osm_tables = views.osm_tables_from_imposm_mapping(config['imposm']['mapping_file'])
        sql += '\n' + views.create_osm_views(
            view_schema='public',
            osm_schema=config['imposm']['schema'],
            osm_tables=osm_tables,
        )

    return sql

def fnk_build_views(config, mappings):
    from . import views
    type_mapping = config.fnk_type_mappings()

    sql = views.create_fnk_views(type_mapping,
        mappings,
        fnk_srid=config['fnk']['srid'],
        fnk_schema=config['fnk']['import_schema'],
        view_schema=config['fnk']['view_schema'],
    )
    return sql

def atkis_build_views(config, mappings):
    from . import views
    type_mapping = config.atkis_type_mappings()

    sql = views.create_atkis_views(type_mapping,
        mappings,
        atkis_srid=config['atkis']['srid'],
        atkis_schema=config['atkis']['import_schema'],
        view_schema=config['atkis']['view_schema'],
    )
    return sql

def create_combined_region_tables(db, config, mappings):
    prefix = config['alkis']['view_schema_prefix']
    src_schemas = [prefix + r for r in config['alkis']['regions'].keys()]
    create_combined_tables(db, config, mappings, src_schemas=src_schemas)

def create_combined_tables(db, config, mappings, src_schemas):
    from . import combined

    tables = []
    for table, conf in mappings.combined_views():
        if conf and 'exclude_schemas' in conf:
            tables.append((table, list(set(src_schemas) - set(conf['exclude_schemas']))))
        else:
            tables.append((table, src_schemas))

    dst_schema = 'public'
    conn = create_conn(db)
    combined.create_combined_tables(conn, tables, dst_schema)

def alkis_union(db, config, mappings):
    if alkis_import_called and not alkis_import_did_imports:
        # do not build unions if called with alkis-import and no files were imported
        return

    from . import union

    connection = 'postgresql://%(db_username)s:%(db_password)s@%(db_host)s:%(db_port)s/%(db_name)s' % {
            'db_name': db.name,
            'db_username': db.username,
            'db_password': db.password,
            'db_host': db.host,
            'db_port': db.port,
    }
    transaction = union.Transaction(connection, mappings)

    transaction.process()
    transaction.finish(with_vacuum=True)

def fnk_union(db, config, mappings):
    from . import union

    connection = 'postgresql://%(db_username)s:%(db_password)s@%(db_host)s:%(db_port)s/%(db_name)s' % {
            'db_name': db.name,
            'db_username': db.username,
            'db_password': db.password,
            'db_host': db.host,
            'db_port': db.port,
    }
    transaction = union.Transaction(connection, mappings)

    transaction.process()
    transaction.finish(with_vacuum=True)

def atkis_union(db, config, mappings):
    from . import union

    connection = 'postgresql://%(db_username)s:%(db_password)s@%(db_host)s:%(db_port)s/%(db_name)s' % {
            'db_name': db.name,
            'db_username': db.username,
            'db_password': db.password,
            'db_host': db.host,
            'db_port': db.port,
    }
    transaction = union.Transaction(connection, mappings)

    transaction.process()
    transaction.finish(with_vacuum=True)

def import_views(db, config, sql_file, alkis_schema, view_schema):
    if alkis_import_called and not alkis_import_did_imports:
        # do not create views if called with alkis-import and no files were imported
        return

    if sql_file:
        with codecs.open(sql_file, encoding='utf-8') as f:
            sql = f.read()
    else:
        sql = build_views(config, config.mappings())

    conn = create_conn(db)
    def replacer(matchobj):
        var = matchobj.group(1)
        if var == 'alkis_schema':
            return alkis_schema
        elif var == 'view_schema':
            return view_schema
        raise ValueError('unknown variable in view "%s"' % var)
    sql, _ = re.subn(r'\{\{([a-zA-Z][a-zA-Z0-9_]*)\}\}', replacer, sql)

    with conn.cursor() as cur:
        cur.execute('CREATE SCHEMA IF NOT EXISTS %s' % view_schema)
        cur.execute(sql)
    conn.commit()

def fnk_import_views(db, config, sql_file, fnk_schema, view_schema):
    if sql_file:
        with codecs.open(sql_file, encoding='utf-8') as f:
            sql = f.read()
    else:
        sql = fnk_build_views(config, config.fnk_mappings())

    conn = create_conn(db)
    def replacer(matchobj):
        var = matchobj.group(1)
        if var == 'fnk_schema':
            return fnk_schema
        elif var == 'view_schema':
            return view_schema
        raise ValueError('unknown variable in view "%s"' % var)
    sql, _ = re.subn(r'\{\{([a-zA-Z][a-zA-Z0-9_]*)\}\}', replacer, sql)

    with conn.cursor() as cur:
        cur.execute('CREATE SCHEMA IF NOT EXISTS %s' % view_schema)
        cur.execute(sql)
    conn.commit()

def atkis_import_views(db, config, sql_file, atkis_schema, view_schema):
    if sql_file:
        with codecs.open(sql_file, encoding='utf-8') as f:
            sql = f.read()
    else:
        sql = atkis_build_views(config, config.atkis_mappings())

    conn = create_conn(db)
    def replacer(matchobj):
        var = matchobj.group(1)
        if var == 'atkis_schema':
            return atkis_schema
        elif var == 'view_schema':
            return view_schema
        raise ValueError('unknown variable in view "%s"' % var)
    sql, _ = re.subn(r'\{\{([a-zA-Z][a-zA-Z0-9_]*)\}\}', replacer, sql)

    with conn.cursor() as cur:
        cur.execute('CREATE SCHEMA IF NOT EXISTS %s' % view_schema)
        cur.execute(sql)
    conn.commit()

def create_conn(db):
    return psycopg2.connect(
        database=db.name,
        user=db.username,
        password=db.password,
        host=db.host,
        port=db.port,
    )

def create_alkis_version_table(db, schema):
    conn = create_conn(db)
    with conn.cursor() as cur:
        cur.execute("SET search_path TO %s, 'public'", (schema, ))
        cur.execute("""
            CREATE TABLE IF NOT EXISTS imported_files (
              id serial NOT NULL,
              time timestamp DEFAULT CURRENT_TIMESTAMP,
              file varchar
            )""")
    conn.commit()

def check_alkis_file_imported(db, schema, filename):
    conn = create_conn(db)
    with conn.cursor() as cur:
        cur.execute("SET search_path TO %s, 'public'", (schema, ))
        cur.execute("SELECT time FROM imported_files WHERE file = %s", (filename, ))
        row = cur.fetchone()
        if row is not None:
            return True
    return False

def mark_alkis_file_imported(db, schema, filename):
    conn = create_conn(db)
    with conn.cursor() as cur:
        cur.execute("SET search_path TO %s, 'public'", (schema, ))
        cur.execute("INSERT INTO imported_files (file) VALUES(%s)", (filename, ))
    conn.commit()

def alkis_truncate_delete_table(db, schema):
    conn = create_conn(db)
    with conn.cursor() as cur:
        cur.execute("SET search_path TO %s, 'public'", (schema, ))
        cur.execute("TRUNCATE delete")
    conn.commit()
