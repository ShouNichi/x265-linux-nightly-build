#!/bin/sh
set -eux

apk add --no-cache \
  build-base \
  cmake \
  git \
  musl-dev \
  nasm \
  ninja \
  tar \
  zstd

tar --version

test -f source/CMakeLists.txt

rm -rf \
  build \
  build-10 \
  build-12 \
  dist

mkdir -p dist

# Force static linking while using Alpine's musl toolchain.
cat > /usr/local/bin/musl-gcc-static <<'EOF'
#!/bin/sh
exec /usr/bin/gcc "$@" \
  -static \
  -static-libgcc \
  -Wl,-Bstatic
EOF

cat > /usr/local/bin/musl-gxx-static <<'EOF'
#!/bin/sh
exec /usr/bin/g++ "$@" \
  -static \
  -static-libgcc \
  -static-libstdc++ \
  -Wl,-Bstatic
EOF

chmod +x \
  /usr/local/bin/musl-gcc-static \
  /usr/local/bin/musl-gxx-static

# Build the 10-bit static library.
cmake -S source -B build-10 \
  -G Ninja \
  -D CMAKE_C_COMPILER=/usr/local/bin/musl-gcc-static \
  -D CMAKE_CXX_COMPILER=/usr/local/bin/musl-gxx-static \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_INSTALL_PREFIX=/usr \
  -D ENABLE_HDR10_PLUS=TRUE \
  -D ENABLE_CLI=FALSE \
  -D ENABLE_SHARED=FALSE \
  -D EXPORT_C_API=FALSE \
  -D HIGH_BIT_DEPTH=TRUE \
  -D CMAKE_FIND_LIBRARY_SUFFIXES=.a \
  -W no-dev

cmake --build build-10
test -f build-10/libx265.a

# Build the 12-bit static library.
cmake -S source -B build-12 \
  -G Ninja \
  -D CMAKE_C_COMPILER=/usr/local/bin/musl-gcc-static \
  -D CMAKE_CXX_COMPILER=/usr/local/bin/musl-gxx-static \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_INSTALL_PREFIX=/usr \
  -D ENABLE_HDR10_PLUS=TRUE \
  -D ENABLE_CLI=FALSE \
  -D ENABLE_SHARED=FALSE \
  -D EXPORT_C_API=FALSE \
  -D HIGH_BIT_DEPTH=TRUE \
  -D MAIN12=TRUE \
  -D CMAKE_FIND_LIBRARY_SUFFIXES=.a \
  -W no-dev

cmake --build build-12
test -f build-12/libx265.a

# Expose the additional bit-depth libraries to the final CLI build.
mkdir -p build

ln -sfn /src/build-10/libx265.a \
  /src/build/libx265_main10.a

ln -sfn /src/build-12/libx265.a \
  /src/build/libx265_main12.a

# Build the final CLI with 8-bit, 10-bit, and 12-bit support.
cmake -S source -B build \
  -G Ninja \
  -D CMAKE_C_COMPILER=/usr/local/bin/musl-gcc-static \
  -D CMAKE_CXX_COMPILER=/usr/local/bin/musl-gxx-static \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_INSTALL_PREFIX=/usr \
  -D ENABLE_HDR10_PLUS=TRUE \
  -D ENABLE_CLI=TRUE \
  -D ENABLE_SHARED=FALSE \
  -D EXTRA_LIB="x265_main10.a;x265_main12.a" \
  -D EXTRA_LINK_FLAGS="-L/src/build -static -Wl,-Bstatic" \
  -D LINKED_10BIT=TRUE \
  -D LINKED_12BIT=TRUE \
  -D CMAKE_FIND_LIBRARY_SUFFIXES=.a \
  -D CMAKE_EXE_LINKER_FLAGS="-static -static-libgcc -static-libstdc++ -Wl,-Bstatic" \
  -W no-dev

cmake --build build --verbose

cli=""

for candidate in build/x265 build/cli/x265; do
  if [ -x "$candidate" ]; then
    cli="$candidate"
    break
  fi
done

test -n "$cli"

cp "$cli" dist/x265-linux-x86_64-musl-static
strip dist/x265-linux-x86_64-musl-static

(
  cd dist
  sha256sum \
    x265-linux-x86_64-musl-static \
    > x265-linux-x86_64-musl-static.sha256
)

tar \
  --sort=name \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  -C dist \
  -czf dist/x265-linux-x86_64-musl-static.tar.gz \
  x265-linux-x86_64-musl-static \
  x265-linux-x86_64-musl-static.sha256

test -x dist/x265-linux-x86_64-musl-static
test -f dist/x265-linux-x86_64-musl-static.sha256
test -f dist/x265-linux-x86_64-musl-static.tar.gz
