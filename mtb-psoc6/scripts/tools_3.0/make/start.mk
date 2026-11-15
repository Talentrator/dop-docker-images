# Stand-in for ModusToolbox's tools_3.x/make/start.mk (the tools package is not in
# this image). A code example's Makefile ends with
#   include $(CY_TOOLS_DIR)/make/start.mk
# and CY_TOOLS_PATHS=/opt/mtb/tools_3.0 points it here. The usual targets then
# go through psoc6-build, which builds with the libraries already in the image.
ifneq ($(MTB_PRINT_ONLY),1)
.DEFAULT_GOAL := build
.PHONY: build all app qbuild clean getlibs program qprogram debug

build all app qbuild:
	psoc6-build -o build/$(or $(TARGET),CY8CKIT-062S2-AI)/$(or $(CONFIG),Debug) $(if $(CONFIG),-c $(CONFIG)) .

clean:
	rm -rf build

getlibs:
	@echo "getlibs: every library is already in the image (\$$MTB_LIBS=$(MTB_LIBS)); nothing to fetch"

program qprogram debug:
	@echo "$@: there is no debug probe in this box; build with 'make build' (or psoc6-build) and hand in the project" >&2; exit 1
endif
