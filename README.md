# .NET - C# 10 Refresher

This project is simply a project to refamilarize myself with modern .NET development. I've spent a good number or years focusing on Go software development and need to reaquaint myself with .NET.

Agenting coding will only be used in an advisory capacity, not in generating code for this exercise.

---

> Maturity: Emerging  
> Version: 0.1.4

---

## Monday, Aug 31, 2026

Spent the day working on a docker-first build...like I would in Go. What I accomplished:

- Focused on stubbing out a conventional ASP.NET Core web API with EF Core.
- A [Dockerfile](build/Dockerfile) that builds, tests, runs analysis (Kind of...not like Go tooling), and pushed the images to GHCR.
- A [build script](build/build.sh) that performs the build. It's used to both build locally and in the [CI build](.github/workflows/ci.yaml).
- A simple [Makefile](./Makefile)
- The start of [docker compose file](./docker-compose.yaml).

## Thursday, Set 03, 2026

Spent the day fleshing out the data access and finishing up the endpoints.

- Learned that I can't compile as Native-AOT using EFCore. Fortunately, that was just a change to the [Dockerfile](./build/Dockerfile). To compile as Native-AOT you have to fallback to ADO.NET.
- Setup DI container for the [OrderDbContext](./src/Orders/DataAccess/OrderDbContext.cs) and for the [OrderHandler](src/Orders/Handlers/OrderHandlers.cs). No over absraction with a repository pattern; size of project just doesn't merit following that pattern.
- Used a plain old class for [Program.cs](src/Orders/Program.cs). This was for stylistic reasons based on this project, not because of personal dogma.
- Start up involves:

```text
1: Create builder 
        ⬇️  
2: Get configuration  
        ⬇️  
3: Setup DI container  
        ⬇️  
4: build the configured WebApplication  
        ⬇️  
5: Set up mappings  
        ⬇️  
6: Run the app
```
