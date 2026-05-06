"""
Example 1: Code Generation with Gemma 4 E4B
Uses the OpenAI-compatible API to generate code.
"""
import requests
import json

OLLAMA_URL = "http://localhost:11434/v1/chat/completions"
MODEL = "gemma4:e4b"


def generate_code(instruction: str, language: str = "python") -> str:
    """Ask Gemma 4 to generate code based on an instruction."""
    response = requests.post(
        OLLAMA_URL,
        json={
            "model": MODEL,
            "messages": [
                {
                    "role": "system",
                    "content": f"You are an expert {language} programmer. Write clean, well-documented code. Only output code with brief comments, no extra explanation.",
                },
                {"role": "user", "content": instruction},
            ],
            "temperature": 0.3,
            "max_tokens": 1024,
        },
    )
    response.raise_for_status()
    return response.json()["choices"][0]["message"]["content"]


if __name__ == "__main__":
    print("=" * 60)
    print("🧪 Gemma 4 E4B - Code Generation Examples")
    print("=" * 60)

    # Example 1: Data structure
    print("\n📝 Task: Implement a thread-safe LRU cache")
    print("-" * 40)
    result = generate_code(
        "Implement a thread-safe LRU cache in Python with get, put, and delete methods. Use typing hints."
    )
    print(result)

    # Example 2: API endpoint
    print("\n\n📝 Task: FastAPI endpoint with validation")
    print("-" * 40)
    result = generate_code(
        "Write a FastAPI POST endpoint /users that creates a user with email validation, password hashing, and returns the created user."
    )
    print(result)

    # Example 3: Shell script
    print("\n\n📝 Task: Backup script")
    print("-" * 40)
    result = generate_code(
        "Write a bash script that backs up a PostgreSQL database with rotation (keep last 7 daily, 4 weekly)",
        language="bash",
    )
    print(result)
