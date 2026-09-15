#!/bin/sh
set -eux

src_dir=/src/source
build_root=/src
dist_dir=/src/dist

apk add --no-cache \
    build-base \
    cmake \
    git \
    musl-dev \
    nasm \
    ninja \
    tar \
    zstd

test -f "$src_dir/CMakeLists.txt"

rm -rf \
    "$build_root/build" \
    "$build_root/build-10" \
    "$build_root/build-12" \
    "$dist_dir"

mkdir -p \
    "$build_root/build" \
    "$dist_dir"

cc=/usr/bin/gcc
cxx=/usr/bin/g++

# These options are passed to the linker only.
static_link_flags="-static -static-libgcc -static-libstdc++ -Wl,-Bstatic"

configure_x265()
{
    build_dir=$1
    shift

    cmake \
        -S "$src_dir" \
        -B "$build_dir" \
        -G Ninja \
        "-DCMAKE_BUILD_TYPE=Release" \
        "-DCMAKE_C_COMPILER=$cc" \
        "-DCMAKE_CXX_COMPILER=$cxx" \
        "-DCMAKE_INSTALL_PREFIX=/usr" \
        "-DENABLE_HDR10_PLUS=ON" \
        "-DENABLE_SHARED=OFF" \
        "-DCMAKE_FIND_LIBRARY_SUFFIXES=.a" \
        "-DCMAKE_EXE_LINKER_FLAGS=$static_link_flags" \
        -Wno-dev \
        "$@"
}

# ----------------------------------------------------------------------
# Build the 12-bit static library.
# ----------------------------------------------------------------------

configure_x265 "$build_root/build-12" \
    "-DENABLE_CLI=OFF" \
    "-DEXPORT_C_API=OFF" \
    "-DHIGH_BIT_DEPTH=ON" \
    "-DMAIN12=ON"

cmake --build "$build_root/build-12" --verbose

test -f "$build_root/build-12/libx265.a"

# ----------------------------------------------------------------------
# Build the 10-bit static library.
# ----------------------------------------------------------------------

configure_x265 "$build_root/build-10" \
    "-DENABLE_CLI=OFF" \
    "-DEXPORT_C_API=OFF" \
    "-DHIGH_BIT_DEPTH=ON"

cmake --build "$build_root/build-10" --verbose

test -f "$build_root/build-10/libx265.a"

# ----------------------------------------------------------------------
# Expose the additional bit-depth libraries to the final CLI build.
# ----------------------------------------------------------------------

ln -s \
    "$build_root/build-10/libx265.a" \
    "$build_root/build/libx265_main10.a"

ln -s \
    "$build_root/build-12/libx265.a" \
    "$build_root/build/libx265_main12.a"

# ----------------------------------------------------------------------
# Build the final 8-bit CLI with 10-bit and 12-bit support.
#
# HIGH_BIT_DEPTH is intentionally not enabled for this build.
# ----------------------------------------------------------------------

configure_x265 "$build_root/build" \
    "-DENABLE_CLI=ON" \
    "-DEXPORT_C_API=ON" \
    "-DLINKED_10BIT=ON" \
    "-DLINKED_12BIT=ON" \
    "-DEXTRA_LIB=x265_main10.a;x265_main12.a" \
    "-DEXTRA_LINK_FLAGS=-L$build_root/build"

cmake --build "$build_root/build" --verbose

# ----------------------------------------------------------------------
# Locate the executable.
# ----------------------------------------------------------------------

cli=""

for candidate in \
    "$build_root/build/x265" \
    "$build_root/build/cli/x265"
do
    if [ -x "$candidate" ]; then
        cli=$candidate
        break
    fi
done

test -n "$cli"

# Confirm that the binary starts before stripping it.
"$cli" --version

# ----------------------------------------------------------------------
# Create a combined static library containing all three bit depths.
# ----------------------------------------------------------------------

if [ -f "$build_root/build/libx265.a" ]; then
    mv \
        "$build_root/build/libx265.a" \
        "$build_root/build/libx265_main.a"
fi

ar -M <<EOF
CREATE $build_root/build/libx265.a
ADDLIB $build_root/build/libx265_main.a
ADDLIB $build_root/build/libx265_main10.a
ADDLIB $build_root/build/libx265_main12.a
SAVE
END
EOF

test -f "$build_root/build/libx265.a"

# ----------------------------------------------------------------------
# Package the CLI.
# ----------------------------------------------------------------------

output="$dist_dir/x265-linux-x86_64-musl-static"

cp "$cli" "$output"
strip "$output"

file "$output"
"$output" --version

(
    cd "$dist_dir"

    sha256sum \
        x265-linux-x86_64-musl-static \
        > x265-linux-x86_64-musl-static.sha256
)

tar \
    --sort=name \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    -C "$dist_dir" \
    -czf "$dist_dir/x265-linux-x86_64-musl-static.tar.gz" \
    x265-linux-x86_64-musl-static \
    x265-linux-x86_64-musl-static.sha256

test -x "$dist_dir/x265-linux-x86_64-musl-static"
test -f "$dist_dir/x265-linux-x86_64-musl-static.sha256"
test -f "$dist_dir/x265-linux-x86_64-musl-static.tar.gz"
