# Tests

This directory contains all test projects and test-related resources.

## Unit

This directory contains unit tests for the Orders.csproj. It utilizes [XUnit](https://xunit.net/?tabs=cs), as I remember this being my personaly preferred testing tool.

> Not because XUnit is "better" than NUnit. It's not. I just like it more than for no other reason than "because".  

## BlackBox

These xUnit tests exercise the public HTTP API as an independent client. The test
project has no application project references, EF dependencies, database access,
or in-process application host. Requests and assertions use the public JSON and
OpenAPI contracts.

From the repository root, build and run the isolated test environment:

```sh
make test-blackbox
```

This target calls [`build/test-black-box.sh`](../../build/test-black-box.sh),
which builds the images, runs the tests, and removes the test containers and
volumes afterward, including when tests fail. It starts the API and database in
the background and runs the test client separately to completion, preserving
its exit status. An API crash cannot stop the client early and produce a false
success. You can also run the script directly:

```sh
./build/test-black-box.sh
```

Cleanup also removes the automatically named database and test-client images
with `docker compose down --rmi local`. Standalone runs remove
`orders-api:blackbox`; runs using `ORDERS_API_IMAGE` preserve the supplied API
image for publication or reuse. Docker build cache is retained.

`build/build.sh` (also used by `make build`) builds the application once, resolves
its commit-specific tag to a local image ID, and passes that ID to the runner through
`ORDERS_API_IMAGE`. The runner builds only the database and test-client images,
then starts Compose with `--no-build --pull never`. It tests the application image
that was just built. A failing black-box run fails the build script.

CI uses this same flow with `LOCAL=0`. Pull requests build and test without
registry login or publication; successful pushes and manual runs on `develop`
can publish the tested tags. The build reports its actual tags to CI only after
tests pass, so publication uses the same names rather than deriving them again.

Each CI build creates `sha-<full HEAD commit SHA>` and `latest` tags. It also
creates a release tag when `HEAD` is exactly on a Git tag. An untagged commit
after `v0.1.5` therefore updates its own SHA tag and `latest`, leaving `v0.1.5`
alone. `LOCAL=1` adds `-local` to every tag. `BUILD_VER` and `BUILD_COMMIT` can
override image metadata but do not override the commit/release tag selection.
These source identifiers assume CI's clean checkout; local working-tree edits
are not represented by the HEAD commit SHA.

The runner's exit-code and cleanup behavior has isolated BATS coverage that does
not start Docker containers:

```sh
bats build/tests
shellcheck build/build.sh build/test-black-box.sh build/tests/*.bats
```

To run Compose directly and keep the stopped containers for inspection:

```sh
docker compose -p orders-blackbox -f src/Tests/BlackBox/docker-compose.tests.yaml build
docker compose -p orders-blackbox -f src/Tests/BlackBox/docker-compose.tests.yaml up -d --no-build --pull never orders_test_pg_db orders_test_api
docker compose -p orders-blackbox -f src/Tests/BlackBox/docker-compose.tests.yaml run --rm --no-deps --pull never -T orders_api_tests
```

Compose starts a disposable PostgreSQL database, the application image, and the
test client container. The application image build runs the unit tests first.
The HTTP fixture waits up to 60 seconds for the orders endpoint to become ready;
an unavailable API fails the run. The command returns the test container's exit
code so test failures can stop a CI job.

After the run, remove the test environment:

```sh
docker compose -p orders-blackbox -f src/Tests/BlackBox/docker-compose.tests.yaml down --volumes --remove-orphans
```

The database uses temporary container storage, with no host ports or shared
development database volume. Tests create unique orders and do not depend on
seeded IDs or the total number of orders. Delete is not covered yet; created
data is discarded with the test database.

To test an already built application image directly:

```sh
ORDERS_API_IMAGE=ghcr.io/twistingmercury/orders:latest ./build/test-black-box.sh
```

The tag, digest, or image ID must already exist locally. The runner resolves it
to an image ID and fails if it is unavailable; it never pulls or rebuilds the API
in this mode. Without `ORDERS_API_IMAGE`, `make test-blackbox` and the runner build
all three images for a standalone test run.

To run the test client locally against an existing disposable API:

```sh
ORDERS_API_BASE_URL=http://localhost:3033 dotnet test src/Tests/BlackBox/Orders.Tests.BlackBox.csproj
```

`ORDERS_API_BASE_URL` defaults to `http://localhost:3033`; Compose sets it to the
API service's internal address. Use a disposable instance because these tests
create orders.
