"""
The Markowitz WSGI application, and its database administration command-line interface -
"python3 wsgi.py check|init|reset" (see the Makefile)
"""

from functools import partial
import os
from pathlib import Path
import sys

from bare_script import barescript_parse_script, execute_script, fetch_read_only, url_file_relative
from bare_script.wsgi import wsgi_application, wsgi_load_source, wsgi_load_statics


# Read the application source - the backend, frontend, and MarkdownUp application (downloaded by
# "make run") directories
ROOT_DIR = Path(__file__).parent
APP_SRC = wsgi_load_source(ROOT_DIR, ('backend', 'frontend', 'build/markdown-up'))

# The static files, a map of URL path to source path - the backend adds a static request for each
APP_STATICS = wsgi_load_statics(ROOT_DIR, {'/': 'frontend', '/markdown-up/': 'build/markdown-up'})

# The configuration and secrets from the environment: the CouchDB database URL (default is
# "http://127.0.0.1:5984/markowitz") and credentials ("user:password")
COUCH_GLOBALS = {}
for env_name, global_name in (
    ('MARKOWITZ_COUCH_URL', 'markowitzCouchURL'),
    ('MARKOWITZ_COUCH_CREDENTIALS', 'markowitzCouchCredentials')
):
    if env_name in os.environ:
        COUCH_GLOBALS[global_name] = os.environ[env_name]

# The globals passed to the backend - the static files, and the configuration and secrets
APP_GLOBALS = {'markowitzStatics': APP_STATICS, **COUCH_GLOBALS}

# Create the WSGI application - unless running the database administration command-line interface
if __name__ != '__main__':
    application = wsgi_application(APP_SRC, 'backend/markowitz.bare', 'markowitzApplication', globals_=APP_GLOBALS)


def main():
    """
    The database administration command-line interface main entry point
    """

    script = barescript_parse_script("include 'backend/markowitzAdmin.bare'\nreturn markowitzAdmin(markowitzAdminArgs)")
    status = execute_script(script, {
        'fetchFn': fetch_read_only,
        'globals': {'markowitzAdminArgs': sys.argv[1:], **COUCH_GLOBALS},
        'logFn': print,
        'urlFn': partial(url_file_relative, __file__)
    })
    sys.exit(int(status))


if __name__ == '__main__':
    main()
