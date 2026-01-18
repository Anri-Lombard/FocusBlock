.PHONY: build deploy clean

build:
	swift build

deploy: build
	sudo cp .build/debug/focus /usr/local/bin/focus
	@echo "Deployed focus to /usr/local/bin/focus"

clean:
	swift package clean
