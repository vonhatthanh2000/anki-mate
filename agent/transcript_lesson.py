"""Structured OpenAI analysis for learner-approved English transcripts."""

from __future__ import annotations

import os
import re
from typing import Literal, Optional

from dotenv import load_dotenv
from openai import OpenAI
from pydantic import BaseModel, Field

load_dotenv()

LanguageCategory = Literal[
    "Vocabulary",
    "Idiom",
    "Phrasal verb",
    "Collocation",
    "Slang",
    "Grammar pattern",
]
ExerciseKind = Literal["recognition", "production"]


class MeaningOverview(BaseModel):
    summary: list[str] = Field(max_length=5)
    mainPoint: str
    supportingIdeas: list[str]
    toneAndRegister: str
    contextNotes: list[str]


class LanguageItem(BaseModel):
    id: str
    expression: str
    spanStart: int
    spanEnd: int
    sourceExcerpt: str
    primaryCategory: LanguageCategory
    secondaryCategories: list[LanguageCategory]
    meaningAndUsage: str
    cefrEstimate: str
    selectionRationale: str
    naturalExample: str
    vietnameseGloss: Optional[str] = None
    practicePriority: Optional[int] = None


class LessonExercise(BaseModel):
    id: str
    itemID: str
    kind: ExerciseKind
    prompt: str
    expectedAnswer: Optional[str] = None
    explanation: Optional[str] = None


class LessonAnalysis(BaseModel):
    overview: MeaningOverview
    items: list[LanguageItem] = Field(max_length=10)
    exercises: list[LessonExercise]


class ExerciseFeedback(BaseModel):
    isCorrect: bool
    meaningFeedback: str
    correctnessFeedback: str
    appropriatenessFeedback: str
    naturalnessFeedback: str
    explanation: str
    naturalRevision: str


class EvaluationRequest(BaseModel):
    transcript: str
    item: LanguageItem
    exercise: LessonExercise
    answer: str


ANALYSIS_INSTRUCTIONS = """
You create one concise English lesson from a learner-approved transcript for a CEFR B2 learner.

Explain what the speaker means without researching or fact-checking. Attribute unsupported claims to the speaker. Keep the Meaning Overview short: up to 5 summary sentences, the main point, supporting ideas, tone/register, and only context needed for comprehension. Do not invent summary sentences to meet a minimum.

Select up to 10 unique high-value transcript expressions across Vocabulary, Idiom, Phrasal verb, Collocation, Slang, and Grammar pattern. Return none when the transcript has no worthwhile examples. Do not fill category quotas or invent items to meet a minimum. Rank comprehension value, common reusability, and B2+ relevance. CEFR is an estimate, not certification. A lower-level expression is allowed only when its contextual use is subtle or essential, and its rationale must say why.

Every expression must be copied exactly and contiguously from the transcript. Give it one primary category and only genuinely useful secondary categories. Explain meaning and usage in clear, concise English. Add a short Vietnamese gloss only for a genuinely difficult sentence-level point; otherwise use null.

Choose up to 5 items for practice using practicePriority values 1 through N. Practice may be empty, and items must not be selected merely to meet a minimum. Give each chosen item exactly one recognition exercise and one production exercise. Recognition includes an expected answer and explanation. Production asks for a paraphrase or original sentence and leaves expectedAnswer and explanation null.
""".strip()

EVALUATION_INSTRUCTIONS = """
Evaluate one learner's typed English answer. Be concise and encouraging without hiding mistakes. Judge intended meaning, grammar, contextual appropriateness, and naturalness. Provide a short explanation and one natural revision. Do not discuss pronunciation or spoken delivery.
""".strip()


def _client() -> OpenAI:
    return OpenAI()


def _model() -> str:
    return os.environ.get("TRANSCRIPT_LESSON_MODEL", "gpt-4o-mini")


def _find_expression(
    transcript: str,
    expression: str,
    preferred_start: int,
) -> Optional[tuple[int, int]]:
    matches = list(re.finditer(re.escape(expression), transcript, flags=re.IGNORECASE))
    if not matches:
        return None
    match = min(matches, key=lambda candidate: abs(candidate.start() - max(preferred_start, 0)))
    return match.start(), match.end()


