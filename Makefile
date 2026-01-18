.PHONY: build deploy clean

build:
	swift build

deploy: build
	sudo cp .build/debug/focus /usr/local/bin/focus
	sudo cp .build/debug/focus-daemon /usr/local/bin/focus-daemon
	@echo "Deployed focus and focus-daemon to /usr/local/bin/"

clean:
	swift package clean
