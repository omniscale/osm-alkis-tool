# -*- coding: utf-8 -*-

from __future__ import absolute_import

import json

from shapely.geometry import box, mapping
from shapely.ops import cascaded_union
from mapproxy.grid import tile_grid


def load(expire_file):
    grid = tile_grid(srs=3857)
    boxes = []
    for line in open(expire_file):
        z, x, y = map(int, line.split('/'))
        boxes.append(box(*grid.tile_bbox((x, y, z))))

    print(json.dumps(mapping(cascaded_union(boxes))))


if __name__ == '__main__':
    load('../examples/expire/20160209/155439.011.tiles')
