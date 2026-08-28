import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import transcript_acquisition_cli as acquisition


class TranscriptAcquisitionTests(unittest.TestCase):
    source = {
        "canonicalURL": "https://www.youtube.com/watch?v=abc",
        "platform": "youtube",
        "title": None,
        "durationSeconds": None,
        "primaryLanguage": None,
    }

    def test_json3_captions_preserve_code_switching(self):
        payload = json.dumps(
            {
                "events": [
                    {"segs": [{"utf8": "This is English. "}]},
                    {"segs": [{"utf8": "Cảm ơn!"}]},
                ]
            }
        )
        self.assertEqual(
            acquisition._caption_text(payload, "json3"),
            "This is English.\nCảm ơn!",
        )

    def test_punctuated_captions_put_each_sentence_on_its_own_line(self):
        payload = """WEBVTT

00:00:00.000 --> 00:00:02.000
First sentence. Second

00:00:02.000 --> 00:00:04.000
sentence! A final question?
"""

        self.assertEqual(
            acquisition._caption_text(payload, "vtt"),
            "First sentence.\nSecond sentence!\nA final question?",
        )

    def test_unpunctuated_captions_use_cue_boundaries(self):
        payload = """WEBVTT

00:00:00.000 --> 00:00:02.000
the first complete caption cue

00:00:02.000 --> 00:00:04.000
the next complete caption cue
"""

        self.assertEqual(
            acquisition._caption_text(payload, "vtt"),
            "the first complete caption cue\nthe next complete caption cue",
        )

    def test_mixed_captions_use_punctuation_and_local_cue_boundaries(self):
        payload = """WEBVTT

00:00:00.000 --> 00:00:02.000
First sentence. A continued

00:00:02.000 --> 00:00:04.000
sentence!

00:00:04.000 --> 00:00:06.000
an unpunctuated caption cue
"""

        self.assertEqual(
            acquisition._caption_text(payload, "vtt"),
            "First sentence.\nA continued sentence!\nan unpunctuated caption cue",
        )

    def test_unpunctuated_tail_does_not_merge_with_next_unpunctuated_cue(self):
        self.assertEqual(
            acquisition._format_transcript_for_review(
                ["Done. trailing words", "next cue"]
            ),
            "Done.\ntrailing words\nnext cue",
        )

    def test_single_word_overlap_is_preserved_as_possible_repetition(self):
        self.assertEqual(
            acquisition._format_transcript_for_review(["I had", "had enough"]),
            "I had\nhad enough",
        )

    def test_readability_formatting_preserves_source_words_and_order(self):
        source = "One  sentence.   Two words!"

        formatted = acquisition._format_transcript_for_review([source])

        self.assertEqual(formatted, "One sentence.\nTwo words!")
        self.assertEqual(formatted.split(), source.split())

    def test_caption_formatter_does_not_guess_that_repeated_phrases_are_rollup_artifacts(self):
        payload = """WEBVTT

00:00:00.000 --> 00:00:01.000
hello there

00:00:01.000 --> 00:00:02.000
hello there world today

00:00:02.000 --> 00:00:03.000
world today from captions
"""

        self.assertEqual(
            acquisition._caption_text(payload, "vtt"),
            "hello there\nhello there world today\nworld today from captions",
        )

    @patch.object(acquisition, "_download_audio")
    @patch.object(acquisition, "_download_caption", return_value="A usable English caption.")
    @patch.object(acquisition, "_extract_metadata")
    def test_captions_are_preferred_without_media_download(
        self, metadata, _caption, download_audio
    ):
        metadata.return_value = {
            "duration": 120,
            "title": "Short source",
            "language": "en",
            "subtitles": {"en": [{"ext": "vtt", "url": "https://caption"}]},
        }
        result = acquisition.acquire_url(
            {"source": self.source}, object(), object()
        )

        self.assertEqual(result["method"], "captions")
        self.assertEqual(result["detectedLanguage"], "en")
        download_audio.assert_not_called()

    @patch.object(acquisition, "_download_caption", return_value="Translated English captions.")
    @patch.object(acquisition, "_extract_metadata")
    def test_manual_english_captions_do_not_invent_spoken_language(self, metadata, _caption):
        metadata.return_value = {
            "duration": 120,
            "subtitles": {"en": [{"ext": "vtt", "url": "https://caption"}]},
        }

        result = acquisition.lookup_captions({"source": self.source}, object())

        self.assertIsNone(result["acquisition"])

    @patch.object(acquisition, "_extract_metadata")
    def test_over_five_minutes_is_rejected_during_metadata(self, metadata):
        metadata.side_effect = acquisition.AcquisitionError(
            "acquisition", "This video is 301 seconds long; the maximum is five minutes.", False
        )
        with self.assertRaisesRegex(acquisition.AcquisitionError, "five minutes"):
            acquisition.acquire_url({"source": self.source}, object(), object())

    @patch.object(acquisition, "_transcribe")
    @patch.object(acquisition, "_download_audio")
    @patch.object(acquisition, "_extract_metadata")
    @patch.object(acquisition, "_extract_audio", side_effect=lambda path, _directory: path)
    def test_temporary_media_is_cleaned_after_success(
        self, _extract_audio, metadata, download_audio, transcribe
    ):
        metadata.return_value = {"duration": 100, "subtitles": {}, "automatic_captions": {}}
        captured = {}

        def create_media(_youtube_dl, _url, directory):
            captured["directory"] = directory
            path = directory / "source.m4a"
            path.write_bytes(b"audio")
            return path

        download_audio.side_effect = create_media
        transcribe.return_value = acquisition.TranscriptionResult(
            text="the first timed segment the second timed segment",
            language="en",
            cues=["the first timed segment", "the second timed segment"],
        )

        result = acquisition.acquire_url({"source": self.source}, object(), object())

        self.assertEqual(result["method"], "speech_to_text")
        self.assertEqual(
            result["transcript"],
            "the first timed segment\nthe second timed segment",
        )
        self.assertFalse(captured["directory"].exists())

    @patch.object(acquisition, "_transcribe")
    @patch.object(acquisition, "_download_audio")
    @patch.object(acquisition, "_extract_metadata")
    @patch.object(acquisition, "_extract_audio", side_effect=lambda path, _directory: path)
    def test_temporary_media_is_cleaned_after_transcription_failure(
        self, _extract_audio, metadata, download_audio, transcribe
    ):
        metadata.return_value = {"duration": 100, "subtitles": {}, "automatic_captions": {}}
        captured = {}

        def create_media(_youtube_dl, _url, directory):
            captured["directory"] = directory
            path = directory / "source.webm"
            path.write_bytes(b"audio")
            return path

        download_audio.side_effect = create_media
        transcribe.side_effect = acquisition.AcquisitionError(
            "transcription", "Malformed speech-to-text output."
        )

        with self.assertRaises(acquisition.AcquisitionError) as context:
            acquisition.acquire_url({"source": self.source}, object(), object())

        self.assertEqual(context.exception.stage, "transcription")
        self.assertFalse(captured["directory"].exists())

    @patch.object(acquisition, "_transcribe")
    @patch.object(acquisition, "_download_audio")
    @patch.object(acquisition, "_extract_metadata")
    @patch.object(acquisition, "_extract_audio", side_effect=lambda path, _directory: path)
    def test_temporary_media_is_cleaned_after_cancellation(
        self, _extract_audio, metadata, download_audio, transcribe
    ):
        metadata.return_value = {"duration": 100, "subtitles": {}, "automatic_captions": {}}
        captured = {}

        def create_media(_youtube_dl, _url, directory):
            captured["directory"] = directory
            path = directory / "source.webm"
            path.write_bytes(b"audio")
            return path

        download_audio.side_effect = create_media
        transcribe.side_effect = acquisition.AcquisitionCancelled()

        with self.assertRaises(acquisition.AcquisitionCancelled):
            acquisition.acquire_url({"source": self.source}, object(), object())

        self.assertFalse(captured["directory"].exists())

    @patch.object(acquisition, "_probe_duration", return_value=90)
    @patch.object(
        acquisition,
        "_transcribe",
        return_value=acquisition.TranscriptionResult(
            text="Local transcript.",
            language="en",
            cues=["Local transcript."],
        ),
    )
    @patch.object(acquisition, "_extract_audio", side_effect=lambda path, _directory: path)
    def test_authorized_local_file_is_copied_then_cleaned(self, _extract_audio, transcribe, _probe):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "authorized.mov"
            source.write_bytes(b"owned media")

            result = acquisition.transcribe_file(
                {"localFilePath": str(source), "source": None}, object()
            )

            copied_path = transcribe.call_args.args[1]
            self.assertEqual(result["transcript"], "Local transcript.")
            self.assertFalse(copied_path.exists())
            self.assertTrue(source.exists())

    def test_log_sanitization_redacts_api_keys(self):
        with patch.dict("os.environ", {"OPENAI_API_KEY": "sk-secret-value"}):
            message = acquisition._safe_message(RuntimeError("failed sk-secret-value"))
        self.assertNotIn("sk-secret-value", message)
        self.assertIn("[REDACTED]", message)


if __name__ == "__main__":
    unittest.main()
