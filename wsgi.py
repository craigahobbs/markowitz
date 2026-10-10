"""
The Markowitz WSGI application
"""

from pathlib import Path

from bare_script.wsgi import wsgi_application, wsgi_load_source, wsgi_load_statics


# Read the application source - the backend, frontend, and MarkdownUp application (downloaded by
# "make run") directories
ROOT_DIR = Path(__file__).parent
APP_SRC = wsgi_load_source(ROOT_DIR, ('backend', 'frontend', 'build/markdown-up'))

# The static files, a map of URL path to source path - the backend adds a static request for each
APP_STATICS = wsgi_load_statics(ROOT_DIR, {'/': 'frontend', '/markdown-up/': 'build/markdown-up'})

# Create the WSGI application
application = wsgi_application(
    APP_SRC, 'backend/markowitz.bare', 'markowitzApplication',
    globals_={'markowitzStatics': APP_STATICS}
)
