QX=qx
#/home/oetiker/scratch/qooxdoo/bin/build/qx

AUTOMAKE_OPTIONS=foreign

EXTRA_DIST = compile.js  compile.json  Manifest.json package.json package-lock.json $(shell find source -not -name ".*" -a -not -name "*~" -a -not -name "*.tmp" -a -not -name "Makefile*" -a -type f -print )

if BUILD_QOOXDOO_APP

CBFILES=$(shell find $(CALLBACKERY_QX) -name '*.js')

all-local: build

.PHONY: source source-watch node_modules build clean

node_modules: node_modules/.installed

source: node_modules compiled/source/.built


source-watch: node_modules
	CALLBACKERY_QX=$(CALLBACKERY_QX) $(NPX) $(QX) compile --watch --feedback=false --erase

build: ../public/.built

clean: node_modules
	$(NPX) $(QX) clean

../public/.built: $(EXTRA_DIST) Makefile.in $(CBFILES)
	$(MAKE) node_modules
	CALLBACKERY_QX=$(CALLBACKERY_QX) $(NPX) $(QX) compile --target=build
	mkdir -p ../public/$(QX_CLASS)
	cp -p compiled/build/$(QX_CLASS)/*.js ../public/$(QX_CLASS)
	cp -p compiled/build/index.html ../public
	cp -ap compiled/build/resource   ../public
	touch $@

compiled/source/.built: $(EXTRA_DIST) Makefile.in $(CBFILES)
	CALLBACKERY_QX=$(CALLBACKERY_QX) $(NPX) $(QX) compile --warn-as-error
	touch $@

node_modules/.installed package-lock.json: package.json
	$(NPM) i
	touch $@
endif
