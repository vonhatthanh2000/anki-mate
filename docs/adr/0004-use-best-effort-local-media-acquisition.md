# ADR 0004: Use best-effort local media acquisition

Status: Accepted

## Context

Anki Mate is a private macOS tool for one learner rather than a product intended for distribution. The learner values the convenience of submitting a YouTube or TikTok URL even when captions are unavailable.

Platform policies and technical changes can still make arbitrary media acquisition unavailable or unreliable. Personal use reduces the product surface but does not remove those constraints.

## Decision

For a submitted URL, use this local acquisition pipeline:

1. Attempt to obtain usable captions or media locally.
2. If media is obtained, extract only the audio needed for speech-to-text.
3. Transcribe the audio.
4. Delete downloaded media and extracted audio after transcription, including after failures where possible.
5. If URL acquisition fails, allow an authorized local media upload or manual transcript paste.

Treat URL acquisition as best-effort rather than guaranteed platform integration.

## Consequences

- Most short public videos may be handled with a single pasted URL.
- Platform changes can break acquisition independently of lesson analysis.
- Acquisition, transcription, and analysis need separate error states so the learner knows what failed.
- Temporary-file cleanup and bounded processing time are required.
- The app must retain fallback input paths.

