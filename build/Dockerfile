FROM ghcr.io/twistingmercury/dotnet-aot-sdk:10.0.0-alpine AS build

WORKDIR /src
COPY src/Orders/ ./Orders/
WORKDIR /src/Orders

RUN dotnet restore --locked-mode
RUN dotnet format --verify-no-changes --no-restore
RUN dotnet build --no-restore --configuration Release -warnaserror
RUN dotnet test --no-build --configuration Release
RUN dotnet package list --no-restore --vulnerable --include-transitive
RUN dotnet publish -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/runtime-deps:10.0-alpine AS final

ARG BUILD_VER=dev
ARG BUILD_DATE=unknown
ARG BUILD_COMMIT=unknown

LABEL org.opencontainers.image.title="Orders" \
    org.opencontainers.image.description="This project is simply a project to refamilarize myself with modern .NET development." \
    org.opencontainers.image.source="https://github.com/twistingmercury/dotnet-refresher" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.authors="Jeremy K. Johnson" \
    org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.revision="${BUILD_COMMIT}" \
    org.opencontainers.image.version="${BUILD_VER}"

EXPOSE 8080

WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["./Orders"]