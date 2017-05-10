
all:
	dub build -b release
	mv paths bin/paths-$(shell date +%s)
