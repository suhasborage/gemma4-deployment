"""
Example 4: Streaming Chat with Gemma 4 E4B
Demonstrates real-time streaming responses for interactive use.
"""
import requests
import json
import sys


OLLAMA_URL = "http://localhost:11434/v1/chat/completions"
MODEL = "gemma4:e4b"


def chat_stream(messages: list, temperature: float = 0.7):
    """Stream a chat response token by token."""
    response = requests.post(
        OLLAMA_URL,
        json={
            "model": MODEL,
            "messages": messages,
            "temperature": temperature,
            "stream": True,
        },
        stream=True,
    )
    response.raise_for_status()

    full_response = ""
    for line in response.iter_lines():
        if line:
            line_str = line.decode("utf-8")
            if line_str.startswith("data: "):
                data_str = line_str[6:]
                if data_str.strip() == "[DONE]":
                    break
                try:
                    chunk = json.loads(data_str)
                    content = chunk["choices"][0]["delta"].get("content", "")
                    if content:
                        print(content, end="", flush=True)
                        full_response += content
                except json.JSONDecodeError:
                    pass

    print()  # newline after streaming
    return full_response


def interactive_chat():
    """Run an interactive chat session with Gemma 4."""
    print("=" * 60)
    print("🧪 Gemma 4 E4B - Interactive Streaming Chat")
    print("=" * 60)
    print("Type 'quit' to exit, 'clear' to reset context")
    print()

    messages = [
        {
            "role": "system",
            "content": "You are a helpful AI assistant running locally via Gemma 4 E4B. Be concise and helpful.",
        }
    ]

    while True:
        try:
            user_input = input("\n👤 You: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n\nGoodbye!")
            break

        if not user_input:
            continue
        if user_input.lower() == "quit":
            print("Goodbye!")
            break
        if user_input.lower() == "clear":
            messages = messages[:1]  # keep system prompt
            print("🔄 Context cleared.")
            continue

        messages.append({"role": "user", "content": user_input})

        print("\n🤖 Gemma: ", end="")
        response = chat_stream(messages)
        messages.append({"role": "assistant", "content": response})


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--demo":
        # Non-interactive demo mode
        print("=" * 60)
        print("🧪 Gemma 4 E4B - Streaming Demo")
        print("=" * 60)

        messages = [
            {"role": "system", "content": "You are a helpful programming assistant."},
            {"role": "user", "content": "Explain the difference between async/await and threads in Python in under 100 words."},
        ]

        print("\n🤖 Gemma: ", end="")
        chat_stream(messages, temperature=0.5)
    else:
        interactive_chat()
