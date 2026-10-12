# Download python-build
PYTHON_BUILD_DIR ?= ../python-build
define WGET
ifeq '$$(wildcard $(notdir $(1)))' ''
$$(info Downloading $(notdir $(1)))
$$(shell [ -f $(PYTHON_BUILD_DIR)/$(notdir $(1)) ] && cp $(PYTHON_BUILD_DIR)/$(notdir $(1)) . || $(call WGET_CMD, $(1)))
endif
endef
WGET_CMD = if command -v wget >/dev/null 2>&1; then wget -q -c $(1); else curl -f -Os $(1); fi
$(eval $(call WGET, https://craigahobbs.github.io/python-build/Makefile.tool))


# Include python-build
include Makefile.tool


# Development dependencies
TESTS_REQUIRE := bare-script waitress


# The application
APP := markowitz

# The application server host and port
HOST ?= 127.0.0.1
PORT ?= 8080

# The MarkdownUp application tarball
MARKDOWN_UP_URL := https://craigahobbs.github.io/markdown-up/markdown-up.tar.gz


help:
	@echo "            [init|lint-backend|lint-frontend|reset|run|test-backend|test-frontend]"


clean:
	rm -rf Makefile.tool __pycache__/


# Generate the application from its specification, if it doesn't exist. Claude Code runs interactively with
# file edits pre-approved - exit the session when it finishes
backend/$(APP).bare: | $(DEFAULT_VENV_BUILD)
	@test -z "$$CLAUDECODE" || { echo "$@ does not exist - create it first (it is not generated inside Claude Code)"; exit 1; }
	@echo
	@echo "========================================================================"
	@echo "  Generating $@ from SPEC.md with Claude Code..."
	@echo "========================================================================"
	@echo
	claude --model opus --effort high --permission-mode acceptEdits @SPEC.md
	test -f $@


# The frontend and the shared API types are generated with the backend
frontend/$(APP).bare frontend/$(APP)Types.bare: backend/$(APP).bare
	test -f $@


# Run the backend and frontend unit tests - separate suites, so "make -j" runs them in parallel
test: test-backend test-frontend


# Run the backend or frontend unit tests (TEST="testName" runs one test); -d surfaces builtin debug logs,
# and -m provides the MarkdownUp runtime function stubs (the frontend and the unittest.bare report use them)
.PHONY: test-backend
test-backend: $(DEFAULT_VENV_BUILD) backend/$(APP).bare frontend/$(APP)Types.bare
	$(DEFAULT_VENV_BIN)/bare -d -m test/backend/runTests.bare$(if $(TEST), -v vUnittestTest "'$(TEST)'")


.PHONY: test-frontend
test-frontend: $(DEFAULT_VENV_BUILD) frontend/$(APP).bare frontend/$(APP)Types.bare
	$(DEFAULT_VENV_BIN)/bare -d -m test/frontend/runTests.bare$(if $(TEST), -v vUnittestTest "'$(TEST)'")


# Lint the backend and frontend - separate targets, so "make -j" runs them in parallel
lint: lint-backend lint-frontend


# Lint every script standalone. -x lints and executes (scripts + test files);
# -s lints the test runner without executing it (that's the test target).
.PHONY: lint-backend
lint-backend: $(DEFAULT_VENV_BUILD) backend/$(APP).bare frontend/$(APP)Types.bare
	$(DEFAULT_VENV_BIN)/bare -x backend/$(APP).bare backend/$(APP)Admin.bare test/backend/test*.bare
	$(DEFAULT_VENV_BIN)/bare -s -m test/backend/runTests.bare


.PHONY: lint-frontend
lint-frontend: $(DEFAULT_VENV_BUILD) frontend/$(APP).bare frontend/$(APP)Types.bare
	$(DEFAULT_VENV_BIN)/bare -x -m frontend/$(APP).bare test/frontend/test*.bare
	$(DEFAULT_VENV_BIN)/bare -s -m test/frontend/runTests.bare


# Run the application with waitress - fail if CouchDB isn't running or the database doesn't exist (see "make init")
.PHONY: run
run: $(DEFAULT_VENV_BUILD) build/markdown-up/VERSION.txt backend/$(APP).bare frontend/$(APP).bare frontend/$(APP)Types.bare
	$(DEFAULT_VENV_PYTHON) wsgi.py check
	$(DEFAULT_VENV_BIN)/waitress-serve --host=$(HOST) --port=$(PORT) wsgi:application


# Initialize the database - add the CouchDB admin (MARKOWITZ_COUCH_CREDENTIALS), create the database, create the stock
# groups, and download their stocks' prices. Running it again updates the groups and the prices.
.PHONY: init
init: $(DEFAULT_VENV_BUILD) backend/$(APP).bare frontend/$(APP)Types.bare
	$(DEFAULT_VENV_PYTHON) wsgi.py init


# Delete and re-create the database, with the built-in stock groups - "make init" downloads their stocks' prices
.PHONY: reset
reset: $(DEFAULT_VENV_BUILD) backend/$(APP).bare frontend/$(APP)Types.bare
	$(DEFAULT_VENV_PYTHON) wsgi.py reset


# Download the MarkdownUp application from the CDN tarball into build/markdown-up/, once. The extraction is
# embedded Python, so it works on Windows.
build/markdown-up/VERSION.txt: $(DEFAULT_VENV_BUILD)
	rm -rf build/markdown-up/
	$(DEFAULT_VENV_PYTHON) -c "$$MARKDOWN_UP_PY"
	touch $@


define MARKDOWN_UP_PY
import io
import tarfile
import urllib.request

# The data filter (Python 3.12, and security releases of 3.8 through 3.11) rejects unsafe archive members
with urllib.request.urlopen('$(MARKDOWN_UP_URL)') as response:
    with tarfile.open(fileobj=io.BytesIO(response.read()), mode='r:gz') as tar:
        if hasattr(tarfile, 'data_filter'):
            tar.extractall('build', filter='data')
        else:
            tar.extractall('build')
endef
export MARKDOWN_UP_PY
