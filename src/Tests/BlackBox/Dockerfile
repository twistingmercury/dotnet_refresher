FROM mcr.microsoft.com/dotnet/sdk:10.0.400-alpine3.24 AS build

WORKDIR /tests
COPY src/Tests/BlackBox/Orders.Tests.BlackBox.csproj ./
RUN dotnet restore Orders.Tests.BlackBox.csproj

COPY src/Tests/BlackBox/ ./
RUN dotnet format Orders.Tests.BlackBox.csproj --verify-no-changes --no-restore
RUN dotnet build Orders.Tests.BlackBox.csproj --no-restore --configuration Release -warnaserror

ENTRYPOINT ["dotnet", "test", "Orders.Tests.BlackBox.csproj", "--no-build", "--no-restore", "--configuration", "Release"]
