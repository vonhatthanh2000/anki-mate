import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from transcript_backend import (
    BackendError,
    CaptionAcquirer,
    CaptionUnavailable,
    Cue,
    PunctuationRestorer,
    SpeechToTextFallback,
    parse_caption_payload,
    sentences_from_cues,
)


class CaptionAcquirerTests(unittest.TestCase):
    def test_uses_exact_url_prefers_english_and_classifies_youtube(self):
        requested = []
        downloaded = []
        fixture = json.dumps(
            {
                "events": [
                    {"tStartMs": 0, "dDurationMs": 1000, "segs": [{"utf8": "First sentence."}]},
                    {"tStartMs": 1000, "dDurationMs": 1000, "segs": [{"utf8": "Second sentence!"}]},
                ]
            }
        )

        def extract(url):
            requested.append(url)
            return {
                "extractor_key": "Youtube",
                "subtitles": {
                    "fr": [{"ext": "json3", "url": "https://captions/fr"}],
                    "en-US": [{"ext": "json3", "url": "https://captions/en"}],
                },
                "automatic_captions": {
                    "en": [{"ext": "json3", "url": "https://captions/automatic"}]
                },
            }

        def download(url, headers):
            downloaded.append((url, headers))
            return fixture

        exact_url = "https://youtu.be/abc123?t=7"
        result = CaptionAcquirer(extract, download).acquire(exact_url)

        self.assertEqual(requested, [exact_url])
        self.assertEqual(downloaded[0][0], "https://captions/en")
        self.assertEqual(result.source, "youtube_captions")
        self.assertEqual(result.sentences, ["First sentence.", "Second sentence!"])

    def test_reports_caption_unavailable_without_downloading(self):
        downloads = []
        acquirer = CaptionAcquirer(
            lambda _url: {"extractor_key": "TikTok", "subtitles": {"es": []}},
            lambda *args: downloads.append(args),
        )

        with self.assertRaises(CaptionUnavailable):
            acquirer.acquire("https://www.tiktok.com/@creator/video/123")

        self.assertEqual(downloads, [])


class SentenceSegmentationTests(unittest.TestCase):
    def test_restores_punctuation_without_changing_spoken_words(self):
        original = (
            "how to talk about daily routines my daily routine is nothing special "
            "I usually wake up early around 7am breakfast is not important to me "
            "so I usually only drink a cup of coffee"
        )
        restored = [
            "How to talk about daily routines.",
            "My daily routine is nothing special.",
            "I usually wake up early around 7 a.m.",
            "Breakfast is not important to me, so I usually only drink a cup of coffee.",
        ]
        calls = []
        restorer = PunctuationRestorer(lambda text: (calls.append(text), restored)[1])

        result = restorer.restore([Cue(original, 0, 20)])

        self.assertEqual(calls, [original])
        self.assertEqual(result, restored)

    def test_rejects_punctuation_output_that_rewrites_words(self):
        original = (
            "this deliberately long transcript contains the exact spoken words and the punctuation service "
            "must never remove important content or add invented language while it creates readable sentences"
        )
        restorer = PunctuationRestorer(
            lambda _text: ["This deliberately long transcript contains rewritten words."]
        )

        result = restorer.restore([Cue(original, 0, 20)])

        original_characters = "".join(character.lower() for character in original if character.isalnum())
        result_characters = "".join(character.lower() for character in " ".join(result) if character.isalnum())
        self.assertEqual(result_characters, original_characters)
        self.assertGreater(len(result), 1)

    def test_skips_punctuation_service_for_already_segmented_text(self):
        calls = []
        restorer = PunctuationRestorer(lambda text: calls.append(text))

        result = restorer.restore(
            [Cue("This is already clear.", 0, 1), Cue("It has sentence boundaries!", 1, 2)]
        )

        self.assertEqual(result, ["This is already clear.", "It has sentence boundaries!"])
        self.assertEqual(calls, [])

    def test_vtt_collapses_rolling_lines_within_a_cue(self):
        payload = """WEBVTT

00:00:00.000 --> 00:00:02.000
We should
We should leave now.

00:00:02.000 --> 00:00:03.000
Next idea.
"""

        self.assertEqual(
            sentences_from_cues(parse_caption_payload(payload, "vtt")),
            ["We should leave now.", "Next idea."],
        )

    def test_preserves_order_long_text_and_genuine_repetition(self):
        long_sentence = "This is " + ("a deliberately long sentence " * 20).strip() + "."
        cues = [
            Cue("Start here.", 0.0, 1.0),
            Cue(long_sentence, 1.0, 5.0),
            Cue("Say it again.", 5.0, 6.0),
            Cue("Say it again.", 7.0, 8.0),
        ]

        self.assertEqual(
            sentences_from_cues(cues),
            ["Start here.", long_sentence, "Say it again.", "Say it again."],
        )

    def test_removes_only_overlapping_processing_duplicates(self):
        cues = [
            Cue("We should", 0.0, 2.0),
            Cue("We should leave now.", 1.5, 3.5),
            Cue("We should leave now.", 2.0, 3.5),
            Cue("Next idea.", 4.0, 5.0),
        ]

        self.assertEqual(sentences_from_cues(cues), ["We should leave now.", "Next idea."])


