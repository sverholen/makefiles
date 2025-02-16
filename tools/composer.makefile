###
##. Configuration
###

#. Package variables
PHP_QUALITY_ASSURANCE_CHECK_TOOLS+=composer.check-platform-reqs composer.validate

#. Tool variables
COMPOSER_VALIDATE_STRICT?=

###
##. Requirements
###

ifeq ($(COMPOSER_EXECUTABLE),)
$(error The variable COMPOSER_EXECUTABLE should never be empty.)
endif
ifeq ($(COMPOSER_DEPENDENCY),)
$(error The variable COMPOSER_DEPENDENCY should never be empty.)
endif

###
## Quality Assurance
###

# Configure Composer with some more strict flags
# @see https://getcomposer.org/doc/06-config.md
composer.configure-strict: | $(COMPOSER_DEPENDENCY)
	@$(COMPOSER_EXECUTABLE) config optimize-autoloader true
	@$(COMPOSER_EXECUTABLE) config sort-packages true
	@$(COMPOSER_EXECUTABLE) config platform-check true
.PHONY: composer.configure-strict

# Check the PHP and extensions versions
# @see https://getcomposer.org/
composer.check-platform-reqs: | $(COMPOSER_DEPENDENCY)
	@$(COMPOSER_EXECUTABLE) check-platform-reqs
.PHONY: composer.check-platform-reqs

# Validate the Composer configuration
# @see https://getcomposer.org/
composer.validate: | $(COMPOSER_DEPENDENCY)
	@$(COMPOSER_EXECUTABLE) validate$(if $(COMPOSER_VALIDATE_STRICT), --strict) --no-check-publish --no-interaction
.PHONY: composer.validate
