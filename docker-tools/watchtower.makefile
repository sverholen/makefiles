###
##. Dependencies
###

ifeq ($(DOCKER_SOCKET),)
$(error Please provide the variable DOCKER_SOCKET before including this file.)
endif

ifeq ($(DOCKER),)
$(error Please provide the variable DOCKER before including this file.)
endif

###
##. Configuration
###

#. Docker variables for Watchtower
WATCHTOWER_IMAGE?=containrrr/watchtower:latest
WATCHTOWER_SERVICE_NAME?=watchtower

#. Overwrite the Watchtower defaults
WATCHTOWER_TZ?=$(if $(wildcard /etc/timezone),$(shell cat /etc/timezone 2>/dev/null),$(if $(shell command -v timedatectl || which timedatectl 2>/dev/null),$(shell timedatectl show --property=Timezone --value 2>/dev/null)))
WATCHTOWER_LABEL_ENABLE?=true

#. Support for all Watchtower variables
WATCHTOWER_VARIABLES_PREFIX?=WATCHTOWER_
WATCHTOWER_VARIABLES_EXCLUDED?=IMAGE SERVICE_NAME VARIABLES_PREFIX VARIABLES_EXCLUDED VARIABLES_UNPREFIXED
WATCHTOWER_VARIABLES_UNPREFIXED?=TZ NO_COLOR DOCKER_HOST DOCKER_CONFIG DOCKER_API_VERSION DOCKER_TLS_VERIFY DOCKER_CERT_PATH

###
## Docker Tools
###

#. Pull the Watchtower container
watchtower.pull:%.pull:
	@$(DOCKER) image pull "$(WATCHTOWER_IMAGE)"
.PHONY: watchtower.pull

#. Start the Watchtower container
watchtower.start:%.start:
	@if test -z "$$($(DOCKER) container inspect --format "{{ .ID }}" "$(WATCHTOWER_SERVICE_NAME)" 2> /dev/null)"; then \
		$(DOCKER) container run --detach --name "$(WATCHTOWER_SERVICE_NAME)" \
			$(foreach variable,$(filter-out $(addprefix $(WATCHTOWER_VARIABLES_PREFIX),$(WATCHTOWER_VARIABLES_EXCLUDED)),$(filter $(WATCHTOWER_VARIABLES_PREFIX)%,$(.VARIABLES))),--env "$(if $(filter $(WATCHTOWER_VARIABLES_UNPREFIXED),$(patsubst $(WATCHTOWER_VARIABLES_PREFIX)%,%,$(variable))),$(patsubst $(WATCHTOWER_VARIABLES_PREFIX)%,%,$(variable)),$(variable))=$($(variable))") \
			$(if $(DOCKER_CONFIG),--volume "$(DOCKER_CONFIG):$(if $(WATCHTOWER_DOCKER_CONFIG),$(WATCHTOWER_DOCKER_CONFIG),/config.json):ro") \
			--volume "$(DOCKER_SOCKET):/var/run/docker.sock:ro" \
			--label "com.centurylinklabs.watchtower.enable=true" \
			"$(WATCHTOWER_IMAGE)" \
			>/dev/null; \
	else \
		if test -z "$$($(DOCKER) container ls --quiet --filter "status=running" --filter "name=^$(WATCHTOWER_SERVICE_NAME)$$" 2>/dev/null)"; then \
			$(DOCKER) container start "$(WATCHTOWER_SERVICE_NAME)" >/dev/null; \
		fi; \
	fi
.PHONY: watchtower.start

#. Wait for the Watchtower container to be running
watchtower.ensure-running:%.ensure-running: | %.start
	@until test -n "$$($(DOCKER) container ls --quiet --filter "status=running" --filter "name=^$(WATCHTOWER_SERVICE_NAME)$$" 2>/dev/null)"; do \
		if test -z "$$($(DOCKER) container ls --quiet --filter "status=created" --filter "status=running" --filter "name=^$(WATCHTOWER_SERVICE_NAME)$$" 2>/dev/null)"; then \
			printf "$(STYLE_ERROR)%s$(STYLE_RESET)\n" "The container \"$(WATCHTOWER_SERVICE_NAME)\" never started."; \
			$(DOCKER) container logs --since "$$($(DOCKER) container inspect --format "{{ .State.StartedAt }}" "$(WATCHTOWER_SERVICE_NAME)")" "$(WATCHTOWER_SERVICE_NAME)"; \
			exit 1; \
		fi; \
		sleep 1; \
	done
.PHONY: watchtower.ensure-running

#. List the logs of the Watchtower container
watchtower.log:%.log:
	@$(DOCKER) container logs --since "$$($(DOCKER) container inspect --format "{{ .State.StartedAt }}" "$(WATCHTOWER_SERVICE_NAME)")" "$(WATCHTOWER_SERVICE_NAME)"
.PHONY: watchtower.log

#. Stop the Watchtower container
watchtower.stop:%.stop:
	@$(DOCKER) container stop "$(WATCHTOWER_SERVICE_NAME)"
.PHONY: watchtower.stop

#. Clear the Watchtower container
watchtower.clear:%.clear:
	@$(DOCKER) container kill "$(WATCHTOWER_SERVICE_NAME)" &>/dev/null || true
	@$(DOCKER) container rm --force --volumes "$(WATCHTOWER_SERVICE_NAME)" &>/dev/null || true
.PHONY: watchtower.clear

#. Reset the Watchtower volume
watchtower.reset:%.reset:
	-@$(MAKE) $(*).clear
	@$(MAKE) $(*)
.PHONY: watchtower.reset

# Run Watchtower in a container
# @see https://containrrr.dev/watchtower/
watchtower:%: | %.start
	@true
.PHONY: watchtower
