# Technical Decisions

Use this file to track decisions that affect architecture, workflows, or long-term maintenance.

## Decision template

```md
## DEC-YYYYMMDD-<slug>
- Date: YYYY-MM-DD
- Status: proposed | accepted | superseded
- Context:
  What problem or constraint required a decision?
- Decision:
  What was chosen?
- Consequences:
  What benefits, tradeoffs, and follow-up actions result from this choice?
- Alternatives considered:
  List options that were rejected and why.
- Supersedes / Superseded by:
  Optional links to related decisions.
```

## Examples

## DEC-20260309-modular-zsh-loading
- Date: 2026-03-09
- Status: accepted
- Context:
  A single large `.zshrc` becomes hard to maintain and reason about over time.
- Decision:
  Load shell configuration from ordered modules in `shell/` via `zshrc.bootstrap`.
- Consequences:
  Improves readability and change isolation; requires keeping numeric load order stable.
- Alternatives considered:
  Keep a monolithic `.zshrc` file; rejected due to maintainability cost.
- Supersedes / Superseded by:
  None.

## DEC-20260309-idempotent-bootstrap
- Date: 2026-03-09
- Status: accepted
- Context:
  Setup scripts are run repeatedly on clean and existing machines.
- Decision:
  Keep install/doctor flows idempotent with backups and safe re-linking.
- Consequences:
  Reduces risk during re-runs; adds extra checks and branching in scripts.
- Alternatives considered:
  One-shot setup with manual rollback; rejected due to operational risk.
- Supersedes / Superseded by:
  None.

## DEC-20260310-relative-bootstrap-path-resolution
- Date: 2026-03-10
- Status: accepted
- Context:
  `zshrc.bootstrap` assumed the repository lived at `~/.dotfiles`, which broke shell module loading when the repo was cloned elsewhere.
- Decision:
  Resolve `DOTFILES_ROOT` from the bootstrap file path itself and load modules from `$DOTFILES_ROOT/shell`.
- Consequences:
  Preserves reproducibility and location independence across clean installs and alternate clone paths; adds a small path resolution step in bootstrap.
- Alternatives considered:
  Keep hardcoded `~/.dotfiles`; rejected because it violates location-independent setup goals.
- Supersedes / Superseded by:
  None.

## DEC-20260310-compinit-cache-refresh
- Date: 2026-03-10
- Status: accepted
- Context:
  Zsh startup time was dominated by running full `compinit` on every interactive shell launch.
- Decision:
  Use `.zcompdump` cache with `compinit -C` when cache is fresh and rebuild it with full `compinit` when missing or older than 24 hours.
- Consequences:
  Improves interactive shell startup latency while keeping completion metadata refreshed on a predictable cadence.
- Alternatives considered:
  Always run full `compinit`; rejected due to avoidable startup cost.
- Supersedes / Superseded by:
  None.

## DEC-20260310-installer-non-interactive-flags
- Date: 2026-03-10
- Status: accepted
- Context:
  Optional Git setup steps in `install.sh` relied on interactive prompts, which made clean-install automation and CI provisioning harder.
- Decision:
  Add installer flags for non-interactive execution and explicit optional-step behavior:
  `--non-interactive`, `--strict-extensions`, `--configure-signing=<yes|no|prompt>`, `--configure-identity=<yes|no|prompt>`, `--signing-key`, `--git-name`, and `--git-email`.
- Consequences:
  Enables deterministic automation while preserving current interactive defaults for manual usage.
  Explicit `yes` modes are fail-fast when prerequisites are missing, preventing silent partial setup in automation.
  Non-TTY stdin is auto-detected and treated as non-interactive to avoid blocking reads in pipelines/CI.
  Extension setup can run in strict mode (`--strict-extensions`) for CI safety.
  Explicit CLI identity/signing inputs are treated as deterministic desired state, including updates when current config differs.
  Conflicting flag combinations are rejected early (for example required values combined with explicit `no` modes).
- Alternatives considered:
  Keep prompt-only behavior; rejected due to poor automation ergonomics.
- Supersedes / Superseded by:
  None.

## DEC-20260310-doctor-non-interactive-safety
- Date: 2026-03-10
- Status: accepted
- Context:
  `doctor.sh --fix` could attempt GUI actions (`open -a "Visual Studio Code"`) in CI/headless environments.
- Decision:
  Add `--non-interactive` support and auto-detect non-TTY stdin to disable GUI auto-open behavior in doctor fix mode.
- Consequences:
  Prevents blocking or inappropriate GUI actions in automated environments while keeping local interactive repair behavior.
