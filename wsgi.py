"""
The Markowitz WSGI application
"""

import os
from pathlib import Path

from bare_script.wsgi import wsgi_application, wsgi_load_source, wsgi_load_statics


# Read the application source - the backend, frontend, and MarkdownUp application (downloaded by
# "make run") directories
ROOT_DIR = Path(__file__).parent
APP_SRC = wsgi_load_source(ROOT_DIR, ('backend', 'frontend', 'build/markdown-up'))

# The static files, a map of URL path to source path - the backend adds a static request for each
APP_STATICS = wsgi_load_statics(ROOT_DIR, {'/': 'frontend', '/markdown-up/': 'build/markdown-up'})

# The globals passed to the backend - the static files, and the configuration and secrets from the environment:
# the CouchDB database URL (default is "http://127.0.0.1:5984/markowitz") and credentials ("user:password")
APP_GLOBALS = {'markowitzStatics': APP_STATICS}
for env_name, global_name in (
    ('MARKOWITZ_COUCH_URL', 'markowitzCouchURL'),
    ('MARKOWITZ_COUCH_CREDENTIALS', 'markowitzCouchCredentials')
):
    if env_name in os.environ:
        APP_GLOBALS[global_name] = os.environ[env_name]

# Create the WSGI application
application = wsgi_application(APP_SRC, 'backend/markowitz.bare', 'markowitzApplication', globals_=APP_GLOBALS)
