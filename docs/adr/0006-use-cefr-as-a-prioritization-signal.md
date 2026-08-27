# ADR 0006: Use CEFR as a prioritization signal

Status: Accepted

## Context

The learner wants B2-and-above material, but assigning a CEFR level to an isolated word or phrase is inherently contextual and approximate. A strict threshold could hide apparently simple language used in a subtle, idiomatic, or conceptually important way.

## Decision

Treat CEFR labels as estimates used for ranking rather than a hard inclusion gate.

- Prioritize estimated B2–C2 language.
- Permit a lower-level item when its use is subtle, easy to misunderstand, or essential to understanding the video.
- Include a short selection rationale for every item.
- Do not present an estimated CEFR label as an objective certification.

## Consequences

- Lessons can teach deceptively simple natural English.
- The analysis output needs both an estimated level and a selection rationale.
- Prompting and evaluation should penalize unjustified CEFR precision.
- The learner can understand why an exception appears in a B2-focused lesson.

