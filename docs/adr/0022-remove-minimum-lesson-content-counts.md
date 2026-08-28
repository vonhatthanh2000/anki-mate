# ADR 0022: Remove minimum lesson content counts

Status: Accepted

## Context

Short or low-value transcripts do not always support a fixed number of useful explanations or exercises. Minimum quotas can reject an otherwise valid lesson or encourage invented content.

## Decision

Do not require a minimum number of Meaning Overview summary sentences, language items, or practiced items.

Retain these maximums:

- up to five summary sentences;
- up to ten unique language items;
- up to five practiced items.

Any practiced item must still have exactly one recognition exercise and one production exercise. Existing uniqueness, transcript-span, category, and priority consistency checks remain in force.

This supersedes only the minimum-count portions of ADRs 0005, 0008, 0010, 0012, and 0014.

## Consequences

- A valid lesson may contain no selected language items or exercises.
- The analyzer is not rewarded for inventing weak content to satisfy a quota.
- Lesson size reflects the approved transcript while remaining bounded.
