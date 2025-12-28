# Shell setup
SHELL := /bin/bash

# -- Path & Tool Detection --
HOME_BUN_BIN := $(HOME)/.bun/bin/bun

# Try to find tools
SYSTEM_GO := $(shell which go)
SYSTEM_BUN := $(shell which bun)
SYSTEM_TEMPL := $(shell which templ)
SYSTEM_AIR := $(shell which air)
SYSTEM_WATCHMAN := $(shell which watchman)

# executable commands
GO_CMD := $(if $(SYSTEM_GO),$(SYSTEM_GO),go)
BUN_CMD := $(if $(SYSTEM_BUN),$(SYSTEM_BUN),$(HOME_BUN_BIN))
TEMPL_CMD := $(if $(SYSTEM_TEMPL),$(SYSTEM_TEMPL),templ)
AIR_CMD := $(if $(SYSTEM_AIR),$(SYSTEM_AIR),air)

# Shell Config for reporting
SHELL_CONFIG := $(shell if [ -f "$$HOME/.zshrc" ]; then echo ".zshrc"; elif [ -f "$$HOME/.bash_profile" ]; then echo ".bash_profile"; elif [ -f "$$HOME/.bashrc" ]; then echo ".bashrc"; else echo ".profile"; fi)

# Project info
PROJECT_NAME := $(shell basename $(CURDIR))
MAIN_GO := cmd/$(PROJECT_NAME)/main.go
STATIC_DIR := static
BUILD_DIR := tmp

# Tailwind settings
CSS_INPUT := $(STATIC_DIR)/css/input.css
CSS_OUTPUT := $(STATIC_DIR)/css/styles.css

