# Markowitz

Markowitz portfolio analyzer

## Specification

Port the attached fortran program to a full stack BareScript application. Create a tool to download and update stock
data and store it in the database. The frontend application should allow you to start a run and manage runs.

The original fortran code scan is shown along with an email from its author in the "original" directory.

## Implementation

Implement the application described above:

- First, read the bare-script skill, `.claude/skills/bare-script/SKILL.md` - including its "WSGI applications
  (Python)" section - and `CLAUDE.md`.
- Define the API's Schema Markdown types in `frontend/markowitzTypes.bare` - `markowitzTypes = schemaParse(...)`,
  after `include <schemaParser.bare>`. It is shared code: the backend includes it to serve the API, and the
  frontend includes it to validate its requests before calling the API (e.g.
  `schemaValidate(markowitzTypes, 'myAction_input', request)`). Code shared by the backend and frontend goes in
  `frontend/`, which is served - backend code is never served, so the frontend must not include it.
- Implement the backend in `backend/markowitz.bare`: an action function for each of the shared types' actions,
  and the `markowitzApplication` WSGI application function. Keep this structure - its comments mark what to
  fill in, and `wsgiStaticRequests` serves the static files that `wsgi.py` passes in the
  `markowitzStatics` global:

  ~~~ bare-script
  include <wsgi.bare>

  # The API types - shared with the frontend
  include '../frontend/markowitzTypes.bare'

  # The action functions - one for each action, named for the action

  # The request objects - the actions (e.g. {'type': 'action', 'name': 'myAction', 'path': '/myAction'}), then
  # a static request for each static file. The host passes the "markowitzStatics" global, a map of URL path to
  # source path (relative to the project root).
  markowitzRequests = [ \
      # The action request objects
  ]
  arrayExtend(markowitzRequests, wsgiStaticRequests(systemGlobalGet('markowitzStatics', {}), '../'))

  # The WSGI application function
  markowitzApplication = wsgiCreateAPIApplication(markowitzTypes, {'doc': true, 'requests': markowitzRequests})
  ~~~

- If the backend needs configuration or secrets - e.g. a database URL and credentials (see the bare-script
  skill's "Persistence" section) - read them from environment variables in `wsgi.py` (e.g.
  `MARKOWITZ_COUCH_URL`) and pass them to the backend as globals alongside `markowitzStatics`. Never
  hard-code credentials.
- Implement the frontend in `frontend/markowitz.bare` with the main function `markowitzMain()`, which
  `frontend/markowitz.md` calls. It calls the backend's actions with `systemFetch` - a request object with a
  JSON `'body'` is a POST, e.g. `systemFetch({'url': 'myAction', 'body': jsonStringify(request)})` - and
  relative URLs resolve against the server root. Escape user-provided text with `markdownEscape` before printing
  it as Markdown.
- Write the backend unit tests in `test/backend/testMarkowitz.bare` - each action's success and error
  responses, by calling `markowitzApplication(environ)` directly - and the frontend unit tests in
  `test/frontend/testMarkowitz.bare` using the skill's unittest.bare and unittestMock.bare patterns, with
  `systemFetch` mocked - a render test per page state, a test for each named handler, and a callback-binding
  test for each control. Both suites need 100% coverage.
- Run `make commit` and fix every test failure and lint warning until it passes.
- Do not run `make run` - it starts a web server that never returns. The user runs it after this session ends.
