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
