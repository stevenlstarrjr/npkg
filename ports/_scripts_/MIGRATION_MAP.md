# Script Migration Map

These legacy Linux scripts are used as reference when implementing FreeBSD-native per-port scripts in `ports/<name>/main/`.

- `box2d` <- `build_box2d.sh`
- `bullet` <- `build_bullet.sh`
- `cef` <- none yet
- `entt` <- `build_entt.sh`
- `filament` <- `build_filament.sh`
- `game_network_sockets` <- `build_GameNetworkingSockets.sh`
- `lexbor` <- `build_lexbor.sh`
- `libsodium` <- `build_libsodium.sh`
- `mesa` <- none yet
- `recast_navigation` <- `build_recastnavigation.sh`
- `skia` <- `build_skia.sh`
- `sqlite` <- `build_sqlite3.sh`
- `v8` <- `build_v8.sh`
- `wayland` <- none yet
- `wlroots` <- none yet
- `yoga` <- `build_yoga.sh`
- `zstd` <- `build_zstd.sh`

Current scripts in each port are scaffolds and should be replaced incrementally with real FreeBSD build/install logic.
