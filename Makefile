export IDRIS2 ?= idris2

lib_pkg = tutorial.ipkg

.PHONY: all
all: lib

.PHONY: lib
lib:
	${IDRIS2} --build ${lib_pkg}

.PHONY: clean
clean:
	${IDRIS2} --clean ${lib_pkg}
	${RM} -r build

.PHONY: develop
develop:
	find -name "*.md" | entr -d idris2 --typecheck ${lib_pkg}


.PHONY: build-docker
build-docker:
	docker build -t idris2-tutorial .

.PHONY: update
update: build-docker
	docker run --rm -it -v /data/project/idris2-tutorial:/work idris2-tutorial


