include $(wildcard .env)

SRCS := $(filter-out %.d.tl, $(wildcard *.tl))
TRANSPILED := $(patsubst %.tl, dist/%.lua, $(SRCS))
LUTRO_DIST_DIR?=$(CURDIR)/dist
LUTRO_DIST_PATH?=${LUTRO_DIST_DIR}/impact-man.lutro

dist/%.lua : %.tl | dist
	tl gen $< -o $@

dist:
	mkdir -p $@

clean:
	rm -rf ./dist || true

${LUTRO_DIST_PATH}: $(TRANSPILED)
	cd dist && zip $@ $(patsubst dist/%, %, $^)

package: ${LUTRO_DIST_PATH}

lint:
	tl check ${SRCS}
