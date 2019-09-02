import logging

from . config import load_config
from . import tasks, combined

log = logging.getLogger(__name__)

import click


def validate_config(ctx, param, value):
    try:
        config = load_config(value)
        return config
    except Exception as e:
        raise click.BadParameter('unable to open --config %s: %s' % (value, e))

@click.group(chain=True)
@click.option('--verbose', is_flag=True)
@click.option('--config', callback=validate_config, required=True)
@click.option('--region', default='')
@click.pass_context
def cli(ctx, verbose, config, region):
    """
    OSM/ALKIS import/updater
    """
    ctx.obj = {}
    ctx.obj['CONFIG'] = config
    ctx.obj['VERBOSE'] = verbose

    if region:
        if region not in config['alkis']['regions']:
            raise click.BadParameter('--region not in alkis.regions of --config')

        ctx.obj['ALKIS_SCHEMA'] = config['alkis']['import_schema_prefix'] + region
        ctx.obj['ALKIS_VIEW_SCHEMA'] = config['alkis']['view_schema_prefix'] + region
    else:
        ctx.obj['ALKIS_SCHEMA'] = config['alkis']['schema']
        ctx.obj['ALKIS_VIEW_SCHEMA'] = 'public'

    if 'fnk' in config:
        ctx.obj['FNK_SCHEMA'] = config['fnk']['import_schema']
        ctx.obj['FNK_VIEW_SCHEMA'] = config['fnk']['view_schema']

    if 'atkis' in config:
        ctx.obj['ATKIS_SCHEMA'] = config['atkis']['import_schema']
        ctx.obj['ATKIS_VIEW_SCHEMA'] = config['atkis']['view_schema']

    import sys
    import codecs
    if (sys.version_info < (3, )):
        sys.stdout = codecs.getwriter('utf8')(sys.stdout)

    logging.basicConfig(
        level=logging.INFO,
        format='[%(asctime)s] [%(levelname)s] %(message)s',
    )


@cli.command(name='create-db')
@click.pass_context
def create_db(ctx):
    """
    Create new database with user and required DB extensions.
    """
    tasks.create_db(ctx.obj['CONFIG'].db_config())


@cli.command(name='init-alkis-schema')
@click.pass_context
def init_alkis_schema(ctx):
    """
    Init schema with PostNAS tables and functions.
    """
    tasks.init_alkis_schema(
        ctx.obj['CONFIG'].db_config(),
        schema=ctx.obj['ALKIS_SCHEMA'],
        srid=ctx.obj['CONFIG']['alkis']['srid'],
    )



@cli.command(name='drop-alkis-schema')
@click.confirmation_option(prompt='Are you sure you want to drop the schema?')
@click.pass_context
def drop_alkis_schema(ctx):
    """
    Drop schema with PostNAS tables and functions.
    """
    tasks.drop_alkis_schema(
        ctx.obj['CONFIG'].db_config(),
        schema=ctx.obj['ALKIS_SCHEMA'],
    )

@cli.command(name='init-fnk-schema')
@click.pass_context
def init_fnk_schema(ctx):
    """
    Init schema for fnk import
    """
    tasks.init_fnk_schema(
        ctx.obj['CONFIG'].db_config(),
        schema=ctx.obj['FNK_SCHEMA']
    )

@cli.command(name='drop-fnk-schema')
@click.confirmation_option(prompt='Are you sure you want to drop the schema?')
@click.pass_context
def drop_fnk_schema(ctx):
    """
    Drop schema with PostNAS tables and functions.
    """
    tasks.drop_fnk_schema(
        ctx.obj['CONFIG'].db_config(),
        schema=ctx.obj['FNK_SCHEMA'],
    )

@cli.command(name='init-atkis-schema')
@click.pass_context
def init_atkis_schema(ctx):
    """
    Init schema for atkis import
    """
    tasks.init_atkis_schema(
        ctx.obj['CONFIG'].db_config(),
        schema=ctx.obj['ATKIS_SCHEMA']
    )

@cli.command(name='drop-atkis-schema')
@click.confirmation_option(prompt='Are you sure you want to drop the schema?')
@click.pass_context
def drop_atkis_schema(ctx):
    """
    Drop schema with atkis tables.
    """
    tasks.drop_atkis_schema(
        ctx.obj['CONFIG'].db_config(),
        schema=ctx.obj['ATKIS_SCHEMA'],
    )

@cli.command(name='drop-db')
@click.confirmation_option(prompt='Are you sure you want to drop the db?')
@click.pass_context
def drop_db(ctx):
    """
    Drop complete database.
    """
    tasks.drop_db(ctx.obj['CONFIG'].db_config())


@cli.command(name='imposm-import')
@click.pass_context
def imposm_import(ctx):
    """
    Import OSM data into import schema (see imposm-deploy).
    """
    tasks.imposm_import(ctx.obj['CONFIG'].db_config(), ctx.obj['CONFIG'])

@cli.command(name='imposm-deploy')
@click.pass_context
def imposm_deploy(ctx):
    """
    Move OSM data from import schema into public schema. Keeps backup of old
    public tables in backup schema.
    """
    tasks.imposm_deploy(ctx.obj['CONFIG'].db_config(), ctx.obj['CONFIG'])

@cli.command(name='imposm-revert-deploy')
@click.pass_context
def imposm_revert_deploy(ctx):
    """
    Revert previous imposm-deploy.
    """
    tasks.imposm_revert_deploy(ctx.obj['CONFIG'].db_config(), ctx.obj['CONFIG'])

