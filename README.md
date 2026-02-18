# npkg

`npkg` is a FreeBSD `pkg`/ports replacement with deterministic, hash-based builds inspired by Nix.

## Layout

- `pkg.toml`: project-level configuration and policies.
- `groups/*.toml`: install intents (for example `kde.toml`).
- `ports/<name>/versions.toml`: version pointers (`last/current/next`).
- `ports/<name>/<version>/pkg.toml`: exact version recipe.
- `ports/<name>/<version>/*.sh`: per-port build scripts linked from `pkg.toml`.
- `ports.lock`: resolved graph and build ledger for a run.
- `store/`: immutable build outputs.
- `profile/current/`: active symlink tree into `store/`.

`/usr/local` should symlink to `/usr/ports/profile/current`.

## Resolver Policy

- Single-version per port name across the graph (`resolver.strategy = "strict"`).
- Dependencies are resolved only from this repository metadata.
- Recipes must define `[scripts]` with at least `build` and `install`.

## Lockfile Purpose

`ports.lock` tracks:

- the graph that belongs together for a run,
- what was built vs reused,
- what failed and why.

This avoids ambiguity when hash-addressed rebuilds produce many similar outputs.

## CLI

Build:

```sh
cmake -S . -B build-cmake
cmake --build build-cmake -j4
```

Run:

```sh
./build-cmake/tool/pkg/pkg validate
./build-cmake/tool/pkg/pkg resolve --group example
./build-cmake/tool/pkg/pkg build --group example
./build-cmake/tool/pkg/pkg apply
```
