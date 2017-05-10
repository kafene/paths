# paths
A utility for manipulating path variables ($PATH, $MANPATH, $INFOPATH, etc.)

Precompiled binaries (targeting the x86_64 architecture only) are in [releases](https://github.com/kafene/paths/releases).

**Working with the source code**:

You'll want to have [dmd](https://github.com/dlang/dmd) and [dub](https://github.com/dlang/dub).

To run tests use `dub test`.

To run the program in-place without explicit compilation use `dub run`, for example: `dub run --rdmd -- --version`.

To compile the program use `dub build`.

**Ideas**:

- more methods
    - `remove <dir>...`
    - `replace <dir_target> <dir_replacement>`
    - `hasAll <dir>...`
    - `validate <path>`
    - `join <dir>...`
    - `create <dir>...`
    - `uniq <path>` or `dedupe <path>`
