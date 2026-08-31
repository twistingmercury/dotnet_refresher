# Day 2 --- ASP.NET Core, Containers, and Minikube

## Objective

Build a current ASP.NET Core service and understand the complete path
from source to a running Kubernetes pod.

**Rule from today onward:** If it does not run in Minikube, it is not
finished.

## Progress

- [ ] ASP.NET Core: bootstrap, middleware, controllers/minimal APIs,
    validation, exception handling
- [ ] DI: singleton/scoped/transient; configuration and options
- [ ] `HttpClientFactory`, hosted services, graceful shutdown
- [ ] OTel: ASP.NET Core + HttpClient instrumentation, OTLP, custom
    `ActivitySource` and `Meter`
- [ ] Multi-stage container build; SDK vs runtime; non-root execution
- [ ] Deploy Namespace, Deployment, Service, ConfigMap to Minikube
- [ ] Implement liveness/readiness
- [ ] Practice `kubectl` diagnostics
- [ ] Complete recap

## Lab

Create `Orders.Api` with `POST /orders` and `GET /orders/{id}`.
Propagate request cancellation into application code. Containerize it
and deploy it to Minikube.

Practice:

``` bash
dotnet test
dotnet publish -c Release
docker build -t orders-api:dev .
kubectl apply -f deploy/
kubectl get pods
kubectl get svc
kubectl describe pod <pod>
kubectl logs -f <pod>
kubectl exec -it <pod> -- /bin/sh
kubectl get events
```

## Observability

Separate automatic/framework instrumentation from business
instrumentation. Avoid redundant spans. Export through OTLP and attach
appropriate service resource attributes.

## Health contracts

Implement `/health/live` and `/health/ready`.

**Liveness:** Would restarting this process potentially restore it?

**Readiness:** Should Kubernetes currently route work to this instance?

Do not automatically include every external dependency in both.

## Verification

- [ ] Pod starts and Service routes traffic
- [ ] Readiness controls routing
- [ ] Liveness behaves correctly
- [ ] SIGTERM causes graceful shutdown
- [ ] Telemetry exports via OTLP
- [ ] Logs are structured

## Recap

- [ ] Explain DI lifetimes.
- [ ] What problem does `HttpClientFactory` address?
- [ ] How does request cancellation propagate?
- [ ] Why multi-stage builds?
- [ ] Framework-dependent vs self-contained?
- [ ] Liveness vs readiness?
- [ ] Why can dependency-heavy readiness checks be harmful?
- [ ] What happens on SIGTERM?
- [ ] What telemetry should ASP.NET Core produce automatically?

## \## Notes / questions for recap

-
-
