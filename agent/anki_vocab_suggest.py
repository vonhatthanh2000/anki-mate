from phi.agent import Agent
from phi.model.openai import OpenAIChat
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

ANKI_VOCAB_DESCRIPTION = """
This agent is designed to assist users in creating vocabulary entries for learning English. Users will input a word and its meaning, and the agent will automatically generate additional information such as the word type and example sentences.
You are strict, clear, and concise like a real IELTS examiner.
"""


ANKI_VOCAB_INSTRUCTIONS = [
 """

1. **Input Format:**
    
    - Users will enter the following details:
        - **Word**: The vocabulary word to be learned.
        - **Meaning**: The definition of the word (can be in English or Vietnamese).
2. **User Flow:**
    
    - The user will input values for Word and Meaning.
    - The agent will process this input to generate:
        - Word Type: Determined automatically based on the word.
        - Example 1: A sentence using the word.
        - Example 2: Another relevant sentence using the word.
    
3. **Sample Input:**    
    - Word: "meticulous"
    - Meaning: "showing great attention to detail; very careful and precise."
 """
]

ANKI_VOCAB_EXPECTED_OUTPUT = """
Return output in JSON format with the following keys:
    {
      "word": "meticulous",
      "meaning": "showing great attention to detail; very careful and precise.",
      "wordType": "adjective",
      "example1": "She is meticulous in her preparation for the exam.",
      "example2": "His meticulous nature makes him an excellent editor."
    }

Keep the word and meaning exactly as input.
Agent will generate the word type and example sentences.
"""


anki_vocab_suggest_agent = Agent(
    model=OpenAIChat(id="gpt-4o-mini"),
    description=ANKI_VOCAB_DESCRIPTION,
    instructions=ANKI_VOCAB_INSTRUCTIONS,
    expected_output=ANKI_VOCAB_EXPECTED_OUTPUT,
    markdown=True,
)
