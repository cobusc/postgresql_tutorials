from setuptools import setup, find_packages

setup(
    name='demo',
    version='0.0.1',
    author='cobusc',
    author_email="cobus.carstens@gmail.com",
    packages=find_packages(),
    install_requires=[
        "momoko",
        "psycopg2",
        "tornado"#
    ],
    # If any package contains *.json files, include them
    package_data={'': ['*.json']},
    scripts=[
        'demo/application.py',
    ]
)
