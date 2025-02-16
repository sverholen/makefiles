###
##. Configuration
###

DOCKER_DETECTED?=$(shell command -v docker || which docker 2>/dev/null)
DOCKER_DIRECTORY?=.
DOCKER_DEPENDENCY?=$(or $(wildcard $(DOCKER_DIRECTORY))) $(if $(DOCKER_DETECTED),docker.assure-usable,docker.not-found)
DOCKER?=$(if $(wildcard $(filter-out .,$(DOCKER_DIRECTORY))),cd "$(DOCKER_DIRECTORY)" && )docker
DOCKER_SOCKET?=$(firstword $(wildcard /var/run/docker.sock /run/podman/podman.sock ${XDG_RUNTIME_DIR}/podman/podman.sock))
DOCKER_CONFIG?=$(firstword $(wildcard ~/.docker/config.json ${HOME}/.docker/config.json))
DOCKER_API_VERSION?=$(shell $(DOCKER) version --format "{{.Client.APIVersion}}")
DOCKER_REGISTRIES?=

USE_DOCKER_COMPOSE_1?=
DOCKER_COMPOSE_DIRECTORY?=$(if $(wildcard compose.yaml compose.yml docker-compose.yaml docker-compose.yml),.)
ifneq ($(if $(USE_DOCKER_COMPOSE_1),,$(shell docker compose version 2>/dev/null || true)),)
DOCKER_COMPOSE?=$(if $(wildcard $(filter-out .,$(DOCKER_COMPOSE_DIRECTORY))),cd "$(DOCKER_COMPOSE_DIRECTORY)" && )$(DOCKER) compose$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS))
DOCKER_COMPOSE_DEPENDENCY?=$(DOCKER_DEPENDENCY) docker-compose.assure-usable
else
DOCKER_COMPOSE_DETECTED?=$(shell command -v docker-compose || which docker-compose 2>/dev/null)
DOCKER_COMPOSE?=$(if $(wildcard $(filter-out .,$(DOCKER_COMPOSE_DIRECTORY))),cd "$(DOCKER_COMPOSE_DIRECTORY)" && )docker-compose$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS))
DOCKER_COMPOSE_DEPENDENCY?=$(DOCKER_DEPENDENCY) $(if $(DOCKER_DETECTED),docker-compose.assure-usable,docker-compose.not-found)
endif
DOCKER_COMPOSE_FLAGS+=
DOCKER_COMPOSE_BUILD_FLAGS+=
DOCKER_COMPOSE_UP_FLAGS+=--detach
DOCKER_COMPOSE_RUN_FLAGS+=-T --rm --no-deps
DOCKER_COMPOSE_EXEC_FLAGS+=-T
# TODO rename to DOCKER_COMPOSE_ENVIRONMENT_VARIABLES_TO_PASS+=
DOCKER_COMPOSE_RUN_ENVIRONMENT_VARIABLES+=
DOCKER_COMPOSE_EXEC_ENVIRONMENT_VARIABLES+=
ifneq ($(DOCKER_COMPOSE_RUN_ENVIRONMENT_VARIABLES),)
DOCKER_COMPOSE_RUN_FLAGS+=$(foreach var,$(DOCKER_COMPOSE_RUN_ENVIRONMENT_VARIABLES), --env $(var)="$${$(var)}")
endif
ifneq ($(DOCKER_COMPOSE_EXEC_ENVIRONMENT_VARIABLES),)
DOCKER_COMPOSE_EXEC_FLAGS+=$(foreach var,$(DOCKER_COMPOSE_EXEC_ENVIRONMENT_VARIABLES), --env $(var)="$${$(var)}")
endif

###
##. Requirements
###

ifeq ($(DOCKER),)
$(error The variable DOCKER should never be empty.)
endif
ifeq ($(DOCKER_DEPENDENCY),)
$(error The variable DOCKER_DEPENDENCY should never be empty.)
endif
ifeq ($(DOCKER_COMPOSE),)
$(error The variable DOCKER_COMPOSE should never be empty.)
endif
ifeq ($(DOCKER_COMPOSE_DEPENDENCY),)
$(error The variable DOCKER_COMPOSE_DEPENDENCY should never be empty.)
endif

###
## Docker
###

#. Exit if Docker is not found
docker.not-found:
	@printf "$(STYLE_ERROR)%s$(STYLE_RESET)\\n" "Please install Docker."
	@exit 1
.PHONY: docker.not-found

#. Assure that DOCKER is usable
docker.assure-usable: # Do not depend on $(DOCKER_DEPENDENCY), as this is often that target
	@if test -z "$$($(DOCKER) --version 2>/dev/null || true)"; then \
		printf "$(STYLE_ERROR)%s$(STYLE_RESET)\n" 'Could not use DOCKER as "$(value DOCKER)".'; \
		exit 1; \
	fi
.PHONY: docker.assure-usable

# Login to all $DOCKER_REGISTRIES
docker.login: | $(DOCKER_DEPENDENCY)
	@$(foreach registry,$(DOCKER_REGISTRIES),$(DOCKER) login $(registry);)

