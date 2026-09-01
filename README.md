# .NET - C# 10 Refresher

This project is simply a project to refamilarize myself with modern .NET development. I've spent a good number or years focusing on Go software development and need to reaquaint myself with .NET.

Agenting coding will only be used in an advisory capacity, not in generating code for this exercise.

---

> Maturity: Emerging  
> Version: 0.0.1

---

## Monday, Aug 31, 2026

Spent the day working on a docker-first build...like I would in Go. What I accomplished:

- Focused on stubbing out a web api that compiled using Native AOT.
- A [Dockerfile](build/Dockerfile) that builds, tests, runs analysis (Kind of,,,not like Go tooling), and pushed the images to GHCR.
- A [build script](build/build.sh) that performs the build. It's used to both build locally and in the [CI build](.github/workflows/ci.yaml).
- A simple [Makefile](./Makefile)
- The start of [docker compose file](./docker-compose.yaml).

### Thoughts

#### Things I (think) I like about C# 14

- __Minimal APIs:__ these are very similar in concept to using a `ServerMux` and registering it with one or more `HandlerFunc`. Or if you're like me and use Gin & Gonic, like registering a handlerfunc with a router.
- __Channels :__ essentially the same thing in Go, used to pass data between asynchronous, or concurrent, threads(.NET) and goroutines(Go). Although, they aren't quite as simple to use.

#### Things I don't like about C# 14

No real complains, just trivial niggles.

- __Statically linked executables:__ Unlike a binary build with Go that doesn't require CGO, you can't use scratch as your final image; Native-AOT binaries aren't fully statically linked.
- __Project files use XML:__ I don't like that in mid to late 2026 .NET project files are _still_ using xml. YAML would be much better, IMHO.
- __JSON is the default config format:__ I don't like that configurations are still using JSON. YAML is again preferred. However, there are providers for YAML. They're just not default. But for containers, env vars are highly preferred over either anyway, so its a wash.
- __Using ORMs (EFCore):__ this is controversial, but I don't like ORMs. I've had more trouble in the past with EFCore creating some nasty queries that have driven DBA's up the wall. But, if that is how it's "done" (it's idiomatic), then so be it. This can be mitigated by ensuring the schema is well thought out (A whole topic on its own). So...may be a wash give the right conditions?
