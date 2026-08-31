# Day 1 --- Modern C# and .NET

## Objective

Rebuild C# muscle memory and identify the important differences between
older C#/.NET and current .NET development.

## Progress

- [ ] Modern C#: nullable references, records, `required`/`init`,
    primary constructors, pattern matching, switch expressions,
    collection expressions, file-scoped namespaces, global usings,
    tuples, generics, LINQ, extension methods
- [ ] Async: `Task`, `ValueTask`, `IAsyncEnumerable<T>`,
    `CancellationToken`, `IAsyncDisposable`, `Channel<T>`, thread pool
    vs async I/O
- [ ] CLI: `dotnet new`, restore, build, test, run, publish, package
    management
- [ ] Observability: `ILogger<T>`, `ActivitySource`/`Activity`,
    `Meter`
- [ ] Complete lab
- [ ] Update `notes/dotnet-deltas.md`
- [ ] Complete recap

## Go → C# context switch

  Go                  C#
  ------------------- -----------------------------
  Error values        Exceptions
  Goroutines          Tasks / async operations
  Channels            `Channel<T>`
  `context.Context`   `CancellationToken`
  `defer`             `using` / `await using`
  Slices/maps         Collections + LINQ
  `nil`               Nullable-reference analysis

## Lab

Build a CLI worker that receives work through `Channel<T>`, processes
multiple items asynchronously, supports end-to-end cancellation, handles
exceptions deliberately, emits structured logs, creates application
spans, emits metrics, and shuts down cleanly.

Do not introduce Kubernetes yet.

## Key questions

- [ ] Why does `await` not imply a new thread?
- [ ] When is `ValueTask` appropriate?
- [ ] How does `CancellationToken` compare with Go's
    `context.Context`?
- [ ] Record vs class?
- [ ] What problem do nullable reference types solve?
- [ ] What is `Channel<T>` useful for?
- [ ] How do `Activity` and OpenTelemetry relate?
- [ ] Why prefer structured log templates?
- [ ] What makes a metric label dangerous?

## \## Notes / questions for recap

-
-
