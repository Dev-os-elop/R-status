.PHONY: build install uninstall check release publish clean

build:
	./scripts/build-app.sh

install:
	./install.sh

uninstall:
	./uninstall.sh

check:
	./scripts/check.sh

release:
	./scripts/build-release.sh

publish:
	./scripts/publish-release.sh

clean:
	rm -rf .build dist release *.Rcheck *.tar.gz
