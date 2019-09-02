import os

from osm_alkis_tool.zip import zip_reader



"""

Content of test files:

Archive:  zipfiles/gzipped_xml_file.zip
  Length     Date   Time    Name
 --------    ----   ----    ----
       43  01-31-17 12:08   gzipped_xml_file_1.xml.gz
       43  01-31-17 12:08   gzipped_xml_file_2.xml.gz
        0  01-31-17 12:09   file_to_ignore
 --------                   -------
       86                   3 files
Archive:  zipfiles/subdir_mixed.zip
  Length     Date   Time    Name
 --------    ----   ----    ----
        0  01-31-17 12:51   subdir/
        0  01-31-17 12:51   subdir/file_to_ignore
       48  01-31-17 12:51   subdir/subdir_gzipped_xml_file.xml.gz
        0  01-31-17 12:51   subdir/subdir_xml_file.xml
 --------                   -------
       48                   4 files
Archive:  zipfiles/xml_file.zip
  Length     Date   Time    Name
 --------    ----   ----    ----
        0  01-31-17 12:52   xml_file_1.xml
        0  01-31-17 12:52   xml_file_2.xml
        0  01-31-17 12:09   file_to_ignore
 --------                   -------
        0                   3 files
Archive:  zipfiles/zipped_xml_file.zip
  Length     Date   Time    Name
 --------    ----   ----    ----
        0  01-31-17 12:07   zipped_xml_file.xml
 --------                   -------
        0                   1 file


"""

here = os.path.dirname(__file__)

def test_xml_zip():
    for i, tmpfile in enumerate(zip_reader(os.path.join(here, 'zipfiles', 'xml_file.zip'))):
        if i == 0:
            assert tmpfile.endswith('xml_file_1.xml'), tmpfile
            assert os.path.exists(tmpfile)
        if i == 1:
            assert tmpfile.endswith('xml_file_2.xml'), tmpfile
            assert os.path.exists(tmpfile)
        if i >= 2:
            assert False, 'got more then the expected files'

    assert not os.path.exists(tmpfile), 'tmpfile (%s) not removed' % tmpfile


def test_gzipped_xml_zip():
    for i, tmpfile in enumerate(zip_reader(os.path.join(here, 'zipfiles', 'gzipped_xml_file.zip'))):
        if i == 0:
            assert tmpfile.endswith('gzipped_xml_file_1.xml'), tmpfile
            assert os.path.exists(tmpfile)
        if i == 1:
            assert tmpfile.endswith('gzipped_xml_file_2.xml'), tmpfile
            assert os.path.exists(tmpfile)
        if i >= 2:
            assert False, 'got more then the expected files'

    assert not os.path.exists(tmpfile), 'tmpfile (%s) not removed' % tmpfile


def test_subdir_mixed_zip():
    for i, tmpfile in enumerate(zip_reader(os.path.join(here, 'zipfiles', 'subdir_mixed.zip'))):
        if i == 0:
            assert tmpfile.endswith('subdir_gzipped_xml_file.xml'), tmpfile
            assert os.path.exists(tmpfile)
        if i == 1:
            assert tmpfile.endswith('subdir_xml_file.xml'), tmpfile
            assert os.path.exists(tmpfile)
        if i >= 2:
            assert False, 'got more then the expected files'

    assert not os.path.exists(tmpfile), 'tmpfile (%s) not removed' % tmpfile


def test_subdir_mixed_zip_check_file():
    def check_file(fname):
        return 'subdir_xml_file' in fname

    for i, tmpfile in enumerate(zip_reader(os.path.join(here, 'zipfiles', 'subdir_mixed.zip'), check_file=check_file)):
        if i == 0:
            assert tmpfile.endswith('subdir_xml_file.xml'), tmpfile
            assert os.path.exists(tmpfile)
        if i >= 1:
            assert False, 'got more then the expected files'

    assert not os.path.exists(tmpfile), 'tmpfile (%s) not removed' % tmpfile

