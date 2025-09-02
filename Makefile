.PHONY: setup start run kill test clean help db-up db-down db-logs db-shell

help:
	@echo "Available commands:"
	@echo "  setup    - Set up the project environment and start database"
	@echo "  run      - Run the application"
	@echo "  kill     - Kill service running on the server port"
	@echo "  test     - Run tests"
	@echo "  check    - Run checks"
	@echo "  fix      - Run fixes"
	@echo "  clean    - Clean up temporary files and stop containers"
	@echo "  db-up    - Start the PostgreSQL database"
	@echo "  db-down  - Stop the PostgreSQL database"
	@echo "  db-logs  - Show database logs"
	@echo "  db-shell - Connect to the database shell"
	@echo "  help     - Show this help message"

setup:
	@echo "Setting up the project..."
	@echo "Starting PostgreSQL database..."
	@docker-compose --profile db up -d
	@echo "Waiting for database to be ready..."
	@sleep 5
	@mix setup
	@echo "Setup complete!"

run:
	@echo "Running the application..."
	@./bin/start.sh

start: run

kill:
	@lsof -t -i tcp:$${SERVER_PORT:-8080} | xargs kill

test:
	@echo "Running tests..."
	@echo "Starting test database if not running..."
	@docker-compose --profile db up -d
	@echo "Running test script..."
	@./bin/test.sh

test-more:
	@echo "Running tests..."
	@echo "Starting test database if not running..."
	@docker-compose --profile db up -d
	@echo "Running test script..."
	@./bin/test-more.sh

check:
	@echo "Running checks..."
	@mix compile --warnings-as-errors
	@mix dialyzer --quiet-with-result
	@mix format --check-formatted
	@mix credo --min-priority low
	@mix sobelow --config .sobelow-conf --exit

fix:
	@echo "Running fixes..."
	@mix format

clean: kill
	@echo "Cleaning up..."
	@echo "Stopping and removing containers..."
	@docker-compose --profile db down -v
	@echo "Removing any temporary files..."
	@rm -rf *.log *.tmp

db-up:
	@echo "Starting PostgreSQL database..."
	@docker-compose --profile db up -d

db-down:
	@echo "Stopping PostgreSQL database..."
	@docker-compose --profile db down

db-logs:
	@echo "Showing database logs..."
	@docker-compose --profile db logs -f postgres

db-shell:
	@echo "Connecting to database shell..."
	@docker-compose --profile db exec postgres psql -U ${POSTGRES_USER:-messaging_user} -d ${POSTGRES_DB:-messaging_service}
