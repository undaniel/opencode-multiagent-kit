#!/usr/bin/env python3
"""Genera la version endurecida de los agentes del orquestador.

Uso:
    python3 tools/harden_agents.py <dir_upstream> <dir_salida>

El resultado se copia encima de los agentes upstream durante la instalacion.
Los IDs de modelo se dejan como `opencode-go/...` para que los instaladores
los sustituyan por los modelos configurados.
"""

from __future__ import annotations

import pathlib
import sys

GIT_READ_ONLY = '''    "git *": deny
    "git diff*": allow
    "git log*": allow
    "git show*": allow
    "git status*": allow
    "git branch --show-current": allow
    "git rev-parse *": allow
    "git ls-files *": allow
    "git remote -v": allow
'''

SECRET_READ_DENY = '''  read:
    "*": allow
    "**/.env*": deny
    "**/.env.example": allow
    "**/.env.sample": allow
    "**/.env.template": allow
    "**/*.pem": deny
    "**/*.key": deny
    "**/id_rsa*": deny
    "**/.ssh/**": deny
'''

V2_NOTE = (
    "\n> OpenCode V2: the delegation tool is `subagent` (older text calls it `Task`).\n"
)


def replace_once(text: str, old: str, new: str, name: str) -> str:
    if old not in text:
        raise SystemExit(f"[{name}] no se encontro el bloque esperado:\n{old[:160]}")
    return text.replace(old, new, 1)


def add_v2_note(text: str) -> str:
    if "OpenCode V2: the delegation tool" in text:
        return text
    marker = "\n---\n"
    first = text.find(marker, 3)
    if first < 0:
        raise SystemExit("frontmatter sin cierre")
    at = first + len(marker)
    return text[:at] + V2_NOTE + text[at:]


def append(text: str, block: str) -> str:
    return text.rstrip() + "\n\n" + block.strip() + "\n"


