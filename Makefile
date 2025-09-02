.PHONY: setup start run kill test clean help db-up db-down db-logs db-shell

help:
	@echo "Available commands:"
	@echo "  setup    - Set up the project environment and start database"
	@echo "  run      - Run the application"
	@echo "  kill     - Kill service running on the server port"
	@echo "  test     - Run tests"
	@echo "  clean    - Clean up temporary files and stop containers"
	@echo "  db-up    - Start the PostgreSQL database"
	@echo "  db-down  - Stop the PostgreSQL database"
	@echo "  db-logs  - Show database logs"
	@echo "  db-shell - Connect to the database shell"
	@echo "  help     - Show this help message"

setup:
	@echo "Setting up the project..."
	@echo "Starting PostgreSQL database..."
	@docker-compose --profile services up -d
	@echo "Waiting for database to be ready..."
	@sleep 5
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
	@docker-compose --profile services up -d
	@echo "Running test script..."
	@./bin/test.sh

clean:
	@echo "Cleaning up..."
	@echo "Stopping and removing containers..."
	@docker-compose down -v
	@echo "Removing any temporary files..."
	@rm -rf *.log *.tmp

db-up:
	@echo "Starting PostgreSQL database..."
	@docker-compose --profile services up -d

db-down:
	@echo "Stopping PostgreSQL database..."
	@docker-compose --profile services down

db-logs:
	@echo "Showing database logs..."
	@docker-compose --profile services logs -f postgres

db-shell:
	@echo "Connecting to database shell..."
	@docker-compose exec postgres psql -U messaging_user -d messaging_service
