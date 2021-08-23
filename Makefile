.PHONY: compile
.SILENT: compile

SRC_FILES := $(basename $(shell find . -type f -name "*.fnl" | cut -d'/' -f2-))

compile:
	for f in $(SRC_FILES); do \
		fennel --compile $$f.fnl > $$f.lua; \
		done