def harden(name: str, text: str) -> str:
    text = text.replace(
        "Communicate with the user in **English**.",
        "Communicate with the user in the user's language.",
    )
    text = text.replace(
        "Communicate findings in **English**.",
        "Communicate findings in the user's language.",
    )

    if name != "code-executor.md" and '    "git *": allow\n' in text:
        text = text.replace('    "git *": allow\n', GIT_READ_ONLY, 1)

    if name in {"plan-runner.md", "code-executor.md"}:
        text = replace_once(
            text,
            "  external_directory: ask\n",
            SECRET_READ_DENY + "  external_directory: ask\n",
            name,
        )
    if name in {"code-explorer.md", "spec-critic.md", "docs-reviewer.md"}:
        text = replace_once(
            text,
            "  edit: deny\n",
            "  edit: deny\n" + SECRET_READ_DENY,
            name,
        )

    if name == "orchestrator.md":
        text = add_v2_note(text)
        text = replace_once(
            text,
            '''  skill:
    "gitnexus-*": allow
    security-investigation: allow
    pythonic-quality: allow
''',
            '''  skill:
    "*": deny
    agent-delegation: allow
    task-management: allow
''',
            name,
        )
        text = replace_once(
            text,
            "  task:\n    plan-runner: allow\n",
            "  task:\n    \"*\": deny\n    plan-runner: allow\n",
            name,
        )
        text = replace_once(
            text,
            "1. Decide if the request is **trivial** (single-file / one obvious step). "
            "If so: answer briefly or suggest switching to **`build`**; do **not** spin "
            "multi-phase Delegation unnecessarily.",
            "1. If the request is a question or a pure explanation, answer briefly without delegating. "
            "For **any** code change, plan request, or multi-step work, delegate to **`plan-runner`** "
            "and ensure a plan file exists; the fast path for small edits is the **`build`** agent, "
            "not this one.",
            name,
        )
        text = replace_once(
            text,
            "3. Follow the **agent-delegation** skill to shape **Task** prompts and delegation choices (narrow child prompts).",
            "3. Follow the **agent-delegation** skill to shape **Task** prompts and delegation choices (narrow child prompts).\n"
            "3.5. If the user asked for a plan, or the work touches code, you **must** delegate to "
            "**`plan-runner`** and ensure a plan file exists under `.opencode/plans/`. A plan that "
            "exists only in chat is invalid. Do not write the plan yourself and do not invoke the "
            "`writing-plans` skill directly; that belongs to `plan-runner`.",
            name,
        )
        text = replace_once(
            text,
            "   - **`custom`**: `true`, **`multiple`**: `false`\n4. **Revise** loop:",
            "   - **`custom`**: `true`, **`multiple`**: `false`\n"
            "   - **Security pre-check:** if the change touches auth, network calls, file handling, "
            "external input, secrets, or permissions, run **subagent** → `security-reviewer` on the "
            "plan file **before** asking for approval. Fold blocking findings into the plan.\n"
            "4. **Revise** loop:",
            name,
        )
        text = replace_once(
            text,
            "1. **Task** → **`code-reviewer`** with repository root, summarized changed paths/commits, blocking vs advisory format per that agent prompt.",
            "1. With a stable diff, run **subagent** → `code-reviewer`, `security-reviewer`, and "
            "`docs-reviewer` in parallel when their scopes are independent; combine the verdicts. "
            "At minimum run `code-reviewer`; run `security-reviewer` for sensitive surfaces.",
            name,
        )
        text = replace_once(
            text,
            "2. **Task** → **`docs-reviewer`** if CLI/config/env/public API surfaced.",
            "2. If docs review was not included above, run **subagent** → `docs-reviewer` when "
            "CLI/config/env/public API surfaced.",
            name,
        )
        text = append(
            text,
            """## Hard limits

- Never claim completion without evidence from **subagent** → `test-verifier`.
- Never paste secrets, tokens, or `.env` values into subagent prompts.
- If a fix exceeds the approved plan or touches forbidden paths, stop and re-plan.
- Use **`code-explorer`** for repo discovery; never the built-in `explore` from the orchestrator.
- Ask for plan approval only through the `question` tool with header `PlanApprove`; never in plain chat.
- Final evidence must include the project smoke check (`bash .opencode/smoke.sh` or the stack's
  documented equivalent) plus the test command. A green test suite alone does not prove the app runs.""",
        )

    elif name == "plan-runner.md":
        text = add_v2_note(text)
        text = replace_once(
            text,
            "  task:\n    explore: allow\n",
            "  task:\n    \"*\": deny\n    explore: allow\n",
            name,
        )
        text = replace_once(
            text,
            '''  edit:
    "*": allow
    ".opencode/plans/**": allow
''',
            '''  edit:
    "*": deny
    ".opencode/plans/**": allow
''',
            name,
        )
        text = replace_once(
            text,
            '''  bash:
    "*": allow
''',
            '''  bash:
    "*": deny
    "pwd": allow
    "ls *": allow
    "find *": allow
    "cat *": allow
    "head *": allow
    "tail *": allow
    "grep *": allow
    "rg *": allow
    "git diff*": allow
    "git log*": allow
    "git show*": allow
    "git status*": allow
    "go list *": allow
    "go env *": allow
''',
            name,
        )
        text = replace_once(
            text,
            '''  skill:
    "gitnexus-*": allow
    security-investigation: allow
    pythonic-quality: allow
''',
            '''  skill:
    "*": deny
    writing-plans: allow
    brainstorming: allow
    test-driven-development: allow
    systematic-debugging: allow
''',
            name,
        )
        text = replace_once(
            text,
            """   - context & goals
   - steps / phased approach touching explicit modules/paths
   - risks / rollback considerations
   - testing & verification playbook
   - acceptance criteria enumerated""",
            """   - context & goals
   - non-goals (explicitly out of scope)
   - security & threat notes (input, network, secrets, permissions, SSRF/path traversal)
   - steps / phased approach touching explicit modules/paths
   - test matrix (unit/integration/e2e with exact commands)
   - risks / rollback considerations
   - acceptance criteria enumerated and mapped to tests
   - evidence with `file:line` citations
   - run log: decisions, commands, open questions""",
            name,
        )
        text = append(
            text,
            """## Hard limits

- Never write outside `.opencode/plans/`.
- Never run commands that mutate the repository, network, containers, or infrastructure.
- If a fact is unknown, mark it as `UNRESOLVED` instead of guessing.""",
        )

    elif name == "code-executor.md":
        text = add_v2_note(text)
        text = replace_once(
            text,
            "  edit: allow\n",
            '''  edit:
    "*": allow
    "**/.env*": deny
    "**/*.pem": deny
    "**/*.key": deny
    "**/id_rsa*": deny
    "**/.ssh/**": deny
    "**/.git/**": deny
''',
            name,
        )
        text = replace_once(
            text,
            '''  bash:
    "*": allow
    "git *": allow
    "git commit *": ask
    "git rebase *": ask
    "git reset *": ask
    "git clean *": ask
    "git push *": deny
''',
            '''  bash:
    "*": allow
    "sudo *": deny
    "chown *": deny
    "bash *": deny
    "sh *": deny
    "eval *": deny
    "env *": deny
    "xargs *": deny
    "rm *": ask
    "rm -rf *": ask
    "mv *": ask
    "cp *": ask
    "curl *": ask
    "wget *": ask
    "ssh *": ask
    "scp *": ask
    "docker *": ask
    "kubectl *": ask
    "systemctl *": ask
    "git *": allow
    "git commit *": ask
    "git rebase *": ask
    "git reset *": ask
    "git clean *": ask
    "git branch -D *": ask
    "git restore *": ask
    "git checkout *": ask
    "git apply *": ask
    "git am *": ask
    "git update-index *": ask
    "git stash drop *": ask
    "git tag -d *": ask
    "git push *": deny
''',
            name,
        )
        text = replace_once(
            text,
            '''  skill:
    "gitnexus-*": allow
    security-investigation: allow
    pythonic-quality: allow
''',
            '''  skill:
    "*": deny
    test-driven-development: allow
    systematic-debugging: allow
    verification-before-completion: allow
''',
            name,
        )
        text = append(
            text,
            """## Hard limits

- Never commit or push; the orchestrator/user decides.
- Never read, print, or edit secrets (`.env*`, keys, tokens, `.ssh`).
- Run the narrowest test that proves each slice; report exact commands and output.
- If the slice needs files outside the stated scope, stop and report instead of widening it.""",
        )

    elif name == "code-reviewer.md":
        text = text.replace("  edit: deny\n", "  edit: deny\n" + SECRET_READ_DENY, 1)
        text = append(
            text,
            """Also verify:
- every acceptance criterion has a test or an explicit manual check
- missing tests are blocking
- no unrelated or generated files changed
- no secrets or debug artifacts in the diff""",
        )

    elif name == "docs-reviewer.md":
        text = append(
            text,
            """Also check the README quick start, env vars, config examples, CLI flags, API examples,
and migration notes. Missing user-facing docs are blocking.""",
        )

    elif name == "security-reviewer.md":
        text = text.replace("  edit: deny\n", "  edit: deny\n" + SECRET_READ_DENY, 1)
        text = append(
            text,
            """Also review implementation plans when asked, before code exists. Model threats for
authn/authz, input validation, SSRF, path traversal, command injection, secret handling,
dependency risk, and data exposure. Every finding needs severity, evidence (`file:line`),
and a concrete fix. A missing threat model for a sensitive change is blocking.""",
        )

    elif name == "test-verifier.md":
        text = text.replace("  edit: deny\n", "  edit: deny\n" + SECRET_READ_DENY, 1)
        text = replace_once(
            text,
            '''    "go test": allow
    "go test *": allow
''',
            '''    "go test": allow
    "go test *": allow
    "go build": allow
    "go build *": allow
    "go vet": allow
    "go vet *": allow
    "go run": allow
    "go run *": allow
    "go list *": allow
    "go env *": allow
    "go tool cover *": allow
    "gofmt *": allow
    "golangci-lint run": allow
    "golangci-lint run *": allow
    "staticcheck *": allow
    "govulncheck *": allow
    "go mod verify": allow

    "mvn": allow
    "mvn *": allow
    "./mvnw": allow
    "./mvnw *": allow
    "gradle": allow
    "gradle *": allow
    "./gradlew": allow
    "./gradlew *": allow
    "javac *": allow
    "java -version": allow
    "java -cp *": allow
    "javac -version": allow

    "cargo fmt *": allow
    "cargo clippy *": allow
    "cargo run *": allow

    "bash .opencode/smoke.sh": allow
    "bash .opencode/smoke.sh *": allow
    "sh .opencode/smoke.sh": allow
    "./.opencode/smoke.sh": allow
    "./.opencode/smoke.sh *": allow
    "echo *": allow
    "command -v *": allow
    "which *": allow
''',
            name,
        )
        text = append(
            text,
            """For each acceptance criterion, name the exact test or command that proves it. If no test
exists, say so explicitly; do not infer success. Run targeted checks first and the full suite
once at the end. Disable test caching (`go test -count=1 ./...`, `pytest -p no:cacheprovider`)
so the result reflects the current code. Run the project smoke check too. Write coverage and
temporary artifacts inside the repo (e.g. `coverage.out`), never under `/tmp`: external paths
are outside your permission boundary. Report the exact command and its output summary.
Coverage below the project threshold is a failure. Never edit files.""",
        )

    elif name == "host-security-investigator.md":
        text = replace_once(
            text,
            "  read: allow\n",
            "  read:\n    \"*\": allow\n    \"**/.env*\": deny\n    \"**/.env.example\": allow\n    \"**/.env.sample\": allow\n    \"**/.env.template\": allow\n    \"**/*.pem\": deny\n    \"**/*.key\": deny\n    \"**/id_rsa*\": deny\n    \"**/.ssh/**\": deny\n",
            name,
        )
        text = append(
            text,
            """Report only evidence-backed findings. Never modify hosts, services, firewall rules, or
infrastructure. Redact secret values and personal data.""",
        )

    elif name == "spec-critic.md":
        text = append(
            text,
            """Also require: explicit non-goals, a test matrix mapped to acceptance criteria, a rollback
plan, and a security note for changes touching auth/network/input/files. Reject plans that
lack verifiable acceptance criteria.""",
        )

    return text


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("uso: harden_agents.py <dir_upstream> <dir_salida>")
    src = pathlib.Path(sys.argv[1])
    dst = pathlib.Path(sys.argv[2])
    dst.mkdir(parents=True, exist_ok=True)
    for path in sorted(src.glob("*.md")):
        hardened = harden(path.name, path.read_text())
        (dst / path.name).write_text(hardened)
        print(f"ok {path.name}")


if __name__ == "__main__":
    main()
