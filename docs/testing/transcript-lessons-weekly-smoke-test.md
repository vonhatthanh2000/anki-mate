# Transcript Lessons packaged weekly smoke test

Run this checklist on the packaged macOS app before releasing Transcript Lessons. Use a supported, primarily English YouTube or TikTok source no longer than five minutes and an authorized local media file with no usable captions.

## Prepare

1. Put `SUPABASE_URL` and `SUPABASE_ANON_KEY` in the project-root `.env` and `OPENAI_API_KEY` in either that file or `agent/.env`. Do not paste credential values into test notes or logs.
2. Install the Python environment with `agent/.venv/bin/pip install -r agent/requirements.txt`.
3. Install `ffmpeg` and `ffprobe`, and open Anki with AnkiConnect enabled.
4. Run `./package_macos_app.sh`. Confirm its final package-verification line passes without printing credential values.
5. Launch `build/AnkiImporter.app` from Finder or with `open build/AnkiImporter.app`.

## Happy path

1. In **Transcript Lessons**, paste the supported URL and acquire its captions. Confirm the canonical source and editable transcript appear before any AI analysis begins.
2. Correct a harmless transcript detail, approve it with **Analyze Approved Transcript**, and confirm the saved result contains:
   - a three-to-five-sentence Meaning Overview;
   - no more than 10 distinct transcript-linked language items; and
   - recognition and production exercises for no more than 5 prioritized items.
3. Complete one recognition and one production exercise. Close and relaunch the app, open the lesson from history, and confirm both attempts and their feedback reload.
4. Export one item. Confirm exactly one **Natural English** note appears in Anki with its source URL. Press export again and confirm no second note is created.
5. Select **Open original source for replay and shadowing** and confirm macOS opens the canonical URL in a registered native app when available, otherwise in the default browser.
6. Confirm BoostVocab can still generate/enrich a word, save and reopen a batch, and export it to Anki.

## Speech-to-text and recovery

1. Use a supported URL without captions, then an authorized local file. Confirm both speech-to-text paths reach the same editable transcript review stage.
2. Verify each recoverable failure independently and retry the same stage:

| Stage | Safe failure to induce | Expected retry behavior |
| --- | --- | --- |
| Acquisition | Disconnect before caption lookup | Retry acquisition; manual/local fallback remains available. |
| Transcription | Temporarily make `ffmpeg` unavailable or disconnect before speech recognition | Retry transcription without starting analysis. |
| Analysis | Disconnect after transcript approval | Retry analysis using the approved transcript. |
| Persistence | Temporarily use an invalid Supabase endpoint after analysis or practice evaluation | Retry the save without repeating completed AI work. |
| Anki | Close Anki before export | Reopen Anki and retry only the export. |

3. Run the acquisition agent cleanup tests with `PYTHONPATH=agent agent/.venv/bin/python -m unittest agent/tests/test_transcript_acquisition.py`. They cover successful, failed, and cancelled jobs.
4. After each real speech-to-text run, inspect the system temporary directory for that job and confirm no `anki-mate-transcript-*` directory or downloaded media remains.

Automation is not a substitute for this external-service smoke run. Record the app build/commit, macOS version, source types, and pass/fail result below. Never record URLs for private media, transcript content, or credentials.

## Smoke evidence

- Commit/build:
- macOS version:
- Caption source: pass / fail
- Speech-to-text source: pass / fail
- Save, reopen, and practice: pass / fail
- Anki export and duplicate prevention: pass / fail
- Native-app/browser source replay: pass / fail
- BoostVocab regression: pass / fail
- Success/failure/cancellation cleanup: pass / fail
