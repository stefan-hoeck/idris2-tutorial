export IDRIS2 ?= idris2

lib_pkg = tutorial.ipkg
pwd :=$(shell pwd)

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
	docker build -t idris2-tutorial:dev .

.PHONY: update
update: build-docker
	docker run --rm -v ${pwd}:/work idris2-tutorial:dev