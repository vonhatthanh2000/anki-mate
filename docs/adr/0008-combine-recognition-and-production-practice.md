# ADR 0008: Combine recognition and production practice

Status: Accepted

The 3-item minimum is superseded by ADR 0022; paired practice and the 5-item maximum remain accepted.

## Context

The learner wants to understand authentic videos and improve natural speaking and writing. Recognition-only exercises can confirm comprehension but do not require the learner to retrieve and use new language.

## Decision

Give up to 5 of the most reusable items in each lesson two forms of practice, with no minimum:

1. A contextual recognition exercise such as a cloze, usage choice, or sentence transformation.
2. An active production task that asks the learner to paraphrase or create a new example.

Use AI to assess production answers for meaning, correctness, contextual appropriateness, and naturalness. Return an explanation and a natural revision, not merely a numeric score.

## Consequences

- Practice supports both comprehension and active language use.
- Production evaluation requires an additional model interaction after lesson generation.
- The exercise model must represent prompts, learner answers, feedback, and suggested revisions.
- Only up to 5 of the strongest items receive exercises, keeping lesson length manageable without a minimum quota.
