# ADR 0002: Keep video playback on the source platform

Status: Accepted

## Context

The transcript lesson needs a transition back to the authentic video, but embedding YouTube and TikTok playback would add platform-specific behavior and distract from the feature's primary purpose.

## Decision

Keep video playback on YouTube or TikTok. Anki Mate will accept the source URL and focus on transcript acquisition, analysis, practice, and selective export to BoostVocab/Anki.

The lesson should provide a convenient way to open the original video again, but it will not embed or reproduce video playback.

## Consequences

- The app avoids owning playback state and platform-specific media controls.
- Timestamp-linked navigation may depend on what each source platform supports.
- The app cannot directly verify whether the learner completed either listen.
- The analysis experience must remain useful without synchronized playback.

