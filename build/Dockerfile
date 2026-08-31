FROM mcr.microsoft.com/dotnet/sdk:10.0.400-alpine3.24-aot AS build

WORKDIR /src
COPY src/Orders/ ./Orders/
WORKDIR /src/Orders

RUN dotnet restore --runtime linux-musl-x64 -p:PublishAot=true
RUN dotnet format --verify-no-changes --no-restore
RUN dotnet build --runtime linux-musl-x64 --no-restore --configuration Release -warnaserror
RUN dotnet test --runtime linux-musl-x64 --no-build --configuration Release
RUN dotnet package list --no-restore --vulnerable --include-transitive
RUN dotnet publish \
    --runtime linux-musl-x64 \
    --self-contained true \
    -p:PublishAot=true \
    --no-restore \
    --configuration Release \
    --output /app/publish

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
