# Provider Handoff Contract

**For External API Reviewers (Gemini / Codex / o3-mini)**

When delegating execution or review to an external model, do not rely on chat history.
Always feed the external model:

1. The exact task objective from `docs/specs/`.
2. The exact text of the relevant template (`docs/templates/review-template.md`).
3. The raw file state or `git diff HEAD`.

Artifacts are the shared contract. Chat is ephemeral.
