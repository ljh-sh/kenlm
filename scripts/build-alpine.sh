#!/bin/sh
# Build kenlm as a true musl-static binary. Runs INSIDE an Alpine container
# (CI invokes: docker run --rm --platform linux/<arch> -v "$PWD":/w -w /w
#  alpine:3.20 /w/scripts/build-alpine.sh).
#
# Alpine's musl + Boost built from source (Alpine ships no static Boost) +
# FORCE_STATIC => fully static musl binary that runs on Alpine and any Linux.
set -eu

BOOST_VER="${BOOST_VER:-1.84.0}"
BOOST_PREFIX="${BOOST_PREFIX:-/opt/boost}"
BOOST_DIR="boost_$(printf '%s' "$BOOST_VER" | tr . _)"

echo "==> apk add: build deps"
apk add --no-cache build-base cmake git wget bash linux-headers zlib-dev bzip2-dev xz-dev

if [ ! -f "$BOOST_PREFIX/lib/libboost_program_options.a" ]; then
	echo "==> Boost $BOOST_VER from source (musl, static, minimal)"
	cd /tmp
	if [ ! -f "$BOOST_DIR.tar.gz" ]; then
		wget -q "https://archives.boost.org/release/$BOOST_VER/source/$BOOST_DIR.tar.gz"
	fi
	rm -rf "$BOOST_DIR"
	tar xzf "$BOOST_DIR.tar.gz"
	cd "$BOOST_DIR"
	./bootstrap.sh --with-toolset=gcc --prefix="$BOOST_PREFIX" \
		--with-libraries=program_options,system,thread,iostreams,test >/dev/null
	./b2 -j"$(nproc)" \
		link=static runtime-link=static variant=release \
		cxxflags=-fPIC cflags=-fPIC \
		--with-program_options --with-system --with-thread --with-iostreams --with-test \
		--prefix="$BOOST_PREFIX" install
fi

echo "==> cmake configure kenlm (musl + static)"
cd /w
cmake -S upstream/kenlm -B build \
	-DCMAKE_BUILD_TYPE=Release \
	-DFORCE_STATIC=ON \
	-DBoost_USE_STATIC_LIBS=ON \
	-DBOOST_ROOT="$BOOST_PREFIX" \
	-DCMAKE_PREFIX_PATH="/w/cmake"

echo "==> cmake --build"
cmake --build build -j"$(nproc)"

echo "==> built binaries:"
ls -1 build/bin/