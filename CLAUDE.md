# Pegasus WMS — Developer Guide

Pegasus Workflow Management System (v5.2.0-dev). Multi-language scientific workflow system: Java planner, Python CLI/API/monitoring, C/C++ execution wrappers.

## Build System

Ant-based build with Make for C components. Default target is `dist`.

```bash
ant dist              # Build binary distribution (no docs)
ant dist-release      # Build binary distribution with documentation
ant compile           # Compile all code (Java + C + externals)
ant compile-java      # Compile Java only
ant compile-c         # Compile C tools (kickstart, cluster, keg)
ant clean             # Remove all build artifacts
```

Java source/target level: 1.8. Version defined in `build.properties`.

## Testing

```bash
ant test              # Run ALL tests (builds dist first, then python → java → c → transfer)
ant test-python       # Run Python tests via tox (all 4 packages)
ant test-java         # Run Java JUnit tests
ant test-c            # Run C unit tests (kickstart + PMC)
ant test-kickstart    # Kickstart tests only
ant test-pmc          # pegasus-mpi-cluster tests only
ant test-transfer     # Transfer utility tests
```

### Python tests individually

Each Python package under `packages/` has its own `tox.ini`. To run tests for a single package:

```bash
cd packages/pegasus-python && tox -e py310
cd packages/pegasus-api && tox -e py310
cd packages/pegasus-common && tox -e py310
cd packages/pegasus-worker && tox -e py310
```

Test framework is pytest. Reports go to `test-reports/`.

## Code Formatting

```bash
ant code-format-python   # Format all Python code
ant code-format-java     # Format all Java code (AOSP style via google-java-format)
```

- **Python**: ruff (check + format), configured in `.pre-commit-config.yaml`
- **Java**: google-java-format 1.7, AOSP style. Applies to `src/**/*.java` and `test/junit/**/*.java`
- Pre-commit hooks available in `.pre-commit-config.yaml`

## Architecture

```
Java (Planner)     — Workflow planning, mapping, site selection, code generation
Python (Tools)     — CLI tools, workflow API, monitoring, dashboard, statistics
C/C++ (Execution)  — Job wrappers (kickstart), clustering, test job generation (keg)
```

## Source Locations

### Java — `src/`

Main planner: `src/edu/isi/pegasus/planner/` with these packages:

| Package | Purpose |
|---------|---------|
| `catalog/` | Site, Replica, Transformation, Work catalogs |
| `classes/` | Core domain models |
| `client/` | Client-facing Java APIs |
| `cluster/` | Job clustering/aggregation |
| `code/` | Code generation (GridStart, submit scripts) |
| `common/` | Shared utilities, credentials, logging |
| `dax/` | DAX parsing and handling |
| `estimate/` | Resource estimation |
| `mapper/` | Output, staging, submit mapping |
| `namespace/` | Job specification namespaces |
| `parser/` | DAX and config parsing |
| `partitioner/` | Workflow partitioning |
| `refiner/` | Cleanup, directory creation refinement |
| `selector/` | Site/replica/transformation selection |
| `transfer/` | Data transfer management |

Other Java packages: `edu.isi.pegasus.common.*`, `edu.isi.pegasus.aws.batch.*`, `org.griphyn.vdl.*`

### Python — `packages/`

Four namespace packages sharing the `Pegasus` namespace:

| Package | What it provides |
|---------|-----------------|
| `pegasus-api/` | Workflow definition API (`Workflow`, `Job`, `File`, `Site`, catalogs) |
| `pegasus-common/` | Shared utilities (`braindump`, YAML/JSON handling, client utils) |
| `pegasus-python/` | CLI tools, monitoring daemon, database layer, dashboard, statistics |
| `pegasus-worker/` | Worker-side execution: data transfer (`transfer.py`, `s3.py`), worker utils |

Python source lives under `packages/<pkg>/src/Pegasus/`.

### C/C++ — `packages/`