def _utf16_offset(text: str, codepoint_offset: int) -> int:
    """Return the NSString/Swift-compatible UTF-16 offset for a Python index."""

    return len(text[:codepoint_offset].encode("utf-16-le")) // 2


def _source_excerpt(transcript: str, start: int, end: int) -> str:
    left_candidates = [transcript.rfind(mark, 0, start) for mark in ".!?\n"]
    left = max(left_candidates) + 1
    right_candidates = [position for mark in ".!?\n" if (position := transcript.find(mark, end)) >= 0]
    right = min(right_candidates) + 1 if right_candidates else len(transcript)
    return transcript[left:right].strip()


def normalize_analysis(analysis: LessonAnalysis, transcript: str) -> LessonAnalysis:
    """Repair model-provided spans and enforce lesson invariants before Swift sees output."""

    normalized_items: list[LanguageItem] = []
    old_to_new_ids: dict[str, str] = {}
    seen: set[tuple[str, int]] = set()

    for item in analysis.items:
        location = _find_expression(transcript, item.expression.strip(), item.spanStart)
        if location is None:
            continue
        start, end = location
        exact_expression = transcript[start:end]
        identity = (exact_expression.casefold(), start)
        if identity in seen:
            continue
        seen.add(identity)
        new_id = f"item-{len(normalized_items) + 1}"
        old_to_new_ids[item.id] = new_id
        normalized_items.append(
            item.model_copy(
                update={
                    "id": new_id,
                    "expression": exact_expression,
                    "spanStart": _utf16_offset(transcript, start),
                    "spanEnd": _utf16_offset(transcript, end),
                    "sourceExcerpt": _source_excerpt(transcript, start, end),
                }
            )
        )

    item_ids = {item.id for item in normalized_items}
    normalized_exercises: list[LessonExercise] = []
    for exercise in analysis.exercises:
        item_id = old_to_new_ids.get(exercise.itemID)
        if item_id not in item_ids:
            continue
        normalized_exercises.append(
            exercise.model_copy(
                update={
                    "id": f"{item_id}-{exercise.kind}",
                    "itemID": item_id,
                }
            )
        )

    by_item: dict[str, list[LessonExercise]] = {}
    for exercise in normalized_exercises:
        by_item.setdefault(exercise.itemID, []).append(exercise)

    practiced_ids = []
    for item in sorted(
        normalized_items,
        key=lambda candidate: candidate.practicePriority or 999,
    ):
        exercises = by_item.get(item.id, [])
        kinds = {exercise.kind for exercise in exercises}
        if kinds == {"recognition", "production"} and len(exercises) == 2:
            practiced_ids.append(item.id)

    practiced_ids = practiced_ids[:5]
    practice_rank = {item_id: index + 1 for index, item_id in enumerate(practiced_ids)}
    normalized_items = [
        item.model_copy(update={"practicePriority": practice_rank.get(item.id)})
        for item in normalized_items
    ]
    normalized_exercises = [
        exercise for exercise in normalized_exercises if exercise.itemID in practice_rank
    ]

    return LessonAnalysis(
        overview=analysis.overview,
        items=normalized_items,
        exercises=normalized_exercises,
    )


def analyze_transcript(transcript: str) -> LessonAnalysis:
    approved = transcript.strip()
    if not approved:
        raise ValueError("Transcript is required")

    response = _client().responses.parse(
        model=_model(),
        instructions=ANALYSIS_INSTRUCTIONS,
        input=approved,
        text_format=LessonAnalysis,
        store=False,
    )
    if response.output_parsed is None:
        raise ValueError("The model did not return a lesson analysis")
    return normalize_analysis(response.output_parsed, approved)


def evaluate_answer(request: EvaluationRequest) -> ExerciseFeedback:
    response = _client().responses.parse(
        model=_model(),
        instructions=EVALUATION_INSTRUCTIONS,
        input=request.model_dump_json(),
        text_format=ExerciseFeedback,
        store=False,
    )
    if response.output_parsed is None:
        raise ValueError("The model did not return exercise feedback")
    return response.output_parsed
