# .NET 10 Refresher

A project to reacquaint myself with modern .NET development after several years
focused on Go. The Orders API uses ASP.NET Core, EF Core, and PostgreSQL, and
runs locally on Minikube using Helm.

Agentic coding is used only in an advisory capacity, not to generate application
code for this exercise.

> **Maturity Level**: Emerging — a learning project; expect breaking changes.
> **Version**: v0.1.6

## Table of Contents

- [Usage](#usage)
- [How it works](#how-it-works)
- [Key Considerations](#key-considerations)
- [Development Considerations](#development-considerations)
- [Versioning](#versioning)
- [Learning journal](#learning-journal)

## Usage

Deploy with the [Quick Start](#quick-start), then keep port forwarding running
and use a separate terminal to query the API:

```sh
curl http://localhost:3033/orders/get
```

Open Swagger UI at `http://localhost:3033/swagger/` to explore the endpoints.
The OpenAPI document is served at `/openapi/v1.json`.

## How it works

[Endpoints](src/Orders/Endpoints/OrderEndpoints.cs) delegate requests to
[handlers](src/Orders/Handlers/OrderHandlers.cs), which use
[OrderDbContext](src/Orders/DataAccess/OrderDbContext.cs) to access PostgreSQL.

The [Helm chart](deploy/orders/Chart.yaml) deploys the API and PostgreSQL with
internal services and a 1Gi persistent volume claim for database storage.
The API connects to the chart's PostgreSQL service using an environment-based
connection string. The [database image](database/Dockerfile) runs its bundled
SQL initialization scripts and seeds orders when initializing an empty volume.

## Key Considerations

- [Chart defaults](deploy/orders/values.yaml) pull
  `ghcr.io/twistingmercury/orders:latest` and
  `ghcr.io/twistingmercury/orders-postgres:test`, both with pull policy `Always`.
  The cluster needs registry access. Local builds require separate image
  loading and Helm image overrides before Minikube can use them.
- The API service is `ClusterIP`; ingress is disabled. Use port forwarding for
  local access.
- Database credentials are fixed development values: `ordersUser` / `ordersPass`
  for the application and `postgres` / `postgresTestPass` for administration.
  This configuration is intended for local development.
- SQL initialization runs only on an empty database volume. Updating the image
  does not rerun initialization against existing data. Helm uninstall removes
  the chart's PVC, so treat the database as disposable.
- Default health probes target `/`, which the current source does not expose.
  Quick Start overrides both probes to `/openapi/v1.json`.

## Development Considerations

### Quick Start

Install Minikube with a supported driver, Helm, and kubectl. Run these commands
from the repository root; Minikube's default storage provisioner must be enabled
for the database PVC:

```sh
minikube start
helm upgrade --install orders ./deploy/orders \
  --kube-context minikube \
  --namespace orders --create-namespace \
  --set livenessProbe.httpGet.path=/openapi/v1.json \
  --set readinessProbe.httpGet.path=/openapi/v1.json \
  --wait --timeout 5m
kubectl --context minikube -n orders port-forward svc/orders 3033:8080
```

Port forwarding occupies the terminal until stopped with Ctrl+C. To inspect
startup or image-pull problems, run:

```sh
kubectl --context minikube -n orders get pods,pvc,svc
kubectl --context minikube -n orders logs deployment/orders
kubectl --context minikube -n orders logs deployment/orders-postgres
```

### Building & running

The deployment above uses published images. With Docker and its Compose plugin
available, build and test the application image locally using:

```sh
make build
```

This runs the [build script](build/build.sh), including the Docker build and
HTTP tests, and creates image tags with a `-local` suffix. It does not deploy
those images to Minikube. See the [Makefile](Makefile) for other local targets
and the [CI workflow](.github/workflows/ci.yaml) for image publication.

### Testing

Validate the chart without deploying:

```sh
helm lint ./deploy/orders
helm template orders ./deploy/orders --namespace orders > /tmp/orders.yaml
```

The Docker build runs formatting checks, compilation, and unit tests; the build
script then runs HTTP tests against the built image. See the
[test guide](src/Tests/README.md) for standalone test commands and shell-script
coverage.

### Versioning

Git tags identify application releases; the latest tag is `v0.1.6`.
Inspect the current checkout with:

```sh
git describe --tags --always
```

The chart currently declares version `0.1.0` and `appVersion: "1.16.0"`.
Its explicit image tags in `values.yaml` determine the deployed images.

## Learning journal

### Monday, Aug 31, 2026

Spent the day working on a Docker-first build, like I would in Go.
What I accomplished:

- Focused on stubbing out a conventional ASP.NET Core web API with EF Core.
- A [Dockerfile](build/Dockerfile) that builds, tests, and runs analysis
  (not quite like Go tooling), with images published to GHCR.
- A [build script](build/build.sh) used locally and by the
  [CI build](.github/workflows/ci.yaml).
- A simple [Makefile](Makefile).
- The start of a [Docker Compose file](docker-compose.yaml).

### Tuesday, Sep 01, 2026

Didn't work on this today.

### Wednesday, Sep 02, 2026

Didn't work on this today. Worked on a super secret, supremely cool, yet absurdly
ambitious (for me) project.

### Thursday, Sep 03, 2026

Spent the day fleshing out the data access and finishing up the endpoints.

- Switched away from Native AOT while using EF Core. That required a change to
  the [Dockerfile](build/Dockerfile).
- Set up the DI container for
  [OrderDbContext](src/Orders/DataAccess/OrderDbContext.cs) and
  [OrderHandler](src/Orders/Handlers/OrderHandlers.cs). The project's size did
  not merit an additional repository abstraction.
- Used a plain class for [Program.cs](src/Orders/Program.cs), a stylistic choice
  for this project.
- Startup creates the builder, reads configuration, registers services, builds
  the WebApplication, maps endpoints, and runs the app.
