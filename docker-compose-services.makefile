###
##. Configuration
###

DOCKER_SOCKET?=/var/run/docker.sock

DOCKER_EXECUTABLE?=$(shell command -v docker || which docker 2>/dev/null)

DOCKER_COMPOSE_DIRECTORY?=
DOCKER_COMPOSE_EXECUTABLE?=$(shell command -v docker-compose || which docker-compose 2>/dev/null)
DOCKER_COMPOSE_EXTRA_FLAGS?=
DOCKER_COMPOSE_FLAGS?=$(if $(DOCKER_COMPOSE_EXTRA_FLAGS), $(DOCKER_COMPOSE_EXTRA_FLAGS))

ifeq ($(DOCKER_EXECUTABLE),)
$(error Please install docker.)
endif

ifeq ($(DOCKER_COMPOSE_EXECUTABLE),)
$(error Please install docker-compose.)
endif

###
## Docker Compose Services
###

.PHONY: build-images up-services log-services down-services remove-services

RUNNING_CACHE=

#. Ensure container % is running
ensure-running-%:
	$(eval RUNNING_CACHE=$(if $(RUNNING_CACHE),$(RUNNING_CACHE),$(shell $(if $(DOCKER_COMPOSE_DIRECTORY),cd "$(DOCKER_COMPOSE_DIRECTORY)"; )$(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) ps --services --filter "status=running")))
	@if ! echo "$(RUNNING_CACHE)" | grep -q "$(*)" 2> /dev/null; then \
		$(if $(DOCKER_COMPOSE_DIRECTORY),cd "$(DOCKER_COMPOSE_DIRECTORY)";) \
		$(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) up -d --remove-orphans "$(*)"; \
		until $(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) ps --services --filter "status=running" | grep -q "$(*)" 2> /dev/null; do \
			if $(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) ps --services --filter "status=stopped" | grep -q "$(*)" 2> /dev/null; then \
				$(call println_error,The image "$(*)" stopped unexpectedly.); \
				exit 1; \
			fi; \
			sleep 1; \
		done; \
	fi

#. Ensure container % is not running
ensure-not-running-%:
	$(eval RUNNING_CACHE=$(if $(RUNNING_CACHE),$(RUNNING_CACHE),$(shell $(if $(DOCKER_COMPOSE_DIRECTORY),cd "$(DOCKER_COMPOSE_DIRECTORY)"; )$(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) ps --services --filter "status=running")))
	@if echo "$(RUNNING_CACHE)" | grep -q $(*) 2> /dev/null; then \
		$(if $(DOCKER_COMPOSE_DIRECTORY),cd "$(DOCKER_COMPOSE_DIRECTORY)";) \
		$(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) stop $(*); \
	fi

#. Create a Docker network %
create-docker-network-%:
	@$(if $(DOCKER_COMPOSE_DIRECTORY),cd "$(DOCKER_COMPOSE_DIRECTORY)";) \
	$(DOCKER_EXECUTABLE) network create $(*) 2>/dev/null || true

# Build the image(s)
build-images:
	@$(if $(DOCKER_COMPOSE_DIRECTORY),cd "$(DOCKER_COMPOSE_DIRECTORY)";) \
	$(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) build

# Up the service(s)
up-services:
	@$(if $(DOCKER_COMPOSE_DIRECTORY),cd "$(DOCKER_COMPOSE_DIRECTORY)";) \
	$(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) up -d --remove-orphans

# Follow the logs from the service(s)
log-services:
	@$(if $(DOCKER_COMPOSE_DIRECTORY),cd "$(DOCKER_COMPOSE_DIRECTORY)";) \
	$(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) logs --follow --tail="100"

# Down the service(s)
down-services:
	@$(if $(DOCKER_COMPOSE_DIRECTORY),cd "$(DOCKER_COMPOSE_DIRECTORY)";) \
	$(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) down

# Stop and remove the service(s) and volume(s)
remove-services:
	@$(if $(DOCKER_COMPOSE_DIRECTORY),cd "$(DOCKER_COMPOSE_DIRECTORY)";) \
	if test -n "$$($(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) ps --services --filter "status=running" 2> /dev/null)"; then \
		$(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) rm --stop --force -v; \
	fi

# TODO # Clear all volumes
#clear-volumes: docker-compose.yaml docker-compose.dev.yaml | $(DOCKER_DEPENDENCY) stop
#	@$(if $(DOCKER_COMPOSE_DIRECTORY),cd "$(DOCKER_COMPOSE_DIRECTORY)";) \
#	if test -n "$$($(DOCKER_EXECUTABLE) volume ls --quiet --filter label=com.docker.compose.project=<PROJECT_NAME>)"; then \
#		$(DOCKER_EXECUTABLE) volume rm --force $$($(DOCKER_EXECUTABLE) volume ls --quiet --filter label=com.docker.compose.project=sqs-frontend); \
#	fi
