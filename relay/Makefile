.PHONY: build test run clean lint docker

BINARY := prompt-gladiators-relay
PORT   ?= 8080
TOKEN  ?=

build:
	go build -ldflags="-s -w" -o $(BINARY) ./cmd/server

run: build
	./$(BINARY) -port $(PORT) -token "$(TOKEN)"

test:
	go test -v -race ./...

test-cover:
	go test -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

lint:
	@which golangci-lint > /dev/null || (echo "Install: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest" && exit 1)
	golangci-lint run ./...

clean:
	rm -f $(BINARY) coverage.out coverage.html

docker:
	docker build -t prompt-gladiators-relay .

docker-run: docker
	docker run --rm -p $(PORT):8080 \
		-e AUTH_TOKEN="$(TOKEN)" \
		prompt-gladiators-relay

deps:
	go mod download
	go mod tidy

# Format all Go files
fmt:
	gofmt -w .

# Check for vulnerabilities
vuln:
	@which govulncheck > /dev/null || go install golang.org/x/vuln/cmd/govulncheck@latest
	govulncheck ./...
