set shell := ["bash", "-euo", "pipefail", "-c"]

check:
    dart format --output=none --set-exit-if-changed lib packages/nds_ui/lib packages/nds_ui/test packages/nds_ui/integration_test packages/nds_native/lib packages/nds_native/hook
    flutter analyze --no-pub
    cd packages/nds_ui && flutter test --no-pub
    cd packages/nds_native/rust && cargo fmt --check
    cd packages/nds_native/rust && cargo test --locked --lib --jobs 4
    cd packages/nds_native/rust && cargo clippy --locked --all-targets --jobs 4 -- -D warnings
    cd packages/nds_native/rust && cargo audit --deny warnings
    cd packages/nds_native/rust && cargo deny --locked check licenses sources

generate:
    python3 scripts/generate.py

generated-check:
    python3 scripts/generate.py --check

build-linux:
    CARGO_BUILD_JOBS=4 flutter build linux --debug

# Supply a private receipt from the server's isolated PostgreSQL/Mailpit fixture.
identity-acceptance receipt device="linux":
    python3 scripts/identity-acceptance.py --fixture "{{receipt}}" --device "{{device}}"

module-acceptance daemon:
    python3 scripts/module-acceptance.py --clipboard-daemon "{{daemon}}"
