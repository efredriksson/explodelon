include $(wildcard .env)
.PHONY: package clean lint format dev

DIST_DIR ?= dist
ALL_SRCS := $(shell find src -type f -name "*.tl")
SRCS := $(filter-out %.d.tl, $(ALL_SRCS))
SRCS_LINT := $(patsubst src/%, ./src/%, $(ALL_SRCS))
TRANSPILED := $(patsubst src/%.tl, ${DIST_DIR}/%.lua, $(SRCS))
ASSETS := $(shell find assets -type f)
DIST_ASSETS := $(patsubst %, ${DIST_DIR}/%, $(ASSETS))
LUTRO_DIST_DIR ?= $(CURDIR)
LUTRO_DIST_NAME ?= explodelon.lutro
LUTRO_DIST_PATH ?= ${LUTRO_DIST_DIR}/${LUTRO_DIST_NAME}

${DIST_DIR}/%.lua : src/%.tl
	@mkdir -p $(@D)
	@tl gen -c $< -o $@

${DIST_DIR}/assets/%: assets/%
	@mkdir -p $(@D) && cp $< $@

clean:
	rm -rf ${DIST_DIR} || true

${LUTRO_DIST_PATH}: $(TRANSPILED) $(DIST_ASSETS)
	cd ${DIST_DIR} && zip -r $@ . -x .reload-stamp

package: ${LUTRO_DIST_PATH}

lint:
	tl check ${SRCS_LINT}
	ceru --check src

format:
	ceru src

dev:
	tl run src/engine/watch.tl ${DIST_DIR} assets
