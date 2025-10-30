include $(wildcard .env)

SRCS := $(shell find src -type f)
SRCS_LINT := $(patsubst src/%, ./src/%, $(SRCS))
TRANSPILED := $(patsubst src/%.tl, dist/%.lua, $(SRCS))
ASSETS := $(shell find assets -type f)
DIST_ASSETS := $(patsubst %, dist/%, $(ASSETS))
LUTRO_DIST_DIR ?= $(CURDIR)/dist
LUTRO_DIST_PATH ?= ${LUTRO_DIST_DIR}/explodelon.lutro

dist/%.lua : src/%.tl | dist
	@mkdir -p $(@D) && tl gen $< -o $@

dist/assets/%: assets/% | dist
	@mkdir -p $(@D) && cp $< $@

dist:
	mkdir -p $@

clean:
	rm -rf ./dist || true

${LUTRO_DIST_PATH}: $(TRANSPILED) $(DIST_ASSETS)
	cd dist && zip -r $@ .

package: ${LUTRO_DIST_PATH}

lint:
	tl check ${SRCS_LINT}
