# Day 5 --- Production Operability and Interview Simulation

## Objective

Stop adding features. Operate, break, diagnose, and recover the system,
then switch to interview recall under pressure.

## Progress

- [ ] Database outage drill
- [ ] Broker outage drill
- [ ] Worker termination drill
- [ ] Memory-pressure drill
- [ ] CPU-starvation drill
- [ ] C# coding drills
- [ ] Debugging drills
- [ ] Architecture simulation
- [ ] Final delta-note review

## Incident drills

### Database outage

Kill PostgreSQL. Determine what fails, what remains functional, what
happens to readiness, what telemetry says, whether retries help or
amplify failure, and how recovery works.

### Broker outage

With the outbox in place, determine whether Orders.Api can continue
accepting orders while backlog grows. Discuss whether broker failure
should make the API unready; treat this as an architecture decision, not
an automatic yes.

### Worker crash

Terminate a worker during message processing. Observe SIGTERM,
cancellation, acknowledgement/redelivery, duplicates, trace continuity,
and recovery.

### Memory pressure

Correlate container memory, allocation rate, GC, latency, OOMKill, and
pod restart.

### CPU starvation

Observe throttling, ThreadPool/runtime behavior, throughput, p50/p95/p99
latency, and backlog growth.

## Incident template

``` text
User-visible symptom:
Metrics:
Traces:
Logs:
Kubernetes evidence:
Root cause:
Recovery:
Design improvement:
```

## Coding drills

Without AI assistance, implement 2--3 focused problems covering
LINQ/collections, async operations, `Channel<T>`, cancellation, records,
pattern matching, and a small generic abstraction.

## Debugging drills

Diagnose forgotten `await`, `.Result` blocking, incorrect DI lifetime,
captured scoped service, EF tracking mistakes, missing cancellation,
improper `HttpClient` creation, excessive allocation, and
nullable-reference problems. Explain both the fix and likely operational
symptoms.

## Architecture simulation

Be prepared to whiteboard:

``` text
API Gateway → ASP.NET API → Database
                    │
                    └→ Outbox → Broker → Consumers → storage

All components → OpenTelemetry/OTLP → OTel Collector → observability platform
```

Discuss consistency, failure domains, retries, idempotency, schema
evolution, scaling, partitioning, backpressure, observability, SLOs,
graceful degradation, Kubernetes lifecycle, security boundaries, and
deployment strategy.

## Final rapid-fire recap

- [ ] DI lifetimes
- [ ] Async I/O without saying "new thread"
- [ ] Request/host cancellation
- [ ] `BackgroundService` shutdown
- [ ] EF tracking and `DbContext` lifetime
- [ ] Transactional outbox and idempotent consumers
- [ ] Liveness vs readiness
- [ ] .NET under container resource limits
- [ ] Traces vs metrics vs logs and correlation
- [ ] Automatic vs manual OTel instrumentation
- [ ] Trace propagation across messaging
- [ ] Metric cardinality
- [ ] Diagnose a slow service from telemetry
- [ ] Explain why downstream failure does not automatically imply
    failed readiness

## Success criterion

Comfortably move through:

``` text
C# → ASP.NET Core → EF Core → container → Minikube
   → distributed messaging → OpenTelemetry → failure diagnosis
```

The target is not memorization. It is to remove the gap between knowing
the architecture and expressing/operating it fluently in modern .NET.

## \## Notes / questions for recap

-
-
