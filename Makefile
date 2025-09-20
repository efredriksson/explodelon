include $(wildcard .env)

SRCS := $(filter-out %.d.tl, $(wildcard *.tl))
TRANSPILED := $(patsubst %.tl, dist/%.lua, $(SRCS))
ASSETS := $(wildcard assets/*)
DIST_ASSETS := $(patsubst %, dist/%, $(ASSETS))
LUTRO_DIST_DIR?=$(CURDIR)/dist
LUTRO_DIST_PATH?=${LUTRO_DIST_DIR}/explodelon.lutro

dist/%.lua : %.tl | dist
	tl gen $< -o $@

dist/assets/% : assets/% | dist/assets
	cp $< $@

dist:
	mkdir -p $@

dist/assets: dist
	mkdir -p $@

clean:
	rm -rf ./dist || true

${LUTRO_DIST_PATH}: $(TRANSPILED) $(DIST_ASSETS)
	cd dist && zip -r $@ .

package: ${LUTRO_DIST_PATH}

lint:
	tl check ${SRCS}
