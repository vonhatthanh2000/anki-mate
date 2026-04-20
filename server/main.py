"""HTTP API for vocabulary batches."""

from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from database import get_connection, init_db


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    yield


app = FastAPI(title="anki-mate", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:5173",
        "http://localhost:5173",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class WordIn(BaseModel):
    word: str = Field(min_length=1)
    meaning: str = Field(min_length=1)
    word_type: str = ""
    example_1: str = ""
    example_2: str = ""


class BatchCreate(BaseModel):
    words: list[WordIn]
    paragraph: str = ""


class BatchCreated(BaseModel):
    batch_id: int


@app.post("/api/batches", response_model=BatchCreated)
def create_batch(body: BatchCreate) -> BatchCreated:
    if not body.words:
        raise HTTPException(status_code=400, detail="At least one word is required")

    with get_connection() as conn:
        cur = conn.execute("INSERT INTO batch DEFAULT VALUES")
        batch_id = cur.lastrowid
        assert batch_id is not None

        for w in body.words:
            conn.execute(
                """
                INSERT INTO word (batch_id, word, word_type, meaning, example_1, example_2)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    batch_id,
                    w.word.strip(),
                    w.word_type.strip(),
                    w.meaning.strip(),
                    w.example_1.strip(),
                    w.example_2.strip(),
                ),
            )

        conn.execute(
            "INSERT INTO paragraph (batch_id, paragraph) VALUES (?, ?)",
            (batch_id, body.paragraph.strip()),
        )
        conn.commit()

    return BatchCreated(batch_id=batch_id)
