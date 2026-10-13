# Markowitz

Markowitz is a portfolio analyzer: for a group of stocks (e.g. the S&P 100), it computes the minimum-risk portfolio
for each of a set of target annual returns, the method of [Harry Markowitz](https://grokipedia.com/page/Harry_Markowitz).

Its analysis is a port of Program HOBBS, a Fortran 2.1 program written in 1967 to test the Markowitz method on a
brand-new IBM mainframe at OSU - which could handle at most 52 stocks. See
[the original program](original/#readme), and an email from its author describing it.

Markowitz is a full-stack [BareScript](https://craigahobbs.github.io/bare-script/language/) application: a schema-validated
JSON API backend, served by Python, and a [MarkdownUp](https://craigahobbs.github.io/markdown-up/) frontend that calls
it. Stock prices are downloaded from Yahoo Finance and stored in [CouchDB](https://couchdb.apache.org/).


## The analysis

A run analyzes a stock group's monthly prices over an analysis period (e.g. the 97 months ending 2026-09):

1. Each stock's monthly percent returns are fit to a trend line. A stock's projected return is the trend's return at
   the end of the projection (default, 3 months after the analysis period), and its risk is the variance of its
   monthly returns about the trend. The stocks' covariance is computed from the same residuals.
2. For each target annual return, the minimum-variance portfolio - the allocations that minimize the portfolio's
   variance, with the target return and allocations that sum to one - is the solution of a linear system, solved by
   Gauss-Jordan elimination.
3. A portfolio can't hold a negative allocation, so the stock with the most negative allocation is deleted and the
   system is solved again, until every allocation is non-negative (or there is no solution).

If the projection's months have passed, each stock's and portfolio's realized return is shown with its projection.

A run can't have more stocks than months in its analysis period - the covariance matrix would be singular. Stocks
without a price for every month of the analysis period are excluded from the run, so a longer analysis period
excludes more stocks with short price histories. Each group has a minimum analysis period, the fewest months with no
more stocks than months, which the new run form computes and uses.


## Requirements

- Python 3 - `make` builds a virtual environment with [bare-script](https://pypi.org/project/bare-script/) and
  [waitress](https://pypi.org/project/waitress/)
- [CouchDB](https://couchdb.apache.org/) 3, running locally (e.g. `brew install couchdb`)


## Setup

The application reads its configuration from environment variables:

| Variable | Description |
| --- | --- |
| `MARKOWITZ_COUCH_CREDENTIALS` | The CouchDB admin's credentials, `user:password` (required) |
| `MARKOWITZ_COUCH_URL` | The CouchDB database URL (default is `http://127.0.0.1:5984/markowitz`) |

CouchDB 3 doesn't start without an admin - add one to the `[admins]` section of its `local.ini` file (for Homebrew,
in `$(brew --prefix couchdb)/etc/local.d/`), and start CouchDB (e.g. `brew services start couchdb`). Then initialize
the database:

~~~sh
export MARKOWITZ_COUCH_CREDENTIALS='admin:password'
make init
~~~

`make init` adds the admin (if CouchDB has none), creates the database, saves the built-in stock groups, and downloads
their stocks' prices - about 500 stocks, in a minute or two. Running it again updates the groups and the prices.

The built-in stock groups are in [admin/markowitzGroups.json](admin/markowitzGroups.json) - edit it to update an
index's members (Yahoo Finance symbols, e.g. "BRK-B"):

| Group | Stocks |
| --- | --: |
| Dow 30 | 30 |
| Magnificent 7 | 7 |
| Nasdaq-100 | 101 |
| S&P 100 | 101 |
| S&P 500 | 503 |

The S&P 500's minimum analysis period is long - 332 months, from 1999 - so its run has 332 stocks, and takes about two
seconds per target return's portfolio. A run shows its progress, a portfolio at a time.


## Running

~~~sh
make run
~~~

Open <http://127.0.0.1:8080/>. `make run` fails, before starting the server, if CouchDB isn't running or the database
doesn't exist. The application's pages:

- **Runs** - the runs, most recent first
- **New Run** - select a stock group, and the analysis period (the months default to the group's minimum), projection
  months, and target returns. The excluded stocks - the group's stocks without a price for every month of the
  analysis period - are updated when the group, end month, or months change, and can be edited.
- **Run** - the portfolios, the efficient frontier chart, the allocations, the stocks' statistics, and the excluded
  stocks and why they were excluded
- **Stocks** - download and update stocks' prices: stock symbols, a group's stocks, or every stock, showing the
  update's progress
- **Groups** - create, edit, and delete stock groups, and update a group's stocks

The API documentation is at <http://127.0.0.1:8080/doc/>.


## Development

| Command | Description |
| --- | --- |
| `make commit` | Run the unit tests and lint - the gate before committing |
| `make test` | Run the unit tests (`make test-backend` or `make test-frontend` runs one suite, `TEST=<name>` one test) |
| `make lint` | Lint every script (`make lint-backend` or `make lint-frontend` lints one side) |
| `make run` | Serve the application at <http://127.0.0.1:8080/> (`HOST` and `PORT` override) |
| `make init` | Initialize the database - see [Setup](#setup) |
| `make reset` | Delete and re-create the database, with the built-in stock groups - **destructive** (`make init` downloads the prices) |
| `make clean` | Remove the build directory and the downloaded python-build `Makefile.tool` |

The unit tests must pass with 100% coverage. They run with `systemFetch` mocked - no CouchDB or network access.

The project layout:

| Path | Description |
| --- | --- |
| `backend/markowitz.bare` | The backend - the API's action functions and the WSGI application |
| `backend/markowitzAnalysis.bare` | The Markowitz portfolio analysis - a port of the original program |
| `backend/markowitzCouch.bare` | The CouchDB database helpers |
| `backend/markowitzYahoo.bare` | The Yahoo Finance stock price download |
| `admin/markowitzAdmin.bare` | The database administration commands - `python3 wsgi.py check\|init\|reset` |
| `admin/markowitzGroups.json` | The built-in stock groups |
| `frontend/markowitz.bare` | The MarkdownUp frontend application |
| `frontend/markowitzCommon.bare` | The frontend's common page helpers |
| `frontend/markowitzGroups.bare` | The groups and group pages |
| `frontend/markowitzNewRun.bare` | The new run page |
| `frontend/markowitzRuns.bare` | The runs and run pages, and a running run's progress |
| `frontend/markowitzStocks.bare` | The stocks and stock pages, and stock updates |
| `frontend/markowitzTypes.bare` | The API's [Schema Markdown](https://craigahobbs.github.io/schema-markdown-js/language/) types, shared by the backend and frontend |
| `frontend/markowitzUtil.bare` | The month, symbol, and run stock selection helpers, shared by the backend and frontend |
| `wsgi.py` | The WSGI application, and the database administration command-line interface |
| `test/` | The backend and frontend unit tests |
| `original/` | The 1967 Fortran program |

See [CLAUDE.md](CLAUDE.md) for more on the project's structure and conventions.


## License

[MIT](LICENSE)
