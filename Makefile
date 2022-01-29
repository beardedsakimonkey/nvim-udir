SRC_FILES := $(basename $(shell find . -type f -name "*.fnl" | cut -d'/' -f2-))

all:
	@for f in $(SRC_FILES); do \
		fennel --globals 'vim' --compile $$f.fnl > $$f.lua; \
		done

.PHONY: all
