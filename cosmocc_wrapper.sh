#!/bin/sh

# Path to the real cosmocc (relative to the build directory)
REAL_COSMOCC="../.cosmocc/bin/cosmocc"

# Filter out the problematic argument
filtered_args=()
for arg; do
  # Simple check if the argument starts with -DPACKAGE_STRING=
  case "$arg" in
    -DPACKAGE_STRING=*)
      echo "Wrapper: Skipping argument: $arg" >&2
      continue # Skip this argument
      ;;
  esac
  filtered_args+=("$arg")
done

# Debug: Print the command being executed
# echo "Wrapper: Executing: $REAL_COSMOCC" "${filtered_args[@]}" >&2

# Execute the real cosmocc with filtered arguments
exec "$REAL_COSMOCC" "${filtered_args[@]}" 