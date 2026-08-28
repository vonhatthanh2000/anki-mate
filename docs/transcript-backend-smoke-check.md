# Transcript backend manual smoke check

This check is opt-in because it accesses live platforms and speech-to-text may incur API cost.

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

## Speech-to-text fallback

Use a supported public video without usable English captions:

```bash
agent/.venv/bin/python3 agent/transcript_cli.py transcribe "VIDEO_URL"
```

Confirm that the result reports `speech_to_text`, sentence order matches the audio, and no
`anki-mate-transcript-*` directory remains in the system temporary directory afterward. Also exercise an
inaccessible/private URL and confirm it returns an actionable error without an incorrect transcript.
