# Test Catalog (Reference for Other Repositories)

Use this catalog to design CI layers with clearer debug signals.

1. Static lint and formatting checks
- Syntax/lint/format checks (`bash -n`, `shellcheck`, `shfmt`, language linters).

2. Unit tests
- Small, fast tests for pure functions and local behavior.

3. CLI and contract tests
- Validate flags, exit codes, and stable command/output contracts.

4. Integration tests
- Validate cross-component behavior with realistic dependencies.

5. Dry-run no-mutation tests
- Assert that dry-run paths never change files, git config, or environment state.

6. Idempotency re-run tests
- Run setup/repair flows repeatedly and verify stable end state.

7. Security tests (SAST + secret scanning)
- Static security checks, policy grep checks, and secret detectors.

8. Build/compile/package smoke tests
- Ensure build/release artifacts can be generated from clean state.
