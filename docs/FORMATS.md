# File Formats

## `groups/*.toml`

```toml
name = "kde"
summary = "KDE desktop stack"
ports = ["wayland", "wlroots", "mesa"]
```

## `ports/<name>/versions.toml`

```toml
last = "0.0.1"
current = "0.0.2"
next = "0.0.3"
```

## `ports/<name>/<version>/pkg.toml`

```toml
name = "example"
version = "0.0.2"
summary = "This is an example"
license = "MIT"
deps = ["m4"]

[src]
type = "url"
url = "https://ftp.example.org/example/example-0.0.2.tar.xz"
sha256 = "..."

[build]
system = "make"

[scripts]
patch = "patch.sh"
build = "build.sh"
install = "install.sh"
check = "check.sh"
```

Supported `build.system` values: `make`, `gmake`, `cmake`, `meson`.
Required script keys: `scripts.build`, `scripts.install`.
Optional script keys: `scripts.patch`, `scripts.check`.
Script paths are relative to `ports/<name>/<version>/`.

## `ports.lock`

- Stores exact graph and build results for a run.
- Uses relative paths for portability.
- Records failures (`error`, `log`) for post-mortem and retry planning.
