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
- A [Dockerfile](build/Dockerfile) that builds, tests, runs analysis (Kind of...not like Go tooling), and pushed the images to GHCR.
- A [build script](build/build.sh) that performs the build. It's used to both build locally and in the [CI build](.github/workflows/ci.yaml).
- A simple [Makefile](./Makefile)
- The start of [docker compose file](./docker-compose.yaml).
