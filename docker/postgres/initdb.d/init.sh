#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create user if it doesn't exist (only if not the default postgres user)
    DO \$\$
    BEGIN
        IF '$POSTGRES_USER' != 'postgres' AND NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$POSTGRES_USER') THEN
            CREATE USER "$POSTGRES_USER" WITH PASSWORD '$POSTGRES_PASSWORD';
        END IF;
    END
    \$\$;

    -- Create database if it doesn't exist
    SELECT 'CREATE DATABASE "$POSTGRES_DB"' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$POSTGRES_DB')\gexec

    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE "$POSTGRES_DB" TO "$POSTGRES_USER";
    ALTER DATABASE "$POSTGRES_DB" OWNER TO "$POSTGRES_USER";
EOSQL