#. Create a Docker network %
docker.network.%.create: | $(DOCKER_DEPENDENCY)
	@$(DOCKER) network create $(*) 2>/dev/null || true

###
## Compose
###

#. Exit if Docker Compose is not found
docker-compose.not-found:
	@printf "$(STYLE_ERROR)%s$(STYLE_RESET)\\n" "Please install Docker Compose."
	@exit 1
.PHONY: docker-compose.not-found

#. Assure that DOCKER_COMPOSE is usable
docker-compose.assure-usable:
	@if test -z "$$($(DOCKER_COMPOSE) --version 2>/dev/null || true)"; then \
		printf "$(STYLE_ERROR)%s$(STYLE_RESET)\n" 'Could not use DOCKER_COMPOSE as "$(value DOCKER_COMPOSE)".'; \
		exit 1; \
	fi
.PHONY: docker-compose.assure-usable

ifneq ($(DOCKER_COMPOSE_DIRECTORY),)

# Build the image(s)
compose.build: | $(DOCKER_COMPOSE_DEPENDENCY)
	@$(DOCKER_COMPOSE) build$(if $(DOCKER_COMPOSE_BUILD_FLAGS), $(DOCKER_COMPOSE_BUILD_FLAGS)) --pull
.PHONY: compose.build

# Up the service(s)
compose.up: | $(DOCKER_COMPOSE_DEPENDENCY)
	@$(DOCKER_COMPOSE) up$(if $(DOCKER_COMPOSE_UP_FLAGS), $(DOCKER_COMPOSE_UP_FLAGS)) --remove-orphans
.PHONY: compose.up

# Follow the logs from the service(s)
compose.logs: | $(DOCKER_COMPOSE_DEPENDENCY)
	@$(DOCKER_COMPOSE) logs --follow --tail="100"
.PHONY: compose.logs

# Down the service(s)
compose.down: | $(DOCKER_COMPOSE_DEPENDENCY)
	@$(DOCKER_COMPOSE) down --remove-orphans
.PHONY: compose.down

# Kill the service(s)
compose.kill: | $(DOCKER_COMPOSE_DEPENDENCY)
	@$(DOCKER_COMPOSE) kill
.PHONY: compose.kill

# Stop and remove the service(s) and their unnamed volume(s)
compose.clear: | $(DOCKER_COMPOSE_DEPENDENCY)
	@$(DOCKER_COMPOSE) down --remove-orphans --volumes --rmi all; \
	$(DOCKER_COMPOSE) rm --stop --force -v
.PHONY: compose.clear

#. Ensure service % is running
compose.service.%.ensure-running: | $(DOCKER_COMPOSE_DEPENDENCY)
	$(eval COMPOSE_RUNNING_CACHE=$(if $(COMPOSE_RUNNING_CACHE),$(COMPOSE_RUNNING_CACHE),$(shell $(DOCKER_COMPOSE) ps --services --filter "status=running")))
	@if ! echo "$(COMPOSE_RUNNING_CACHE)" | grep -q "$(*)" 2> /dev/null; then \
		$(DOCKER_COMPOSE) up -d --remove-orphans $(*); \
		until $(DOCKER_COMPOSE) ps --services --filter "status=running" | grep -q "$(*)" 2> /dev/null; do \
			if $(DOCKER_COMPOSE) ps --services --filter "status=stopped" | grep -q "$(*)" 2> /dev/null; then \
				printf "$(STYLE_ERROR)%s$(STYLE_RESET)\n" "The service \"$(*)\" stopped unexpectedly."; \
				exit 1; \
			fi; \
			sleep 1; \
		done; \
	fi

#. Ensure service % is stopped
compose.service.%.ensure-stopped: | $(DOCKER_COMPOSE_DEPENDENCY)
	$(eval COMPOSE_RUNNING_CACHE=$(if $(COMPOSE_RUNNING_CACHE),$(COMPOSE_RUNNING_CACHE),$(shell $(DOCKER_COMPOSE) ps --services --filter "status=running")))
	@if echo "$(COMPOSE_RUNNING_CACHE)" | grep -q "$(*)" 2> /dev/null; then \
		$(DOCKER_COMPOSE) stop $(*); \
	fi

COMMAND?=

# Execute a command $(COMMAND) in service %
compose.service.%.exec: compose.service.%.ensure-running | $(DOCKER_COMPOSE_DEPENDENCY)
	@$(DOCKER_COMPOSE) exec$(foreach var,$(DOCKER_COMPOSE_EXEC_ENVIRONMENT_VARIABLES), --env $(var)="$${$(var)}") "$(*)" $(COMMAND)

# Open a shell in service %
compose.service.%.shell: compose.service.%.exec | $(DOCKER_COMPOSE_DEPENDENCY); @true
#. Pass the sh command
compose.service.%.shell: COMMAND:=sh

#. Open a shell in service % (alias)
compose.service.%.sh: compose.service.%.shell | $(DOCKER_COMPOSE_DEPENDENCY); @true

# Open a bash shell in service %
compose.service.%.bash: compose.service.%.exec | $(DOCKER_COMPOSE_DEPENDENCY); @true
#. Pass the bash command
compose.service.%.bash: COMMAND:=bash

endif
