# .NET 10 Refresher

A project to reacquaint myself with modern .NET development after several years
focused on Go. The Orders API uses ASP.NET Core, EF Core, and PostgreSQL, and
runs locally on Minikube using Helm.

Agentic coding is used only in an advisory capacity, not to generate application
code for this exercise.

> **Maturity Level**: Emerging — a learning project; expect breaking changes.
> **Version**: v0.1.8

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
curl http://localhost:3034/orders/get
```

Open Swagger UI at `http://localhost:3034/swagger/` to explore the endpoints.
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

The separate [Envoy Helm chart](deploy/envoy/Chart.yaml) deploys a standalone
Envoy reverse proxy, its ConfigMap, and a ClusterIP Service:

```text
localhost:3034 → port-forward svc/envoy → Envoy → orders Service:8080
              → Orders API → PostgreSQL
```

[Envoy's static configuration](deploy/envoy/envoy.yaml) listens on port `8080`,
forwards all paths unchanged to `orders.orders.svc.cluster.local:8080`, and
writes access logs to stdout. It is mounted from the ConfigMap at
`/etc/envoy/envoy.yaml`. This setup uses standalone Envoy, not Envoy Gateway.

The Orders chart includes a [NetworkPolicy](deploy/orders/templates/networkpolicy.yaml).
Calico enforces it: only pods labeled `app: envoy` in the same namespace may
send ordinary pod traffic to the API on TCP port `8080`. Orders can still
connect outbound to PostgreSQL.

## Key Considerations

- [Chart defaults](deploy/orders/values.yaml) pull
  `ghcr.io/twistingmercury/orders:latest` and
  `ghcr.io/twistingmercury/orders-postgres:test`, both with pull policy `Always`.
  The cluster needs registry access. Local builds require separate image
  loading and Helm image overrides before Minikube can use them.
- Both services are `ClusterIP`; Ingress and HTTPRoute are disabled. Forward
  local traffic to `svc/envoy`. Envoy's upstream assumes the Orders release
  and namespace are both named `orders`.
- NetworkPolicy requires an enforcing network plugin such as Calico. It does
  not restrict administrative `kubectl port-forward` access; use RBAC for that
  boundary. Additional policies can expand allowed traffic, and anyone who can
  create pods with the allowed label can match this policy.
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
minikube start -p order-policy --cni=calico
kubectl --context order-policy -n kube-system rollout status \
  daemonset/calico-node --timeout=180s
kubectl --context order-policy -n kube-system rollout status \
  deployment/calico-kube-controllers --timeout=180s
helm upgrade --install orders ./deploy/orders \
  --kube-context order-policy \
  --namespace orders --create-namespace \
  --set livenessProbe.httpGet.path=/openapi/v1.json \
  --set readinessProbe.httpGet.path=/openapi/v1.json \
  --wait --timeout 5m
helm upgrade --install envoy ./deploy/envoy \
  --kube-context order-policy \
  --namespace orders \
  --wait --timeout 2m
kubectl --context order-policy -n orders port-forward svc/envoy 3034:8080
```

The profile name is `order-policy` (singular). It is a separate cluster with its
own database volume; an existing `minikube` profile and its data remain unchanged.
These commands install fresh releases, so no Helm ownership flags are needed.

Port forwarding occupies the terminal until stopped with Ctrl+C. To inspect
startup or image-pull problems, run:

```sh
kubectl --context order-policy -n orders get pods,pvc,svc
kubectl --context order-policy -n orders logs deployment/orders
kubectl --context order-policy -n orders logs deployment/orders-postgres
kubectl --context order-policy -n orders logs deployment/envoy --tail=20
```

If starting a second cluster fails with `Failed to create control group inotify
object: Too many open files`, the host's inotify instance limit may be exhausted.
During this setup, raising it from 128 to 1024 resolved startup:

```sh
sudo sysctl -w fs.inotify.max_user_instances=1024
```

This host setting lasts until reboot. Retry the Minikube start command afterward.

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

After editing Envoy configuration, upgrade its chart and restart Envoy to load
the updated ConfigMap; configuration changes do not automatically restart pods:

```sh
helm upgrade envoy ./deploy/envoy \
  --kube-context order-policy --namespace orders --wait --timeout 2m
kubectl --context order-policy -n orders rollout restart deployment/envoy
kubectl --context order-policy -n orders rollout status deployment/envoy --timeout=2m
```

### Testing

Validate and render both charts without deploying:

```sh
helm lint ./deploy/orders ./deploy/envoy
helm template orders ./deploy/orders --namespace orders > /tmp/orders.yaml
helm template envoy ./deploy/envoy --namespace orders > /tmp/envoy.yaml
```

With the Envoy port forward running, verify policy enforcement:

```sh
kubectl --context order-policy -n orders run direct-check \
  --image=curlimages/curl:8.18.0 \
  --restart=Never --rm -i --command -- \
  curl -i --max-time 10 http://orders:8080/orders/get
curl -i --max-time 10 http://localhost:3034/orders/get
kubectl --context order-policy -n orders logs deployment/envoy --since=2m
```

The direct pod request should time out (curl exit code 28), while the Envoy
request should return HTTP `200` and Orders JSON, with an Envoy access log entry.
Both outcomes were verified after applying the policy. Before applying it, the
same direct request returned JSON, establishing that the destination was reachable.
Testing through a direct API port forward does not test this policy boundary.

The Docker build runs formatting checks, compilation, and unit tests; the build
script then runs HTTP tests against the built image. See the
[test guide](src/Tests/README.md) for standalone test commands and shell-script
coverage.

### Versioning

Git tags identify application releases; the latest tag is `v0.1.8`.
Inspect the current checkout with:

```sh
git describe --tags --always
```

The Orders chart currently declares version `0.1.0` and `appVersion: "1.16.0"`.
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

### Tuesday, Sep 08, 2026

- Wrote Envoy's static configuration by hand to learn listeners, routes, and
  upstream clusters, then validated it with Envoy.
- Packaged Envoy's configuration, Deployment, and Service in a separate Helm
  chart and verified requests through its access logs.
- Created the separate `order-policy` Minikube profile with Calico to enforce
  NetworkPolicies, preserving the original cluster.
- Added the Orders ingress policy and verified that direct pod requests time
  out while requests through Envoy return the expected JSON.
