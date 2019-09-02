from setuptools import setup, find_packages

setup(name='osm-alkis-tool',
      version='0.4.4',
      description='OSM/ALKIS importer/updater',
      author='Omniscale',
      author_email='info@omniscale.de',
      packages=find_packages(),
      include_package_data=True,
      package_data = {'': ['*.sql']},
      install_requires=[
        'psycopg2',
        'PyYAML',
        'click',
      ],
      entry_points = {
          'console_scripts': [
              'osm-alkis-tool = osm_alkis_tool.main:cli',
          ],
      },
)
