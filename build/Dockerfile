FROM mcr.microsoft.com/dotnet/sdk:10.0.400-alpine3.24 AS build

WORKDIR /src
COPY src/Orders/ ./Orders/
COPY src/Tests/Unit/ ./Tests/Unit/
WORKDIR /src/Orders

RUN dotnet restore
RUN dotnet restore /src/Tests/Unit/Orders.Tests.Unit.csproj
RUN dotnet format --verify-no-changes --no-restore
RUN dotnet format /src/Tests/Unit/Orders.Tests.Unit.csproj --verify-no-changes --no-restore
RUN dotnet build --no-restore --configuration Release -warnaserror
RUN dotnet build /src/Tests/Unit/Orders.Tests.Unit.csproj --no-restore --configuration Release -warnaserror
RUN dotnet test /src/Tests/Unit/Orders.Tests.Unit.csproj --no-build --no-restore --configuration Release
RUN dotnet package list --no-restore --vulnerable --include-transitive
RUN dotnet package list --project /src/Tests/Unit/Orders.Tests.Unit.csproj --no-restore --vulnerable --include-transitive
RUN dotnet publish \
    --no-restore \
    --configuration Release \
    --output /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS final

ARG VERSION=dev
ARG DATE=unknown
ARG COMMIT=unknown

LABEL org.opencontainers.image.title="Orders" \
    org.opencontainers.image.description="This project is simply a project to refamilarize myself with modern .NET development." \
    org.opencontainers.image.source="https://github.com/twistingmercury/dotnet-refresher" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.authors="Jeremy K. Johnson" \
    org.opencontainers.image.created="${DATE}" \
    org.opencontainers.image.revision="${COMMIT}" \
    org.opencontainers.image.version="${VERSION}"

EXPOSE 8080

WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Orders.dll"]
