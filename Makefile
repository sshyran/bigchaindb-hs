
graphdeps:
	scripts/graphdeps.py | dot -Tsvg > dist/deps.svg

build-so:
	stack build --flag bigchaindb:so --ghc-options="-lHSrts-ghc8.0.1" -v --allow-different-user

so: build-so
	python3 scripts/dist-archive.py `ls -t .stack-work/install/x86_64-linux/*/*/lib/x86_64-linux-ghc-8.0.1/libHSbigchaindb*.so | head -n 1`

so-alt: build-so
	python3 scripts/dist-archive.py `ls -t .stack-work/install/x86_64-linux/*/*/lib/x86_64-linux-ghc-8.0.1/bigchaindb*/libHSbigchaindb*.so | head -n 1`

clean:
	rm -rf build
