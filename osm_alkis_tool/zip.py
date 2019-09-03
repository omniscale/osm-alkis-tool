# -*- coding: utf-8 -*-

from __future__ import absolute_import

import glob
import gzip
import os
import shutil
import tempfile
import zipfile


def dir_reader(directory, check_file=None):
    zipfiles = glob.glob(os.path.join(directory, '*.zip'))
    zipfiles.sort()
    for filename in zipfiles:
        for xmlfile in zip_reader(filename, check_file=check_file):
            yield xmlfile


SUPPORTED_XML_EXTENSIONS = ('.xml', '.xml.gz')
def zip_reader(filename, check_file=None):
    with zipfile.ZipFile(filename, 'r') as zf:
        files = zf.namelist()
        files.sort()
        for fname in files:
            if not fname.endswith(SUPPORTED_XML_EXTENSIONS):
                continue

            if check_file and not check_file(fname):
                continue

            tmpdir = tempfile.mkdtemp()
            try:
                zf.extract(fname, tmpdir)
                tmpfname = os.path.join(tmpdir, fname)

                if fname.endswith('.xml.gz'):
                    # gunzip .xml.gz files
                    xmlf = gzip.GzipFile(tmpfname)
                    xmlfname = fname[:-len('.gz')]
                    tmpfname = os.path.join(tmpdir, xmlfname)
                    with open(tmpfname, 'wb') as f:
                        shutil.copyfileobj(xmlf, f)

                yield tmpfname
            finally:
                shutil.rmtree(tmpdir)

