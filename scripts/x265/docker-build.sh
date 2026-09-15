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

mkdir -p "$build_root/build" "$dist_dir"

cc=/usr/bin/gcc
cxx=/usr/bin/g++

# Apply static options only when linking. Do not append linker flags to
# every compiler invocation through a compiler wrapper.
static_link_flags="-static -static-libgcc -static-libstdc++ -Wl,-Bstatic"

common_cmake_args="
    -G Ninja
    -D CMAKE_BUILD_TYPE=Release
    -D CMAKE_C_COMPILER=$cc
    -D CMAKE_CXX_COMPILER=$cxx
    -D CMAKE_INSTALL_PREFIX=/usr
    -D ENABLE_HDR10_PLUS=ON
    -D ENABLE_SHARED=OFF
    -D CMAKE_FIND_LIBRARY_SUFFIXES=.a
    -D CMAKE_EXE_LINKER_FLAGS=$static_link_flags
    -W no-dev
"

# ----------------------------------------------------------------------
# Build the 12-bit library.
# ----------------------------------------------------------------------

cmake -S "$src_dir" -B "$build_root/build-12" \
    $common_cmake_args \
    -D ENABLE_CLI=OFF \
    -D EXPORT_C_API=OFF \
    -D HIGH_BIT_DEPTH=ON \
    -D MAIN12=ON

cmake --build "$build_root/build-12" --verbose

test -f "$build_root/build-12/libx265.a"

# ----------------------------------------------------------------------
# Build the 10-bit library.
# ----------------------------------------------------------------------

cmake -S "$src_dir" -B "$build_root/build-10" \
    $common_cmake_args \
    -D ENABLE_CLI=OFF \
    -D EXPORT_C_API=OFF \
    -D HIGH_BIT_DEPTH=ON

cmake --build "$build_root/build-10" --verbose

test -f "$build_root/build-10/libx265.a"

# ----------------------------------------------------------------------
# Prepare the final 8-bit build directory.
#
# The names below are the names expected by x265's multilib CMake logic.
# ----------------------------------------------------------------------

ln -s "$build_root/build-10/libx265.a" \
    "$build_root/build/libx265_main10.a"

ln -s "$build_root/build-12/libx265.a" \
    "$build_root/build/libx265_main12.a"

# ----------------------------------------------------------------------
# Build the CLI as an 8-bit build with linked 10-bit and 12-bit support.
#
# Do not set HIGH_BIT_DEPTH=ON here.
# ----------------------------------------------------------------------

cmake -S "$src_dir" -B "$build_root/build" \
    $common_cmake_args \
    -D ENABLE_CLI=ON \
    -D EXPORT_C_API=ON \
    -D LINKED_10BIT=ON \
    -D LINKED_12BIT=ON \
    -D EXTRA_LIB="x265_main10.a;x265_main12.a" \
    -D EXTRA_LINK_FLAGS="-L$build_root/build"

cmake --build "$build_root/build" --verbose

# x265 normally places the executable in one of these locations.
cli=""

for candidate in \
    "$build_root/build/x265" \
    "$build_root/build/cli/x265"
do
    if [ -x "$candidate" ]; then
        cli="$candidate"
        break
    fi
done

test -n "$cli"

# The final CLI should identify itself as a multilib build.
"$cli" --version

# ----------------------------------------------------------------------
# Combine the three static libraries into one multilib archive.
#
# This is useful if the resulting libx265.a is also consumed by another
# static application.
# ----------------------------------------------------------------------

mv "$build_root/build/libx265.a" \
   "$build_root/build/libx265_main.a"

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
# Install the executable artifact.
# ----------------------------------------------------------------------

cp "$cli" "$dist_dir/x265-linux-x86_64-musl-static"

strip "$dist_dir/x265-linux-x86_64-musl-static"

file "$dist_dir/x265-linux-x86_64-musl-static"
"$dist_dir/x265-linux-x86_64-musl-static" --version

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
