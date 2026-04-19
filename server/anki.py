import requests


def add_anki_card(
    deck_name,
    model_name,
    *,
    word,
    meaning,
    word_type,
    example_1,
    example_2,
    tags=None,
):
    """Add a note via AnkiConnect. Field names must match your note type in Anki exactly."""
    url = "http://localhost:8765"
    payload = {
        "action": "addNote",
        "version": 6,
        "params": {
            "note": {
                "deckName": deck_name,
                "modelName": model_name,
                "fields": {
                    "Word": word,
                    "Meaning": meaning,
                    "Word type": word_type,
                    "Example 1": example_1,
                    "Example 2": example_2,
                },
                "tags": list(tags) if tags else [],
            }
        },
    }
    response = requests.post(url, json=payload)
    return response.json()


if __name__ == "__main__":
    deck_name = "Vocab"
    # Must match the exact note type name in Tools → Manage note types
    model_name = "Basic"  # replace with your custom note type name

    result = add_anki_card(
        deck_name,
        model_name,
        word="ephemeral",
        meaning="lasting a very short time",
        word_type="adjective",
        example_1="The beauty of cherry blossoms is ephemeral.",
        example_2="Social media trends are often ephemeral.",
    )
    print(result)
