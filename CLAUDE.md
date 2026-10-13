# CLAUDE.md

Notes for coding agents working in this repository.

## Project overview

Markowitz is a [BareScript](https://craigahobbs.github.io/bare-script/language/) web application: a schema-validated JSON
API backend, served by Python ([WSGI](https://peps.python.org/pep-3333/)), and a
[MarkdownUp](https://craigahobbs.github.io/markdown-up/) frontend that calls it - a Markowitz portfolio analyzer.

- `SPEC.md` - the application specification
- `backend/markowitz.bare` - the backend: the API's action functions, and the `markowitzApplication` WSGI
  application function, which rejects a cross-origin request (`HTTP_ORIGIN`) and calls the API application,
  `markowitzAPIApplication`, created by `wsgiCreateAPIApplication` from the `wsgi.bare` include library. Its API
  documentation is at `/doc/`. It includes the backend's modules:
  - `backend/markowitzAnalysis.bare` - the Markowitz portfolio analysis (`markowitzAnalyzeStocks` and
    `markowitzPortfolio`), a port of the original program
  - `backend/markowitzCouch.bare` - the CouchDB database URL, headers, and request helpers (`markowitzDB*`)
  - `backend/markowitzYahoo.bare` - the Yahoo Finance stock price download (`markowitzYahooDownload`)
- `frontend/markowitz.bare` - the frontend MarkdownUp application, whose main function `markowitzMain()` is
  called from `frontend/markowitz.md`. It includes the application's pages:
  - `frontend/markowitzCommon.bare` - the URL arguments and the common page helpers (header, `markowitzFetch`,
    tables, and formatting)
  - `frontend/markowitzRuns.bare` - the runs and run pages, and a running run's progress
  - `frontend/markowitzNewRun.bare` - the new run page
  - `frontend/markowitzStocks.bare` - the stocks and stock pages, and stock updates
  - `frontend/markowitzGroups.bare` - the groups and group pages

  Each page file includes the files it calls, so it lints standalone - the common helpers, and the run page
  (`markowitzNewRun.bare`) or stock updates (`markowitzGroups.bare`). Keep the calls one-way so the includes don't
  form a cycle - the runs and stocks files never call the new run and groups files.
- `frontend/markowitzTypes.bare` - the API's Schema Markdown types, `markowitzTypes`, shared by the backend and
  frontend
- `frontend/markowitzUtil.bare` - the month, stock symbol, and run stock selection (`markowitzRunSelect`) helpers,
  shared by the backend and frontend
- Persistence is CouchDB - one database (default `http://127.0.0.1:5984/markowitz`) of `stock`, `group` (stock groups,
  e.g. "S&P 100"), and `run` documents. `wsgi.py` reads the `MARKOWITZ_COUCH_URL` and `MARKOWITZ_COUCH_CREDENTIALS`
  ("user:password") environment variables. Stock prices are downloaded from Yahoo Finance's chart API by the
  `updateStocks` action - the frontend updates a group's stocks, or every stock, a chunk of symbols at a time.
- `admin/markowitzAdmin.bare` - the database administration commands (`markowitzAdmin(args)`): `check`, `init`, and
  `reset`. It includes the backend, but isn't part of the web application - `wsgi.py` doesn't load `admin/`.
  `python3 wsgi.py check|init|reset` runs them with the same environment variables; the Makefile's `run`, `init`,
  and `reset` targets call it. Both save the built-in stock groups, `admin/markowitzGroups.json` (Yahoo Finance
  symbols, e.g. "BRK-B" - edit it to update an index's members).
- `original/` - the 1967 Fortran program scans that the backend's analysis (`backend/markowitzAnalysis.bare`) ports
- `wsgi.py` - the WSGI application, which `make run` serves with waitress (named `wsgi`, not `markowitz`, so it
  can't collide with a Python module of the same name). It reads the application
  source once, at startup - restart the server after editing - and passes the backend the `markowitzStatics`
  global, a map of URL path to project-relative source path for each static file: the `frontend/` files (at
  `/<file>`, and `/` for `frontend/index.html`) and the MarkdownUp application
  (downloaded to `build/markdown-up/` by `make run`, at `/markdown-up/<file>`). Configuration and secrets (e.g.
  database credentials) come from environment variables - read them in `wsgi.py` and add them to its `globals_`
- `test/` - the unit tests, `test/backend/` and `test/frontend/` - a test file for each source file, and the
  shared `testMarkowitzHelpers.bare` fixtures - with a
  `runTests.bare` runner and an `index.html` to run them in a browser. The pages load MarkdownUp from
  `build/markdown-up/` (downloaded by `make run`, or `make build/markdown-up/VERSION.txt`), so serve the project
  root with a static file server (e.g. `python3 -m http.server`) and open `/test/backend/` or `/test/frontend/`.

The backend's includes, and `systemFetch` calls made while it loads, resolve relative to `backend/` - e.g.
`'../frontend/index.html'`. Only the directories `wsgi.py` loads (`backend/`, `frontend/`, and
`build/markdown-up/`) can be read. Read files when the backend loads, as `wsgiStaticRequests` does - a
`systemFetch` call made while a request is handled resolves relative to the main script, which is the test runner in
the tests.

The Makefile includes [python-build](https://github.com/craigahobbs/python-build#readme)'s `Makefile.tool`,
downloaded on first use, which builds a Python virtual environment with bare-script and waitress.

## Sharing code between the backend and frontend

Code shared by the backend and frontend lives in `frontend/` - it is served, so the browser can include it - and
the backend includes it from there (`include '../frontend/<file>.bare'`). Never the reverse: `backend/` is never
served, so backend-only code (and anything private) stays there, and frontend code must not include it. The API's
types are shared this way - the backend serves the API from `markowitzTypes` and the frontend validates requests
with it (e.g. `schemaValidate(markowitzTypes, 'myAction_input', request)`).

Shared code is tested in the frontend suite. The backend suite includes it too, so its coverage counts there - if
the backend exercises a shared file only partly, add the file to `test/backend/runTests.bare`'s
`coverageExclude` (e.g. `'frontend/markowitzUtil.bare'`).

## Authoring BareScript code

Before writing, modifying, or reviewing BareScript code, read the bare-script skill,
`.claude/skills/bare-script/SKILL.md`. It is the reference for the language, the built-in and include
libraries (see its "WSGI applications (Python)" section), the MarkdownUp application pattern, and the
unit-test and mocking pattern.

## Commands

- `make commit` - run the unit tests and lint; the gate before committing
- `make test` - run the unit tests - `make test-backend` and `make test-frontend` run one suite (`TEST=<name>`
  runs one test)
- `make lint` - lint every script standalone - `make lint-backend` and `make lint-frontend` lint one side
- `make run` - serve the application at <http://127.0.0.1:8080/> with waitress (for the user, not for a coding
  agent - it starts a server that never returns). It fails first if CouchDB isn't running or the database doesn't
  exist.
- `make init` - add the CouchDB admin (if CouchDB has none), create the database, create the stock groups, and download
  their stocks' prices - re-running it updates them
- `make reset` - delete and re-create the database, with the built-in stock groups - destructive; `make init`
  downloads the stocks' prices
- `make clean` - remove the build directory and the downloaded python-build `Makefile.tool`

`make commit`, `make test`, and `make lint` depend on `backend/markowitz.bare`, `frontend/markowitz.bare`, and `frontend/markowitzTypes.bare`, which the Makefile
otherwise generates with Claude Code - create them before running them.

## Conventions

- The unit tests must pass with 100% coverage - `make test` fails otherwise.
- Action functions take the validated request object - `function myAction(request)`; the WSGI environ is an
  optional second argument. Omit arguments a function doesn't use - the linter warns on them.
- Action output is schema-validated, so a response that doesn't match the action's types is a
  `500 InvalidOutput` error.
- Backend tests call `markowitzApplication(environ)` directly with environ objects (`REQUEST_METHOD`,
  `PATH_INFO`, `QUERY_STRING`, and `wsgi.input`, the request body string) and compare the response objects.
- Frontend tests mock `systemFetch`. Each page state has a render test, each named handler has a test, and each
  control's callback binding is tested.
- Escape user-provided text with `markdownEscape` before printing it as Markdown.
