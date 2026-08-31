# Day 3 --- EF Core, Testing, and Container Runtime Behavior

## Objective

Refresh persistence/testing while connecting .NET runtime behavior to
Kubernetes CPU/memory constraints and telemetry.

## Progress

- [ ] EF Core: `DbContext`, LINQ, async queries, tracking, migrations,
    transactions, concurrency
- [ ] Inspect generated SQL and connection behavior
- [ ] Implement `orders` + transactional `outbox`
- [ ] xUnit and integration testing with `WebApplicationFactory`
- [ ] Deploy PostgreSQL in Minikube
- [ ] Review StatefulSet, Service, PVC, ConfigMap, Secret, DNS
- [ ] Add CPU/memory requests and limits
- [ ] Observe GC, allocations, CPU, memory, ThreadPool, HTTP and DB
    telemetry
- [ ] Run failure drills
- [ ] Complete recap

## Persistence lab

Creating an order must atomically:

``` text
BEGIN
  INSERT order
  INSERT outbox message
COMMIT
```

For every EF query ask: **What SQL am I causing EF Core to execute?**

Verify rollback, duplicate requests, optimistic concurrency conflicts,
and cancellation during DB operations.

## Testing

Favor integration tests at infrastructure boundaries. Cover API →
application, application → PostgreSQL, transactional outbox behavior,
health checks, and cancellation where practical.

## Resource behavior

Apply meaningful resource requests/limits. Connect CPU throttling to
runtime/ThreadPool behavior and latency. Connect memory limits to GC
behavior, allocation pressure, latency, and OOMKill.

## Failure drills

- [ ] PostgreSQL unavailable
- [ ] Slow PostgreSQL
- [ ] Connection exhaustion
- [ ] CPU throttling
- [ ] Memory pressure
- [ ] Invalid configuration
- [ ] Missing secret
- [ ] Pod restart
- [ ] Failed readiness
- [ ] Rolling deployment

**Diagnostic rule:** Look at telemetry before source code.

For each incident record: symptom, metrics, traces, logs, Kubernetes
evidence, root cause, recovery, and design improvement.

## Recap

- [ ] Appropriate `DbContext` lifetime?
- [ ] Tracking vs `AsNoTracking`?
- [ ] What does a transactional outbox guarantee---and not guarantee?
- [ ] What is optimistic concurrency?
- [ ] How can CPU limits manifest as latency?
- [ ] How does container memory pressure interact with .NET?
- [ ] What telemetry distinguishes DB latency from GC pressure?
- [ ] Why are requests/limits operational design concerns?

## \## Notes / questions for recap

-
-
