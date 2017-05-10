
all:
	dub build -b release
	cp paths bin/paths
	mv paths bin/paths-$(shell date +%s)
