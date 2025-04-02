#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Check for --dev flag
DEV_MODE=0
if [[ " $@ " =~ " --dev " ]]; then
  DEV_MODE=1
  echo "+++ Developer mode enabled: Patch will be committed to a local branch."
fi

# --- Build Script for libuv v1.50.0 with Cosmopolitan Toolchain ---
#
# This script automates the process of patching and building libuv v1.50.0
# using cosmocc to produce a static library (libuv.a). It downloads
# the required cosmocc binary if not found locally.
#
# Prerequisites:
# 1. curl (for downloading cosmocc)
# 2. Standard build tools: autoconf, automake, libtool
#    (e.g., on macOS with Homebrew: `brew install autoconf automake libtool`)
# 3. Git
# 4. This script, 'libuv_v1.50.0_cosmo.diff', and 'cosmocc_wrapper.sh' in the same directory.
#
# Usage:
#   bash build_libuv_cosmo.sh
#
# --- Configuration ---

# Local directory for Cosmopolitan tools
COSMO_LOCAL_DIR="./.cosmocc"
COSMO_BIN_DIR="$COSMO_LOCAL_DIR/bin"
# Use the zip archive URL
COSMOCC_URL="https://cosmo.zip/pub/cosmocc/cosmocc.zip"
COSMOCC_ZIP_TARGET="$COSMO_LOCAL_DIR/cosmocc.zip"
COSMOCC_TARGET="$COSMO_BIN_DIR/cosmocc"

# Path to cosmocc compiler wrapper
# Adjust if your Cosmopolitan installation is elsewhere
# COSMOCC="${COSMO_PREFIX:-/Users/sebastian/Projects/cosmopolitan}/.cosmocc/3.9.2/bin/cosmocc"

# Git tag to checkout
LIBUV_VERSION="v1.50.0"

# Directory for cloning and building libuv
BUILD_DIR="./libuv"

# Path to the patch file relative to this script
PATCH_FILE="libuv_v1.50.0_cosmo.diff"

# Wrapper script for cosmocc (must exist)
COSMOCC_WRAPPER="./cosmocc_wrapper.sh"

# Project version for output directory name
PROJECT_VERSION="v0.0.1"

# Output directory for the compiled library and headers
OUTPUT_DIR="./libuv_cosmocc_${PROJECT_VERSION}"

# --- Setup Cosmocc ---

echo "+++ Ensuring cosmocc is available..."
if [ ! -x "$COSMOCC_TARGET" ]; then
  echo "   cosmocc not found or not executable at $COSMOCC_TARGET. Downloading and extracting toolchain..."
  mkdir -p "$COSMO_LOCAL_DIR" # Ensure base directory exists
  echo "   Downloading $COSMOCC_URL to $COSMOCC_ZIP_TARGET..."
  if curl -L -f -o "$COSMOCC_ZIP_TARGET" "$COSMOCC_URL"; then
    echo "   Download complete. Extracting zip archive..."
    # Extract into the local dir. -o overwrites without prompting.
    if unzip -oq "$COSMOCC_ZIP_TARGET" -d "$COSMO_LOCAL_DIR"; then
      echo "   Extraction complete."
      # Ensure the main binary is executable after extraction
      if [ -f "$COSMOCC_TARGET" ]; then
          chmod +x "$COSMOCC_TARGET"
          echo "   Made $COSMOCC_TARGET executable."
      else
          echo "Error: $COSMOCC_TARGET not found after extraction." >&2
          rm -f "$COSMOCC_ZIP_TARGET" # Clean up zip on error
          exit 1
      fi
    else
      echo "Error: Failed to extract $COSMOCC_ZIP_TARGET" >&2
      rm -f "$COSMOCC_ZIP_TARGET" # Clean up zip on error
      exit 1
    fi
    # Clean up the zip file after successful extraction
    rm -f "$COSMOCC_ZIP_TARGET"
    echo "   Cleaned up zip file."
  else
    echo "Error: Failed to download cosmocc toolchain from $COSMOCC_URL" >&2
    # Clean up potentially incomplete download
    rm -f "$COSMOCC_ZIP_TARGET"
    exit 1
  fi
else
  echo "   Using existing cosmocc at $COSMOCC_TARGET"
fi

# Verify the final path exists and is executable
if [ ! -x "$COSMOCC_TARGET" ]; then
    echo "Error: cosmocc is still not found or not executable at $COSMOCC_TARGET after download attempt." >&2
    exit 1
fi
# Use the downloaded/verified cosmocc path
COSMOCC="$COSMOCC_TARGET"

# --- Build Steps ---

echo "+++ Ensuring libuv source directory ($BUILD_DIR) exists..."
if [ -d "$BUILD_DIR/.git" ]; then
  echo "   Found existing libuv repository in $BUILD_DIR."
  echo "   Fetching latest changes..."
  (cd "$BUILD_DIR" && git fetch --all --prune)
