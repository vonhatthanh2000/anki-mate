# ADR 0003: Avoid downloading arbitrary platform media

Status: Rejected in favor of ADR 0004

## Context

When a YouTube or TikTok URL has no accessible transcript, the app could attempt to download the video, extract its audio, and run speech-to-text.

Speech-to-text is technically straightforward. Reliably and permissibly downloading arbitrary media is not. YouTube's official developer policies prohibit API clients from downloading audiovisual content or separating its audio without approval. TikTok's public Display API documents metadata and display capabilities rather than an arbitrary audio-download endpoint.

## Proposed decision

Do not make automated downloading of arbitrary YouTube or TikTok media part of the supported product contract.

Use this acquisition order instead:

1. Use an accessible caption/transcript when permitted.
2. If unavailable, allow the learner to upload a local audio/video file they own or are authorized to use.
3. Offer manual transcript paste as a lightweight fallback.
4. Transcribe authorized uploaded media and delete the temporary media after processing.

## Consequences

- Speech-to-text can still cover videos without captions when the learner can supply an authorized file.
- URL-only analysis will not work for every public video.
- The app avoids depending on undocumented scraping/downloading behavior that may break or violate platform rules.
- The interface must clearly explain why a URL sometimes needs a file or pasted transcript.

## Outcome

The product was clarified to be a private, single-user tool. ADR 0004 accepts best-effort local media acquisition while preserving the safeguards and fallbacks identified here.

