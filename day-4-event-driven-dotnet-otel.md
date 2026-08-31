# Day 4 --- Event-Driven .NET and Distributed Tracing

## Objective

Translate distributed-systems knowledge into current .NET idioms,
emphasizing message lifecycle, correctness, graceful shutdown, and
OpenTelemetry across asynchronous boundaries.

## Progress

- [ ] Implement `BackgroundService`
- [ ] Deploy message broker
- [ ] Implement outbox publisher
- [ ] Implement consumer worker
- [ ] Review retries, acknowledgements, DLQ, poison messages,
    ordering, backpressure
- [ ] Implement idempotency/deduplication strategy
- [ ] Propagate OTel trace context
- [ ] Add messaging/business metrics
- [ ] Run failure/scaling drills
- [ ] Complete recap

## Architecture

``` text
POST /orders
  → Orders.Api
  → orders + outbox
  → OutboxPublisher
  → Broker
  → Orders.Worker
```

For each behavior identify its owner: application, client library,
broker, or Kubernetes.

## Graceful shutdown

Test the full path:

``` text
SIGTERM → .NET host stopping → CancellationToken → BackgroundService
        → stop accepting work → resolve in-flight work
        → ack/nack deliberately → close broker resources
```

## Distributed tracing

Review `Activity`, `ActivitySource`, `ActivityContext`, W3C Trace
Context, `traceparent`, baggage, span links, producer/consumer spans,
and messaging semantic conventions.

Think deliberately about parent/child spans versus links. Do not force
synchronous call-tree semantics onto asynchronous architecture.

## Metrics

Implement useful signals such as: - `orders.created`, `orders.failed`,
`orders.processing.duration` - `outbox.pending`,
`outbox.publish.duration`, `outbox.publish.failures` -
`consumer.processing.duration`, `consumer.retry.count`,
`consumer.deadletter.count`

For every metric attribute ask whether the value set is bounded. IDs
usually belong on traces, not metric dimensions.

## Failure/scaling drills

- [ ] Delete a worker pod mid-processing
- [ ] Scale workers to zero and build backlog
- [ ] Scale workers to three replicas and observe recovery/concurrency
- [ ] Restart broker
- [ ] Introduce poison message
- [ ] Force transient consumer failures

Determine what was lost, duplicated, retried, or dead-lettered; what
happened to in-flight work; whether cancellation propagated; and whether
telemetry tells the complete story.

## Recap

- [ ] How does `BackgroundService` participate in shutdown?
- [ ] What must an at-least-once consumer assume?
- [ ] How do you implement idempotency?
- [ ] Why outbox? Why might inbox/dedup still be needed?
- [ ] Parent/child span vs span link?
- [ ] How should trace context cross a broker?
- [ ] How do you detect backlog operationally?
- [ ] Which metric dimensions cause cardinality problems?
- [ ] What happens when Kubernetes terminates a consumer mid-message?

## \## Notes / questions for recap

-
-
