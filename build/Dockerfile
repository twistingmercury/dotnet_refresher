FROM ghcr.io/twistingmercury/dotnet-aot-sdk:10.0.0-alpine AS build

WORKDIR /src
COPY src/Orders/ ./Orders/
WORKDIR /src/Orders

RUN dotnet restore --locked-mode
RUN dotnet format --verify-no-changes --no-restore
RUN dotnet build --no-restore --configuration Release -warnaserror
RUN dotnet test --no-build --configuration Release
Run dotnet package list --no-restore --vulnerable --include-transitive
Run dotnet publish -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/runtime-deps:10.0-alpine AS runtime
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["./Orders"]