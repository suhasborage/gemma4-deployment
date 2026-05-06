"""
Example 2: Code Review with Gemma 4 E4B
Submit code for review and get actionable feedback.
"""
import requests
import json

OLLAMA_URL = "http://localhost:11434/v1/chat/completions"
MODEL = "gemma4:e4b"

SAMPLE_CODE = '''
import sqlite3
import os

def get_user(username):
    conn = sqlite3.connect('users.db')
    cursor = conn.cursor()
    query = f"SELECT * FROM users WHERE username = '{username}'"
    cursor.execute(query)
    result = cursor.fetchone()
    conn.close()
    return result

def save_file(filename, content):
    path = "/uploads/" + filename
    with open(path, 'w') as f:
        f.write(content)
    return path

def process_payment(card_number, amount):
    print(f"Processing payment of ${amount} on card {card_number}")
    # TODO: implement actual payment
    return True
'''


def review_code(code: str, focus: str = "security") -> str:
    """Ask Gemma 4 to review code with a specific focus."""
    response = requests.post(
        OLLAMA_URL,
        json={
            "model": MODEL,
            "messages": [
                {
                    "role": "system",
                    "content": f"You are a senior software engineer conducting a code review. Focus on: {focus}. Be specific about issues, cite line numbers, and suggest fixes.",
                },
                {
                    "role": "user",
                    "content": f"Review this code:\n\n```python\n{code}\n```",
                },
            ],
            "temperature": 0.3,
            "max_tokens": 2048,
        },
    )
    response.raise_for_status()
    return response.json()["choices"][0]["message"]["content"]


if __name__ == "__main__":
    print("=" * 60)
    print("🧪 Gemma 4 E4B - Code Review Examples")
    print("=" * 60)

    # Security review
    print("\n🔒 Security Review:")
    print("-" * 40)
    result = review_code(SAMPLE_CODE, focus="security vulnerabilities, SQL injection, path traversal, data exposure")
    print(result)

    # Performance review
    print("\n\n⚡ Performance Review:")
    print("-" * 40)
    result = review_code(SAMPLE_CODE, focus="performance, resource management, connection pooling")
    print(result)