else
  echo "   Cloning full libuv repository into $BUILD_DIR..."
  # Clone the full repository history
  git clone https://github.com/libuv/libuv.git "$BUILD_DIR"
fi

# Clean up potentially old output dir before build
rm -rf "$OUTPUT_DIR"

echo "+++ Changing to libuv build directory ($BUILD_DIR)..."
cd "$BUILD_DIR"

echo "+++ Checking out specified version (${LIBUV_VERSION})..."
# Stash any local changes to avoid checkout conflicts
git stash push -m "Stashing before build script checkout" || true # Allow stash to fail if nothing to stash

# Checkout the base tag
if git checkout "$LIBUV_VERSION"; then
  echo "   Successfully checked out $LIBUV_VERSION."
  # Always clean the git state before applying patch for build consistency
  git reset --hard HEAD
  git clean -fdx
else
  echo "Error: Failed to checkout tag $LIBUV_VERSION. Does it exist?" >&2
  git stash pop || true # Try to restore stashed changes
  cd ..
  exit 1
fi

echo "+++ Applying Cosmopolitan patches (${PATCH_FILE})..."
# Check if patch file exists
if [ ! -f "../$PATCH_FILE" ]; then
    echo "Error: Patch file ../$PATCH_FILE not found!" >&2
    cd ..
    exit 1
fi
# Apply the patch - This is always needed for the build itself
patch -p1 -N --ignore-whitespace < "../$PATCH_FILE"

# --- Conditional Dev Branch and Commit ---
PATCHED_BRANCH="cosmo-patched-${LIBUV_VERSION}"
if [ "$DEV_MODE" -eq 1 ]; then
  echo "+++ Dev mode: Creating/checking out branch $PATCHED_BRANCH and committing patch..."
  # Create/Reset and checkout the local branch
  git checkout -B "$PATCHED_BRANCH"
  echo "+++ Committing patch to local branch $PATCHED_BRANCH..."
  git add .
  # Use a standard commit message format
  git commit -m "build: Apply Cosmopolitan build patches" -m "Applied patches from ${PATCH_FILE} to base tag ${LIBUV_VERSION}."
  echo "   Patch committed to branch $PATCHED_BRANCH."
else
  echo "+++ Build mode: Patch applied for build, but not committed. HEAD remains at $LIBUV_VERSION."
  # Note: Working directory will contain the uncommitted patch changes necessary for build.
fi

echo "+++ Running autogen.sh..."
./autogen.sh

echo "+++ Configuring build..."
# Define build flags
# Note: -DHAVE_ENUM_ICONV_EILSEQ_DOT_H=0 needed for errno enum issue with Cosmo
export COSMO_CFLAGS="-static -O2 -fno-pie -DHAVE_ENUM_ICONV_EILSEQ_DOT_H=0"
export COSMO_LDFLAGS="-static"

# Configure using the cosmocc wrapper and disabling unsupported features
# CC must point to the correct path of the wrapper script relative to the build dir
CC="../$COSMOCC_WRAPPER" CFLAGS="$COSMO_CFLAGS" LDFLAGS="$COSMO_LDFLAGS" \
ac_cv_lib_CoreFoundation_CFRunLoopRun=no \
ac_cv_header_sys_event_h=no \
./configure --disable-shared --enable-static

echo "+++ Cleaning previous build artifacts..."
make clean

echo "+++ Building libuv.a..."
# Pass CFLAGS directly to make as well, just in case
make CFLAGS="$COSMO_CFLAGS"

echo "+++ Creating output directory ($OUTPUT_DIR)..."
mkdir -p "../$OUTPUT_DIR/lib"
mkdir -p "../$OUTPUT_DIR/include"

echo "+++ Copying libuv.a to output directory..."
if [ -f ".libs/libuv.a" ]; then
  cp .libs/libuv.a "../$OUTPUT_DIR/lib/"
  echo "Success: libuv.a copied to $OUTPUT_DIR/lib"
  ls -l "../$OUTPUT_DIR/lib/libuv.a"
  file "../$OUTPUT_DIR/lib/libuv.a"
else
  echo "Error: .libs/libuv.a not found after build! Cannot copy." >&2
  # Keep build dir for inspection
  exit 1
fi

echo "+++ Copying include files..."
cp -R include/* "../$OUTPUT_DIR/include/"

# Go back to the original directory
cd ..

echo "+++ Build complete! Library and headers in $OUTPUT_DIR"
if [ "$DEV_MODE" -eq 1 ]; then
  echo "+++ NOTE: The libuv source code in '$BUILD_DIR' is now on the '$PATCHED_BRANCH' branch with patches applied and committed."
else
  echo "+++ NOTE: The libuv source code in '$BUILD_DIR' is on tag '$LIBUV_VERSION', but contains uncommitted changes from the build patch."
fi

exit 0 