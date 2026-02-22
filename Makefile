.PHONY: help build clean install test test-integration test-integration-local test-clean test-list release

help:
	@echo "ShipNode Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  make build                    - Build distributable installer"
	@echo "  make clean                    - Remove dist directory"
	@echo "  make install                  - Install locally from source"
	@echo "  make test                     - Test the installer"
	@echo "  make test-integration         - Run integration tests with Docker"
	@echo "  make test-integration-local   - Run local tests only (no container)"
	@echo "  make test-clean               - Clean up leftover test containers"
	@echo "  make test-list                - List available integration test phases"
	@echo "  make release                  - Create and publish a new release"

build:
	@./build-dist.sh

clean:
	@echo "Cleaning dist directory..."
	@rm -rf dist/
	@echo "✓ Clean complete"

install:
	@echo "Installing ShipNode locally..."
	@./install.sh

test: build
	@echo "Testing installer..."
	@bash dist/shipnode-installer.sh

test-integration: build
	@echo "Running integration tests with Docker..."
	@./scripts/test-docker.sh --phases 1,2,3,4,5,6,7,8 2>&1

test-integration-local: build
	@echo "Running local integration tests (no container required)..."
	@./scripts/test-docker.sh --local

test-clean:
	@echo "Cleaning up test containers..."
	@docker ps -a --format '{{.Names}}' | grep "^shipnode-test-" | xargs -r docker rm -f 2>/dev/null || true
	@echo "✓ Test environments cleaned up"

test-list:
	@./scripts/test-docker.sh --list

release:
	@echo "Creating release..."
	@# Extract version from lib/core.sh
	@VERSION=$$(grep -m1 '^VERSION=' lib/core.sh | cut -d'"' -f2); \
	if [ -z "$$VERSION" ]; then \
		echo "Error: Could not extract VERSION from lib/core.sh"; \
		exit 1; \
	fi; \
	echo "Version: $$VERSION"; \
	\
	echo "Syncing version to build-dist.sh..."; \
	sed -i "s/^VERSION=.*/VERSION=\"$$VERSION\"/" build-dist.sh; \
	sed -i "s/^VERSION=.*/VERSION=\"$$VERSION\"/" build-dist.sh; \
	\
	echo "Building distribution..."; \
	./build-dist.sh; \
	\
	echo "Creating git tag v$$VERSION..."; \
	git tag -a "v$$VERSION" -m "Release v$$VERSION" || (echo "Tag already exists or git error"; exit 1); \
	\
	echo "Pushing tag to origin..."; \
	git push origin "v$$VERSION"; \
	\
	echo "Creating GitHub release..."; \
	gh release create "v$$VERSION" \
		dist/shipnode-installer.sh \
		--title "ShipNode v$$VERSION" \
		--notes "Release v$$VERSION" \
		--verify-tag; \
	\
	echo "✓ Release v$$VERSION created successfully!"
