# -*- coding: utf-8 -*-

from __future__ import absolute_import

import os

from collections import namedtuple

import yaml

from . mapping import Mappings
from . views import read_type_mapping, fnk_read_type_mapping, atkis_read_type_mapping

DBConfig = namedtuple('DBConfig', [
    'name',
    'username',
    'password',
    'host',
    'port',
])

class Config(dict):
    def db_config(self):
        return DBConfig(
            name=self['database']['name'],
            username=self['database']['username'],
            password=self['database']['password'],
            host=self['database']['host'],
            port=self['database']['port'],
        )

    def mappings(self):
        mapping_file = os.path.join(self['__here__'], self['views']['mapping'])
        return Mappings.from_yaml(mapping_file)

    def type_mappings(self):
        mapping_file = os.path.join(self['__here__'], self['views']['type_mapping'])
        return read_type_mapping(mapping_file)

    def fnk_mappings(self):
        mapping_file = os.path.join(self['__here__'], self['views']['fnk_mapping'])
        return Mappings.from_yaml(mapping_file)

    def fnk_type_mappings(self):
        mapping_file = os.path.join(self['__here__'], self['views']['fnk_type_mapping'])
        return fnk_read_type_mapping(mapping_file)

    def atkis_mappings(self):
        mapping_file = os.path.join(self['__here__'], self['views']['atkis_mapping'])
        return Mappings.from_yaml(mapping_file)

    def atkis_type_mappings(self):
        mapping_file = os.path.join(self['__here__'], self['views']['atkis_type_mapping'])
        return atkis_read_type_mapping(mapping_file)


def load_config(config_file):
    with open(config_file) as f:
        data = yaml.safe_load(f)
        data['__here__'] = os.path.abspath(os.path.dirname(config_file))

    return Config(data)
