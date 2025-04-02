# Cosmopolitan Libuv Builder

## Overview

This project provides an experimental script to build the [libuv library](https://github.com/libuv/libuv)  using the [Cosmopolitan Libc](https://github.com/jart/cosmopolitan) toolchain. The goal is to produce a static `libuv.a` library that leverages Cosmopolitan's "Compile Once, Run Anywhere" philosophy.

**Disclaimer:** This is highly experimental. The build process and resulting library have not been rigorously tested on various platforms. It was created primarily as an exploration of combining `libuv` with Cosmopolitan. Use with caution and expect potential issues.

## Prerequisites

*   **Standard Build Tools:** `bash`, `git`, `curl`, `unzip`, `patch`
*   **Autotools:** `autoconf`, `automake`, `libtool`
    *   On macOS (Homebrew): `brew install autoconf automake libtool`
    *   On Debian/Ubuntu: `sudo apt-get update && sudo apt-get install -y autoconf automake libtool`

## Included Components

*   `build_libuv_cosmo.sh`: The main build script.
*   `cosmocc_wrapper.sh`: A wrapper script required by the build process to interface with `cosmocc`.
*   `libuv_v1.50.0_cosmo.diff`: A patch file containing necessary modifications to the `libuv` source code for Cosmopolitan compatibility (as of `v1.50.0`).

## Usage

The primary tool is the `build_libuv_cosmo.sh` script.

1.  **Clone this repository:**
    ```bash
    git clone https://github.com/SEBK4C/cosmocc-libuv.git
    cd cosmocc-libuv
    ```

2.  **Run the build script:**
    ```bash
    bash build_libuv_cosmo.sh
    ```

This command will perform the following steps:
*   Download the Cosmopolitan toolchain (`cosmocc.zip`) into `./.cosmocc` if it doesn't exist locally.
*   Clone the official [libuv repository](https://github.com/libuv/libuv) into `./libuv` if it doesn't exist locally, or fetch updates if it does.
*   Check out the specific tag `v1.50.0` of `libuv`.
*   Apply the necessary patches from `libuv_v1.50.0_cosmo.diff` to the source files *temporarily* for the build.
*   Configure and build `libuv` using the downloaded `cosmocc` compiler.
*   Copy the resulting static library (`libuv.a`) and header files into `./cosmocc-libuv-v1.50.0/`.
*   The `./libuv` directory will be left on the `v1.50.0` tag, but will contain uncommitted changes from the patch application.

### Developer Mode

If you intend to work on the patched `libuv` source code directly, you can use the `--dev` flag:

```bash
bash build_libuv_cosmo.sh --dev
```

This performs the same build steps but with one key difference: after applying the patch, it creates a local Git branch named `cosmo-patched-v1.50.0` within the `./libuv` directory and commits the patch changes to this branch. This leaves the `./libuv` repository in a clean state on the patched branch, ready for development.

## Versions

*   **Libuv:** Targets `v1.50.0` ([Link](https://github.com/libuv/libuv/releases/tag/v1.50.0))
*   **Cosmopolitan Toolchain:** Downloads the version available from `https://cosmo.zip/pub/cosmocc/cosmocc.zip` at runtime.

## Contributing

Given the experimental nature, contributions (bug reports, patches, testing results) are welcome via issues or pull requests on the project's repository.

## License

The build scripts and patch file are provided under the MIT License.
`libuv` itself is subject to its own licenses (primarily MIT). See the `./libuv/LICENSE` file after running the build script.
Cosmopolitan Libc is provided under its own license (ISC).

## Acknowledgements

This project builds heavily upon the fantastic work of others. I extend our sincere thanks to:

*   **The libuv team:** For creating and maintaining the robust, cross-platform asynchronous I/O library that forms the core of this effort. ([libuv GitHub](https://github.com/libuv/libuv))
*   **Justine Tunney (jart) and contributors:** For the groundbreaking Cosmopolitan Libc project, which makes the "compile once, run anywhere" goal a possibility. ([Cosmopolitan GitHub](https://github.com/jart/cosmopolitan))