| Package | Language | Purpose |
|---------|----------|---------|
| `pegasus-kickstart/` | C | Job execution wrapper, metadata capture, checksumming |
| `pegasus-cluster/` | C | Groups multiple jobs into clustered execution |
| `pegasus-keg/` | C++ | Synthetic job generator for testing |
| `pegasus-mpi-cluster/` | C++ | MPI-based distributed job clustering |

### Executables — `bin/`

Key CLI entry points: `pegasus-plan` (main planner), `pegasus-rc-client`, `pegasus-tc-converter`, `pegasus-sc-converter`, `pegasus-version`.

## Configuration and Catalogs

Configuration files and examples in `etc/`:

- `basic.properties` — Default Pegasus properties
- `sample.sites.xml4` — Site catalog example (XML v4)
- `sample.rc.data` — Replica catalog example
- `sample.tc.text` — Transformation catalog example
- `etc/yaml/` — YAML format examples (`sc.yml`, `rc.yml`, `tc.yml`, `workflow.yml`)

Three catalog types:
- **Site Catalog** — Defines compute resources and their configurations
- **Replica Catalog** — Tracks physical locations of data files
- **Transformation Catalog** — Maps logical transformations to physical executables

## Test Directory

```
test/
├── junit/     # Java JUnit tests
├── unit/      # Unit tests
├── core/      # Integration/core tests
├── common/    # Common test utilities
├── scripts/   # Test scripts
└── visualize/ # Visualization tests
```

## Base44 Sandbox Environment (`docker-compose.base44.yml`)

`docker compose -f docker-compose.base44.yml up -d --build` runs the Pegasus
Workflow Dashboard (`pegasus-service`, the Flask app in
`packages/pegasus-python/src/Pegasus/service/`) on <http://localhost:3000>.

- The service imports the four `Pegasus` namespace packages straight from the
  bind-mounted checkout via `PYTHONPATH`, so source edits are picked up by the
  Flask reloader; no Pegasus code is baked into the image.
- Dependencies are installed into the image from `src/requirements.txt` (the
  project's pinned Python runtime set, used by `build.xml`'s
  `compile-externals` target) plus `PyYAML`, which `packages/pegasus-python/setup.py`
  declares but that file omits. Rebuild (`--build`) when those change.
- `pegasus-service` refuses to serve the root user's data
  (`service/lifecycle.py: authorization()`), so it runs as the unprivileged
  `pegasus` user (uid 1000) created in `.base44/Dockerfile.dev`.
  `.base44/entrypoint.sh` makes the root-owned bind mount readable by that user
  and, when `BASE44_PREVIEW_MODE=1`, writes the single-user sandbox config to
  `~/.pegasus/service.py` (`NoAuthentication`, `PROCESS_SWITCHING = False`,
  `SSL_ENABLED = False`); with the flag unset the service keeps its defaults.
- The dashboard reads workflows from the master database `~/.pegasus/workflow.db`
  in the `pegasus-home` volume. The one-shot `pegasus-seed` service copies the
  master database shipped in `packages/pegasus-python/test/resources/monitoring-db/`
  (five archived hello-world workflows, `db_url` repointed at the copy) when no
  database exists, so the dashboard has data to show without running a workflow.
  `docker compose -f docker-compose.base44.yml down -v` resets it to empty.
- Running real workflows to populate the dashboard normally needs a full
  Pegasus + HTCondor installation; only the Python parts of the project run in
  this environment. No credentials or external services are needed.
- Verifying a change: `curl -sL http://localhost:3000/u/pegasus/` must return
  the workflow listing; the compose healthcheck probes that URL as `pegasus`
  (requests from uid 0 are rejected).
- `case()` calls in `service/dashboard/queries.py` and
  `db/workflow/stampede_statistics.py` must pass conditions as positional
  tuples; the SQLAlchemy list form raises `ArgumentError` on the pinned
  SQLAlchemy 2.x.