class SpeechToTextFallbackTests(unittest.TestCase):
    def test_propagates_exact_url_and_cleans_all_temporary_files(self):
        calls = []
        root = Path(tempfile.mkdtemp())

        def acquire(url, directory):
            calls.append(("acquire", url, directory))
            media = directory / "source.webm"
            media.write_bytes(b"media")
            return media

        def extract(media, directory):
            calls.append(("extract", media, directory))
            audio = directory / "audio.mp3"
            audio.write_bytes(b"audio")
            return audio

        def transcribe(audio):
            calls.append(("transcribe", audio))
            return [Cue("One sentence.", 0, 1), Cue("Another sentence.", 1, 2)]

        cleaned = []
        fallback = SpeechToTextFallback(
            media_acquirer=acquire,
            audio_extractor=extract,
            transcriber=transcribe,
            temporary_directory=lambda: root,
            cleanup=lambda path: (cleaned.append(path), self._remove_tree(path)),
        )
        exact_url = "https://www.youtube.com/watch?v=exact"

        result = fallback.transcribe(exact_url)

        self.assertEqual(calls[0][1], exact_url)
        self.assertEqual(result.source, "speech_to_text")
        self.assertEqual(result.sentences, ["One sentence.", "Another sentence."])
        self.assertEqual(cleaned, [root])
        self.assertFalse(root.exists())

    def test_cleans_temporary_files_when_transcription_fails(self):
        root = Path(tempfile.mkdtemp())
        media = root / "source.webm"
        media.write_bytes(b"media")
        audio = root / "audio.mp3"
        audio.write_bytes(b"audio")
        cleaned = []
        fallback = SpeechToTextFallback(
            media_acquirer=lambda _url, _directory: media,
            audio_extractor=lambda _media, _directory: audio,
            transcriber=lambda _audio: (_ for _ in ()).throw(
                BackendError("transcription_failed", "Transcription failed")
            ),
            temporary_directory=lambda: root,
            cleanup=lambda path: (cleaned.append(path), self._remove_tree(path)),
        )

        with self.assertRaisesRegex(BackendError, "Transcription failed"):
            fallback.transcribe("https://youtu.be/exact")

        self.assertEqual(cleaned, [root])
        self.assertFalse(root.exists())

    def test_success_reports_cleanup_warning_without_losing_transcript(self):
        root = Path(tempfile.mkdtemp())
        media = root / "source.webm"
        media.write_bytes(b"media")
        audio = root / "audio.mp3"
        audio.write_bytes(b"audio")
        fallback = SpeechToTextFallback(
            media_acquirer=lambda _url, _directory: media,
            audio_extractor=lambda _media, _directory: audio,
            transcriber=lambda _audio: [Cue("Kept transcript.", 0, 1)],
            temporary_directory=lambda: root,
            cleanup=lambda _path: (_ for _ in ()).throw(OSError("file busy")),
        )

        result = fallback.transcribe("https://youtu.be/exact")

        self.assertEqual(result.sentences, ["Kept transcript."])
        self.assertIn("file busy", result.cleanup_warning)
        self._remove_tree(root)

    @staticmethod
    def _remove_tree(path):
        for child in path.iterdir():
            child.unlink()
        path.rmdir()


if __name__ == "__main__":
    unittest.main()
