###
##. Configuration
###

DOCKER_EXECUTABLE?=$(shell command -v docker || which docker 2>/dev/null || printf "%s" "docker")
DOCKER_SOCKET?=/var/run/docker.sock

DOCKER_COMPOSE_EXECUTABLE?=$(shell command -v docker-compose || which docker-compose 2>/dev/null || printf "%s" "docker-compose")
DOCKER_COMPOSE_EXTRA_FLAGS?=
DOCKER_COMPOSE_FLAGS?=$(if $(DOCKER_COMPOSE_EXTRA_FLAGS), $(DOCKER_COMPOSE_EXTRA_FLAGS))

###
## Docker
###

#. Check if a program is available, exit if it is not
$(DOCKER_EXECUTABLE) $(DOCKER_COMPOSE_EXECUTABLE):%:
	@if ! test -x "$@"; then \
		printf "$(STYLE_ERROR)%s$(STYLE_RESET)\\n" "Could not run \"$@\". Make sure it is installed."; \
		exit 1; \
	fi

RUNNING_CACHE=

# Ensure container % is running
ensure-running-%: | $(DOCKER_COMPOSE_EXECUTABLE)
	$(eval RUNNING_CACHE=$(if $(RUNNING_CACHE),$(RUNNING_CACHE),$(shell $(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) ps --services --filter "status=running")))
	@if ! echo "$(RUNNING_CACHE)" | grep -q "$(*)" 2> /dev/null; then \
		$(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) up -d --remove-orphans "$(*)"; \
		until $(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) ps --services --filter "status=running" | grep -q "$(*)" 2> /dev/null; do \
			if $(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) ps --services --filter "status=stopped" | grep -q "$(*)" 2> /dev/null; then \
				$(call println_error,The image "$(*)" stopped unexpectedly.); \
				exit 1; \
			fi; \
			sleep 1; \
		done; \
	fi

# Ensure container % is not running
ensure-not-running-%: | $(DOCKER_COMPOSE_EXECUTABLE)
	$(eval RUNNING_CACHE=$(if $(RUNNING_CACHE),$(RUNNING_CACHE),$(shell $(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) ps --services --filter "status=running")))
	@if echo "$(RUNNING_CACHE)" | grep -q $(*) 2> /dev/null; then \
		$(DOCKER_COMPOSE_EXECUTABLE)$(if $(DOCKER_COMPOSE_FLAGS), $(DOCKER_COMPOSE_FLAGS)) stop $(*); \
	fi

# Create a Docker network %
create-docker-network-%: | $(DOCKER_EXECUTABLE)
	@$(DOCKER_EXECUTABLE) network create $(*) 2>/dev/null || true

###
## Docker Tools
###

.PHONY: ctop lazydocker

# Ctop - Real-time metrics for containers                      https://ctop.sh/
ctop: | $(DOCKER_EXECUTABLE)
	@set -e; \
		if test -z "$$($(DOCKER_EXECUTABLE) ps --quiet --filter="name=ctop")"; then \
			$(DOCKER_EXECUTABLE) run --rm --interactive --tty --name ctop \
				--volume $(DOCKER_SOCKET):$(DOCKER_SOCKET):ro \
				quay.io/vektorlab/ctop:latest; \
		else \
			$(DOCKER_EXECUTABLE) attach ctop; \
		fi

# Lazydocker - Terminal UI          https://github.com/jesseduffield/lazydocker
lazydocker: | $(DOCKER_EXECUTABLE)
	@$(DOCKER_EXECUTABLE) run --rm --interactive --tty --volume $(DOCKER_SOCKET):$(DOCKER_SOCKET):ro \
		--name lazydocker lazyteam/lazydocker:latest
