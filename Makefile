# Best practices: https://tech.davis-hansson.com/p/make/

SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

.DEFAULT_GOAL := help

# Variables
PROJECT_ROOT := $(shell pwd)
HOME_DIR := $(shell echo $$HOME)
GO := go
GOLANGCI_LINT := golangci-lint
# File watcher: go install github.com/cespare/reflex@latest — or use go run (see test-reflex / run-reflex)
REFLEX := reflex
# Package path for tests/build from repo root (adjust if you add cmd/ subpackages)
PKG := ./...

##@ Running

.PHONY: run
run: ## Run main.go in the current directory
	$(GO) run src/app/main.go

.PHONY: run-watch
run-watch: run ## Auto-restart 'make run' when any .go file in src/ changes (live reload with reflex)
	$(REFLEX) -r '^src/.*\.go$$' -- $(MAKE) run

.PHONY: run-watch-server
run-watch-server: run ## Run make run and restart on each .go source change in src (server mode, reflex -s)
	$(REFLEX) -r '^src/.*\.go$$' -s -- $(MAKE) run

.PHONY: run-air
run-air: ## Hot-reload src/cli with Air (uses .air.toml; optional: go install github.com/air-verse/air@latest)
	air

##@ Testing

.PHONY: test
test: ## Run all tests (quiet unless something fails)
	$(GO) test $(PKG)

.PHONY: test-v
test-v: ## Run all tests with verbose output
	$(GO) test -v $(PKG)

.PHONY: test-watch
test-watch: test ## Re-run make test in src when any .go file in src changes
	$(REFLEX) -r '^src/.*\.go$$' -- $(MAKE) test

.PHONY: test-cover
test-cover: ## Run tests with coverage summary
	$(GO) test -cover $(PKG)

.PHONY: test-cover-html
test-cover-html: ## Run tests with coverage summary and generate HTML report
	$(GO) test -cover -coverprofile=coverage.out $(PKG)
	$(GO) tool cover -html=coverage.out

.PHONY: test-race
test-race: ## Run tests with the race detector (slower; catches data races)
	$(GO) test -race $(PKG)

.PHONY: bench
bench: ## Run benchmarks (if any)
	$(GO) test -bench=. -benchmem $(PKG)

##@ Linting & Formatting

.PHONY: fmt
fmt: ## Format all Go files with go fmt
	$(GO) fmt $(PKG)

.PHONY: vet
vet: ## Run go vet on all packages
	$(GO) vet $(PKG)

.PHONY: lint
lint: ## Run golangci-lint on all packages (uses .golangci.yml)
	$(GOLANGCI_LINT) run $(PKG)

.PHONY: lint-config
lint-config: ## Verify .golangci.yml against the JSON schema
	$(GOLANGCI_LINT) config verify -c .golangci.yml

.PHONY: lint-fix
lint-fix: ## Run golangci-lint with --fix (auto-fix where supported)
	$(GOLANGCI_LINT) run --fix $(PKG)

.PHONY: fix
fix: ## Fix field alignment issues
	fieldalignment -test -fix $(PKG)

.PHONY: fix
errcheck: ## Fix errcheck issues
	errcheck $(PKG)

.PHONY: check
check: fmt vet errcheck lint test ## Format, vet, errcheck, lint, then test (good before a commit)

##@ Modules & Building

.PHONY: tidy
tidy: ## Add missing modules and remove unused ones
	$(GO) mod tidy

.PHONY: download
download: ## Download modules to the module cache
	$(GO) mod download

.PHONY: build
build: ## Build all packages under the module
	$(GO) build $(PKG)

.PHONY: clean
clean: ## Remove build artifacts (e.g. ./learn-go-with-tests binary if built here)
	$(GO) clean -cache -testcache 2>/dev/null || true
	@rm -f learn-go-with-tests main 2>/dev/null || true

##@ Setup & Info

.PHONY: setup
setup: download tidy ## Verify toolchain and sync modules
	@echo "Checking Go environment..."
	@$(GO) version
	@echo "Installing required Go tools..."
	@$(GO) install golang.org/x/tools/go/analysis/passes/fieldalignment/cmd/fieldalignment@latest
	@$(GO) install github.com/kisielk/errcheck@latest
	@$(GO) install golang.org/x/pkgsite/cmd/pkgsite@latest
	@$(GO) install github.com/air-verse/air@latest
	@$(GO) install github.com/cespare/reflex@latest
	@command -v golangci-lint >/dev/null 2>&1 || { \
		echo >&2 "WARNING: golangci-lint not found in PATH. Please install golangci-lint manually (https://golangci-lint.run/docs/welcome/install/local)."; \
		exit 1; \
	}
	@echo "✓ Ready"

.PHONY: pkgsite
pkgsite: ## Open the package documentation in the browser
	@pkgsite -open .

.PHONY: info
info: ## Show Go env and project paths useful when learning
	@echo "Project root: $(PROJECT_ROOT)"
	@echo "GO (pinned): $(GO)"
	@echo "Module: $$($(GO) list -m)"
	@echo ""
	@$(GO) version
	@echo ""
	@echo "GOOS=$$($(GO) env GOOS)  GOARCH=$$($(GO) env GOARCH)"
	@echo "GOROOT=$$($(GO) env GOROOT)"
	@echo "GOPATH=$$($(GO) env GOPATH)"
	@echo "GOTOOLCHAIN=$$($(GO) env GOTOOLCHAIN)"

.PHONY: help
help: ## Show this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make <target>\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  %-18s %s\n", $$1, $$2 } /^##@/ { printf "\n%s\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