# Colors
CYAN := \033[36m
RESET := \033[0m
CHECK := ✓
ARROW := →

# URLs
ALPINE_URL := https://cdn.jsdelivr.net/npm/alpinejs@latest/dist/cdn.min.js

.PHONY: dev build generate css clean help check-deps create-air-config init setup-go check-tailwind fix-air-config

# -- Main Development --

dev: check-deps check-tailwind fix-air-config
	@# Check for go.mod, create if missing
	@[ -f go.mod ] || make setup-go
	@printf "\n$(CYAN)Starting Dev Server...$(RESET)\n"
	@# Run Tailwind CLI (v4 compatible)
	@$(BUN_CMD) x @tailwindcss/cli -i $(CSS_INPUT) -o $(CSS_OUTPUT) --watch & \
	$(AIR_CMD)

# -- Build --

build: generate css
	@printf "\n$(CYAN)Building Binary...$(RESET)\n"
	@$(GO_CMD) build -o $(BUILD_DIR)/main $(MAIN_GO)
	@printf "$(CHECK) Build complete\n"

# -- Generators --

generate:
	@$(TEMPL_CMD) generate

css: check-tailwind
	@$(BUN_CMD) x @tailwindcss/cli -i $(CSS_INPUT) -o $(CSS_OUTPUT) --minify

# -- Setup & Helpers --

check-deps:
	@printf "\n$(CYAN)Checking dependencies$(RESET)\n"
	
	@# 1. Check Go
	@test -n "$(SYSTEM_GO)" || (echo "Go not found" && exit 1)
	
	@# 2. Check Bun
	@if [ -z "$(SYSTEM_BUN)" ] && [ ! -f "$(HOME_BUN_BIN)" ]; then \
		read -p "Bun not found. Install it? (y/N): " ans; \
		if [ "$${ans:-N}" = "y" ]; then \
			printf "Installing Bun...\n"; \
			curl -fsSL https://bun.sh/install | bash; \
			printf "Detected Shell Config: ~/%s\n" $(SHELL_CONFIG); \
			printf "NOTE: Enabled Bun for this run. Run 'source ~/%s' later.\n" $(SHELL_CONFIG); \
		else \
			echo "Bun is required."; exit 1; \
		fi \
	fi

	@# 3. Check Templ
	@if [ -z "$(SYSTEM_TEMPL)" ]; then \
		read -p "Templ not found. Install it? (y/N): " ans; \
		if [ "$${ans:-N}" = "y" ]; then \
			printf "Installing Templ...\n"; \
			$(GO_CMD) install github.com/a-h/templ/cmd/templ@latest; \
		else \
			echo "Templ is required."; exit 1; \
		fi \
	fi

	@# 4. Check Air
	@if [ -z "$(SYSTEM_AIR)" ]; then \
		read -p "Air not found. Install it? (y/N): " ans; \
		if [ "$${ans:-N}" = "y" ]; then \
			printf "Installing Air...\n"; \
			$(GO_CMD) install github.com/air-verse/air@latest; \
		else \
			echo "Air is required for dev mode."; exit 1; \
		fi \
	fi

	@# 5. Check Watchman (Added as requested)
	@if [ -z "$(SYSTEM_WATCHMAN)" ]; then \
		read -p "Watchman not found (required for Tailwind). Install it? (y/N): " ans; \
		if [ "$${ans:-N}" = "y" ]; then \
			printf "Installing Watchman...\n"; \
			if command -v pacman >/dev/null; then \
				sudo pacman -S watchman; \
			elif command -v apt-get >/dev/null; then \
				sudo apt-get update && sudo apt-get install -y watchman; \
			else \
				echo "Could not detect package manager (pacman/apt). Please install 'watchman' manually."; \
				exit 1; \
			fi \
		else \
			echo "Watchman is required."; exit 1; \
		fi \
	fi
	@printf "$(CHECK) System dependencies ready\n"

# Check/Install Tailwind (v4 support)
check-tailwind:
	@if [ ! -d "node_modules/@tailwindcss/cli" ]; then \
		printf "Tailwind CLI (v4) not found. Installing via Bun...\n"; \
		$(BUN_CMD) add -d tailwindcss @tailwindcss/cli; \
		printf "$(CHECK) Tailwind installed\n"; \
	fi

# Ensure .air.toml has the correct serve command
fix-air-config:
	@if [ ! -f .air.toml ] || ! grep -q "full_bin" .air.toml; then \
		make create-air-config; \
	fi

setup-go:
	@printf "\n$(CYAN)Initializing Go Module$(RESET)\n"
	@[ -f go.mod ] || $(GO_CMD) mod init $(PROJECT_NAME)
	@$(GO_CMD) get github.com/a-h/templ
	@printf "$(CHECK) Go module initialized\n"

create-air-config:
	@printf "\n$(CYAN)Creating/Updating .air.toml config...$(RESET)\n"
	@printf 'root = "."\n' > .air.toml
	@printf 'tmp_dir = "tmp"\n\n' >> .air.toml
	@printf '[build]\n' >> .air.toml
	@printf '  cmd = "templ generate && go build -o ./tmp/main ./cmd/$(PROJECT_NAME)/main.go"\n' >> .air.toml
	@printf '  bin = "./tmp/main"\n' >> .air.toml
	@printf '  full_bin = "./tmp/main serve --http=0.0.0.0:42069"\n' >> .air.toml
	@printf '  include_ext = ["go", "tpl", "tmpl", "html", "templ"]\n' >> .air.toml
	@printf '  exclude_dir = ["assets", "tmp", "vendor", "node_modules", "static", "pb_data"]\n' >> .air.toml
	@printf '  exclude_regex = ["_test.go", ".*_templ.go"]\n' >> .air.toml
	@printf '  stop_on_error = true\n\n' >> .air.toml
	@printf '[log]\n' >> .air.toml
	@printf '  time = false\n\n' >> .air.toml
	@printf '[misc]\n' >> .air.toml
	@printf '  clean_on_exit = true\n\n' >> .air.toml
	@printf '[proxy]\n' >> .air.toml
	@printf '  enabled = true\n' >> .air.toml
	@printf '  proxy_port = 8090\n' >> .air.toml
	@printf '  app_port = 42069\n' >> .air.toml
	@printf "$(CHECK) .air.toml configured\n"

create-dirs:
	@printf "\n$(CYAN)Creating project structure$(RESET)\n"
	@mkdir -p $(STATIC_DIR)/js $(STATIC_DIR)/css
	@mkdir -p views/{components,layouts,pages}
	@mkdir -p cmd/$(PROJECT_NAME)
	@[ -f $(MAIN_GO) ] || printf "package main\n\nimport \"net/http\"\n\nfunc main() {\n\t// Simple blocking server so Air doesn't exit immediately\n\thttp.ListenAndServe(\":42069\", nil)\n}\n" > $(MAIN_GO)
	@printf "$(CHECK) Directories created\n"

setup-tailwind:
	@printf "\n$(CYAN)Setting up Tailwind CSS$(RESET)\n"
	@$(BUN_CMD) add -d tailwindcss @tailwindcss/cli
	@printf "@tailwind base;\n@tailwind components;\n@tailwind utilities;" > $(CSS_INPUT)
	@printf "$(CHECK) Tailwind ready\n"

download-alpine:
	@printf "\n$(CYAN)Downloading Alpine.js$(RESET)\n"
	@curl -s $(ALPINE_URL) -o $(STATIC_DIR)/js/alpine.min.js
	@printf "$(CHECK) Alpine.js ready\n"

# -- Init Command --
init: check-deps create-dirs setup-go setup-tailwind download-alpine create-air-config
	@printf "\n$(CHECK) Project initialized successfully!\n"

clean:
	@rm -rf $(BUILD_DIR) *_templ.go
	@printf "$(CHECK) Clean complete\n"

help:
	@printf "\n$(CYAN)Available commands$(RESET)\n"
	@printf "  make dev      $(ARROW) Start Air server + Tailwind watch\n"
	@printf "  make build    $(ARROW) Build binary\n"
	@printf "  make init     $(ARROW) Setup project (checks deps, creates config, init go mod)\n"
	@printf "  make clean    $(ARROW) Remove temp files\n"
