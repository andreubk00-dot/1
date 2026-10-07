# OSTATOK 1.37.1 Stable — Release Record

Maintenance-only hotfix from `1.37.0 Final Release`.

Scope is restricted to ambience shutdown lifecycle cleanup. No feature creep, gameplay changes,
save-schema changes, balance changes or art changes are included.

Promotion gates: current High Risk version gate and main SELFTEST must pass on `1.37.1`; package
must exclude `.godot`, temporary/backup files and import-generated stray `.uid` files, then pass
`unzip -t` and SHA-256 recording.

Final runtime promotion gates passed on `1.37.1`: High Risk **130/130** and main SELFTEST
with `failures=0`.

