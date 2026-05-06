"""
Example 3: Text Summarization with Gemma 4 E4B
Summarize documents, PRs, and technical content.
"""
import requests

OLLAMA_URL = "http://localhost:11434/v1/chat/completions"
MODEL = "gemma4:e4b"

SAMPLE_TEXT = """
Kubernetes 1.30 introduces several significant changes to container orchestration.
The most notable is the graduation of Pod Scheduling Readiness to stable, which allows
pods to be placed in a scheduling gate that prevents the scheduler from considering them
until all specified conditions are met. This is particularly useful for batch processing
workloads where resources need to be pre-provisioned before scheduling can occur.

Additionally, the release includes improvements to the sidecar container pattern through
native sidecar support. Previously, sidecar containers were implemented as regular containers
with specific restart policies, leading to ordering issues during startup and shutdown.
The new native sidecar support ensures proper lifecycle management, with sidecars starting
before main containers and shutting down after them.

The networking stack has also seen improvements with the graduation of Service Internal
Traffic Policy to GA. This feature allows services to route traffic preferentially to
endpoints on the same node, reducing cross-node traffic and latency. Combined with
topology-aware routing, this enables more efficient network utilization in large clusters.

Memory management improvements include the stabilization of Memory Manager, which provides
NUMA-aware memory allocation for containers. This is critical for high-performance computing
workloads that require predictable memory access patterns and minimal cross-NUMA traffic.
"""


def summarize(text: str, style: str = "brief") -> str:
    """Summarize text in the specified style."""
    style_prompts = {
        "brief": "Summarize in 2-3 sentences. Be concise.",
        "bullet_points": "Summarize as 4-6 bullet points covering the key changes.",
        "executive": "Write an executive summary suitable for a CTO. Focus on business impact.",
        "eli5": "Explain this like I'm a junior developer who just started learning Kubernetes.",
    }

    response = requests.post(
        OLLAMA_URL,
        json={
            "model": MODEL,
            "messages": [
                {"role": "system", "content": style_prompts.get(style, style_prompts["brief"])},
                {"role": "user", "content": f"Summarize:\n\n{text}"},
            ],
            "temperature": 0.3,
            "max_tokens": 512,
        },
    )
    response.raise_for_status()
    return response.json()["choices"][0]["message"]["content"]


if __name__ == "__main__":
    print("=" * 60)
    print("🧪 Gemma 4 E4B - Summarization Examples")
    print("=" * 60)

    for style in ["brief", "bullet_points", "executive", "eli5"]:
        print(f"\n📄 Style: {style}")
        print("-" * 40)
        print(summarize(SAMPLE_TEXT, style))
        print()