@cli.command(name='imposm-run')
@click.pass_context
def imposm_run(ctx):
    """
    Keep OSM data up-to-date. Runs in foreground.
    """
    tasks.imposm_run(ctx.obj['CONFIG'].db_config(), ctx.obj['CONFIG'])


@cli.command(name='alkis-import')
@click.option('--nas-dir', required=True)
@click.option('--force', is_flag=True)
@click.pass_context
def alkis_import(ctx, nas_dir, force):
    tasks.alkis_import(
        ctx.obj['CONFIG'].db_config(),
        ctx.obj['CONFIG'],
        nas_dir=nas_dir,
        schema=ctx.obj['ALKIS_SCHEMA'],
        force=force,
    )

@cli.command(name='alkis-union')
@click.pass_context
def alkis_union(ctx):
    mappings = ctx.obj['CONFIG'].mappings()
    mappings = mappings.union_mappings(schema=ctx.obj['ALKIS_VIEW_SCHEMA'])
    tasks.alkis_union(ctx.obj['CONFIG'].db_config(), ctx.obj['CONFIG'],
        mappings=mappings,
    )

@cli.command(name='fnk-import')
@click.option('--sqlite-file', required=True)
@click.pass_context
def fnk_import(ctx, sqlite_file):
    tasks.fnk_import(
        ctx.obj['CONFIG'].db_config(),
        ctx.obj['CONFIG'],
        sqlite_file=sqlite_file,
        schema=ctx.obj['FNK_SCHEMA']
    )

@cli.command(name='fnk-union')
@click.pass_context
def fnk_union(ctx):
    mappings = ctx.obj['CONFIG'].fnk_mappings()
    mappings = mappings.union_mappings(schema=ctx.obj['FNK_VIEW_SCHEMA'])
    tasks.fnk_union(ctx.obj['CONFIG'].db_config(), ctx.obj['CONFIG'],
        mappings=mappings,
    )

@cli.command(name='fnk-create-public-tables')
@click.pass_context
def fnk_create_public_tables(ctx):
    mappings = ctx.obj['CONFIG'].fnk_mappings()
    src_schemas = [ctx.obj['FNK_VIEW_SCHEMA']]
    tasks.create_combined_tables(ctx.obj['CONFIG'].db_config(), ctx.obj['CONFIG'], mappings,
        src_schemas=src_schemas,
    )

@cli.command(name='atkis-import')
@click.option('--shp-dir', required=True)
@click.pass_context
def atkis_import(ctx, shp_dir):
    tasks.atkis_import(
        ctx.obj['CONFIG'].db_config(),
        ctx.obj['CONFIG'],
        shp_dir=shp_dir,
        schema=ctx.obj['ATKIS_SCHEMA']
    )

@cli.command(name='atkis-union')
@click.pass_context
def atkis_union(ctx):
    mappings = ctx.obj['CONFIG'].atkis_mappings()
    mappings = mappings.union_mappings(schema=ctx.obj['ATKIS_VIEW_SCHEMA'])
    tasks.atkis_union(ctx.obj['CONFIG'].db_config(), ctx.obj['CONFIG'],
        mappings=mappings,
    )

@cli.command(name='atkis-create-public-tables')
@click.pass_context
def atkis_create_public_tables(ctx):
    mappings = ctx.obj['CONFIG'].atkis_mappings()
    src_schemas = [ctx.obj['ATKIS_VIEW_SCHEMA']]
    tasks.create_combined_tables(ctx.obj['CONFIG'].db_config(), ctx.obj['CONFIG'], mappings,
        src_schemas=src_schemas,
    )

@cli.command(name='import-views')
@click.option('--sql-file', help='import existing view file. build-views gets called if not provided')
@click.pass_context
def import_views(ctx, sql_file=None):
    tasks.import_views(
        ctx.obj['CONFIG'].db_config(),
        config=ctx.obj['CONFIG'],
        sql_file=sql_file,
        alkis_schema=ctx.obj['ALKIS_SCHEMA'],
        view_schema=ctx.obj['ALKIS_VIEW_SCHEMA'],
    )

@cli.command(name='fnk-import-views')
@click.option('--sql-file', help='import existing view file. build-views gets called if not provided')
@click.pass_context
def fnk_import_views(ctx, sql_file=None):
    tasks.fnk_import_views(
        ctx.obj['CONFIG'].db_config(),
        config=ctx.obj['CONFIG'],
        sql_file=sql_file,
        fnk_schema=ctx.obj['FNK_SCHEMA'],
        view_schema=ctx.obj['FNK_VIEW_SCHEMA'],
    )

@cli.command(name='atkis-import-views')
@click.option('--sql-file', help='import existing view file. build-views gets called if not provided')
@click.pass_context
def atkis_import_views(ctx, sql_file=None):
    tasks.atkis_import_views(
        ctx.obj['CONFIG'].db_config(),
        config=ctx.obj['CONFIG'],
        sql_file=sql_file,
        atkis_schema=ctx.obj['ATKIS_SCHEMA'],
        view_schema=ctx.obj['ATKIS_VIEW_SCHEMA'],
    )

@cli.command(name='build-views')
@click.pass_context
def build_views(ctx):
    mappings = ctx.obj['CONFIG'].mappings()
    print(tasks.build_views(ctx.obj['CONFIG'], mappings))

@cli.command(name='create-combined-tables')
@click.pass_context
def create_combined_tables(ctx):
    mappings = ctx.obj['CONFIG'].mappings()
    tasks.create_combined_region_tables(ctx.obj['CONFIG'].db_config(), ctx.obj['CONFIG'], mappings)

if __name__ == '__main__':
    cli()
