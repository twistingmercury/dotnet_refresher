# check=skip=SecretsUsedInArgOrEnv
FROM postgres:18.6-alpine3.24

# Default credentials are for disposable test databases only.
ENV POSTGRES_DB=postgres \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgresTestPass \
    DB_NAME=orders \
    DB_USER=ordersUser \
    DB_PASS=ordersPass

# The official entrypoint runs migrations when initializing an empty data directory.
COPY --chmod=0755 docker-migrate.sh /docker-entrypoint-initdb.d/010-docker-migrate.sh
COPY sql/ /docker-entrypoint-initdb.d/sql/

EXPOSE 5432

HEALTHCHECK --interval=2s --timeout=3s --start-period=10s --retries=15 \
    CMD pg_isready -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" || exit 1
