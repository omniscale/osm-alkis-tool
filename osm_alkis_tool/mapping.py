import yaml
from . union import Mapping as UnionMapping

class Mappings(object):
    def __init__(self, conf):
        self.conf = conf

    @classmethod
    def from_yaml(cls, filename):
        with open(filename) as f:
            conf = yaml.safe_load(f)
            return Mappings(conf)

    def define_typed_views(self):
        return self.conf.get('type_views', {})

    def define_single_table_views(self):
        views = []
        for templ in self.conf.get('sql_templates', {}).values():
            views.append(templ['sql'])
        return views

    def union_mappings(self, schema):
        mappings = []
        for m in self.conf.get('union_tables', {}):
            mappings.append(
                UnionMapping(
                    table=m['table'],
                    schema=schema,
                    group_by=m['group_by'],
                    union_buffer=m['union_buffer'],
                    srid=m['srid'],
                    union_columns=m['union_columns'],
                    extra_columns=m.get('extra_columns', []),
                    tolerances=m['tolerances'],
                    _filter=m.get('filter'),
                )
            )
        return mappings

    def combined_views(self):
        return self.conf.get('combined_tables', {}).items()


if __name__ == '__main__':
    import sys
    mappings = Mappings.from_yaml(sys.argv[1])
    print mappings