- Alternatives considered:
  Keep GUI open attempts in all `--fix` runs; rejected due to headless automation risk.
- Supersedes / Superseded by:
  None.

## DEC-20260310-bounded-agent-socket-detection
- Date: 2026-03-10
- Status: accepted
- Context:
  Recursive socket discovery with `find "$HOME/Library/Group Containers"` proved slow or blocking on some systems, which could stall `install.sh` and `doctor.sh`.
  Also, installer `--non-interactive` mode was not explicitly propagated to post-install doctor invocation in TTY sessions.
- Decision:
  Replace recursive `find`-based 1Password SSH agent socket discovery with bounded glob/`compgen` lookup in both scripts.
  Propagate installer non-interactive mode to the post-install doctor run, including the `--fix` path.
  Preserve non-interactive mode during doctor revalidation after applied fixes.
- Consequences:
  Removes a class of hangs from large/slow macOS Group Containers trees.
  Keeps post-install behavior consistent with caller intent for automation and headless safety.
  Adds small helper functions and argument-array plumbing in scripts.
- Alternatives considered:
  Keep recursive `find`; rejected due to observed blocking behavior.
  Skip doctor from installer when non-interactive; rejected because it removes useful validation in automation.
- Supersedes / Superseded by:
  None.

## DEC-20260310-dry-run-modes-for-install-and-doctor
- Date: 2026-03-10
- Status: accepted
- Context:
  There was no safe preview path for script behavior, which made auditing harder in new machines and CI rehearsals.
- Decision:
  Add `--dry-run` mode to `install.sh` and `doctor.sh`.
  In dry-run mode, scripts print planned changes but do not modify files, global Git config, or environment/session sockets.
  Installer dry-run also propagates dry-run mode to post-install doctor execution.
- Consequences:
  Enables deterministic audits before applying changes.
  Improves confidence for headless automation and first-time bootstrap checks.
  Adds additional branches in fix/write paths that must remain tested.
- Alternatives considered:
  Document expected behavior without execution; rejected because it still requires manual command tracing.
  Add a separate audit script; rejected to avoid duplicated logic.
- Supersedes / Superseded by:
  None.

## DEC-20260310-shell-quality-gates
- Date: 2026-03-10
- Status: accepted
- Context:
  Repository quality checks were manual.
- Decision:
  Add a GitHub Actions CI workflow with shell quality gates: `bash -n`, `shellcheck`, `shfmt -d`, installer smoke tests, and doctor non-interactive checks.
- Consequences:
  Catches shell regressions earlier and keeps automation behavior measurable.
  Slightly increases maintenance work to keep tests current.
- Alternatives considered:
  Keep ad hoc local validation only; rejected due to lower reliability.
  Add heavyweight test framework; rejected as unnecessary for current repository size.
- Supersedes / Superseded by:
  None.

## DEC-20260310-git-only-release-tracking
- Date: 2026-03-10
- Status: accepted
- Context:
  The repository is personal/public and changelog maintenance duplicated information already present in commits and tags.
  The extra file created drift risk in README and onboarding docs.
- Decision:
  Remove `CHANGELOG.md` from the repository.
  Track releases exclusively through annotated Git tags and commit history.
- Consequences:
  Reduces repository maintenance and stale release-note risk in tracked files.
  Consumers inspect release metadata using Git primitives (`git tag`, `git show`, `git log`).
- Alternatives considered:
  Keep `CHANGELOG.md`; rejected due to duplicated maintenance overhead for this repository scope.
- Supersedes / Superseded by:
  Supersedes the release-tracking portion previously bundled with CI guidance.

## DEC-20260310-doctor-smoke-test-coverage
- Date: 2026-03-10
- Status: accepted
- Context:
  CI covered installer CLI semantics but lacked a dedicated smoke suite for doctor CLI scenarios.
  This left argument handling and dry-run no-mutation behavior for `doctor.sh` less directly verified.
- Decision:
  Add `scripts/test-doctor-flags.sh` and wire it into CI/lint/format checks.
  Cover key scenarios: help output, unknown argument rejection, non-interactive execution, `--fix --dry-run` execution, and dry-run no-mutation behavior in temporary HOME.
- Consequences:
  Improves confidence that doctor CLI contracts remain stable across refactors.
  Keeps tests lightweight and shell-native without introducing extra dependencies.
  Requires maintaining one additional smoke script and CI step.
- Alternatives considered:
  Rely only on end-to-end doctor invocation in CI; rejected due to weaker CLI contract coverage.
  Move to a full shell testing framework; rejected as unnecessary for current repository complexity.
- Supersedes / Superseded by:
  None.
