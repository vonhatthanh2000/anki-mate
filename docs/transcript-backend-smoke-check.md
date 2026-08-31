# Transcript backend manual smoke check

This check is opt-in because it accesses live platforms and speech-to-text may incur API cost.

## Provider selection

Set one of these values in the repository `.env`, then restart the app:

```bash
TRANSCRIPT_PROVIDER=tokscript
TRANSCRIPT_PROVIDER=gpt
```

Only keep one active value. The selected provider must report its own error; it must never switch providers.

## TokScript provider

Submit one public YouTube, TikTok, and Instagram URL in the app. On first use, complete TokScript OAuth in the
browser and confirm the app returns with a `TokScript` transcript source. Confirm subsequent requests reuse the
Keychain token without another login. Exhausted quota, a cancelled login, or a TokScript service error should
show an actionable error without downloading media or calling OpenAI.

## Setup

1. Install `ffmpeg` and the packages in `agent/requirements.txt`.
2. Put `OPENAI_API_KEY` in `agent/.env` or the repository `.env` file.
3. Use only public media you own or are authorized to process.

## Platform captions

Run the following with a supported public YouTube URL and then a supported public TikTok URL that has English captions:

```bash
agent/.venv/bin/python3 agent/transcript_cli.py captions "VIDEO_URL"
```

Confirm that the JSON result:

- reports `youtube_captions` or `tiktok_captions` accurately;
- contains ordered, complete sentence strings;
- corresponds to the exact submitted video.

For an auto-caption track without punctuation, confirm the result contains readable sentence rows and that
the words still match the source exactly. Repeat with `TRANSCRIPT_PUNCTUATION_MODE=local` to exercise the
offline fallback.

## GPT audio transcription provider

Set `TRANSCRIPT_PROVIDER=gpt` before this check.

Use a supported public video without usable English captions:

```bash
agent/.venv/bin/python3 agent/transcript_cli.py transcribe "VIDEO_URL"
```

Confirm that the result reports `speech_to_text`, sentence order matches the audio, and no
`anki-mate-transcript-*` directory remains in the system temporary directory afterward. Also exercise an
inaccessible/private URL and confirm it returns an actionable error without an incorrect transcript.

In the app, confirm the status advances through **Downloading audio**, **Preparing audio**,
**Uploading and transcribing**, and **Formatting transcript**. A transient TikTok extraction failure should show
the retry status once before either continuing or returning an actionable error.
