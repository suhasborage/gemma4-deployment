#!/usr/bin/env node
/**
 * Gemma 4 E4B MCP Server
 *
 * Exposes Gemma 4 (running via Ollama) as tools callable from Claude CLI and Desktop.
 * Tools provided:
 *   - gemma4_chat: General chat/completion with Gemma 4
 *   - gemma4_code: Code generation and review
 *   - gemma4_summarize: Text summarization
 *   - gemma4_analyze: Code/text analysis
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const OLLAMA_BASE_URL = process.env.OLLAMA_BASE_URL || "http://localhost:11434";
const MODEL_NAME = process.env.GEMMA_MODEL || "gemma4:e4b";

// Helper to call Ollama's OpenAI-compatible API
async function callGemma(messages, options = {}) {
  const response = await fetch(`${OLLAMA_BASE_URL}/v1/chat/completions`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: MODEL_NAME,
      messages,
      temperature: options.temperature ?? 0.7,
      max_tokens: options.max_tokens ?? 2048,
      ...options,
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Ollama API error (${response.status}): ${err}`);
  }

  const data = await response.json();
  return data.choices[0].message.content;
}

// Create MCP Server
const server = new Server(
  { name: "gemma4-local", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

// Define available tools
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "gemma4_chat",
      description:
        "Chat with Gemma 4 E4B (local model). Use for general questions, brainstorming, drafting, or getting a second opinion from a different AI model.",
      inputSchema: {
        type: "object",
        properties: {
          prompt: {
            type: "string",
            description: "The message or question to send to Gemma 4",
          },
          system: {
            type: "string",
            description: "Optional system prompt to set context/role",
          },
          temperature: {
            type: "number",
            description: "Creativity level 0.0-1.0 (default: 0.7)",
          },
        },
        required: ["prompt"],
      },
    },
    {
      name: "gemma4_code",
      description:
        "Use Gemma 4 for code generation, review, refactoring, or explanation. Optimized for programming tasks.",
      inputSchema: {
        type: "object",
        properties: {
          task: {
            type: "string",
            enum: ["generate", "review", "refactor", "explain", "debug"],
            description: "Type of coding task",
          },
          code: {
            type: "string",
            description: "The code to review/refactor/explain (if applicable)",
          },
          instruction: {
            type: "string",
            description: "What you want Gemma to do with the code",
          },
          language: {
            type: "string",
            description: "Programming language (e.g., python, javascript, rust)",
          },
        },
        required: ["task", "instruction"],
      },
    },
    {
      name: "gemma4_summarize",
      description:
        "Summarize text, documents, or code using Gemma 4. Good for getting concise overviews.",
      inputSchema: {
        type: "object",
        properties: {
          text: {
            type: "string",
            description: "The text to summarize",
          },
          style: {
            type: "string",
            enum: ["brief", "detailed", "bullet_points", "executive"],
            description: "Summary style (default: brief)",
          },
          max_length: {
            type: "number",
            description: "Approximate max words for the summary",
          },
        },
        required: ["text"],
      },
    },
    {
      name: "gemma4_analyze",
      description:
        "Analyze code architecture, patterns, potential issues, or text for insights using Gemma 4.",
      inputSchema: {
        type: "object",
        properties: {
          content: {
            type: "string",
            description: "The code or text to analyze",
          },
          focus: {
            type: "string",
            enum: [
              "architecture",
              "security",
              "performance",
              "readability",
              "bugs",
              "general",
            ],
            description: "What aspect to focus the analysis on",
          },
        },
        required: ["content"],
      },
    },
  ],
}));

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    let result;

    switch (name) {
      case "gemma4_chat": {
        const messages = [];
        if (args.system) {
          messages.push({ role: "system", content: args.system });
        }
        messages.push({ role: "user", content: args.prompt });
        result = await callGemma(messages, {
          temperature: args.temperature ?? 0.7,
        });
        break;
      }

      case "gemma4_code": {
        const systemPrompt = `You are an expert programmer. Task type: ${args.task}. ${
          args.language ? `Language: ${args.language}.` : ""
        } Provide clean, well-commented code with explanations.`;

        const userContent = args.code
          ? `${args.instruction}\n\nCode:\n\`\`\`${args.language || ""}\n${args.code}\n\`\`\``
          : args.instruction;

        result = await callGemma(
          [
            { role: "system", content: systemPrompt },
            { role: "user", content: userContent },
          ],
          { temperature: 0.3 }
        );
        break;
      }

      case "gemma4_summarize": {
        const style = args.style || "brief";
        const styleInstructions = {
          brief: "Provide a concise 2-3 sentence summary.",
          detailed: "Provide a comprehensive summary covering all key points.",
          bullet_points: "Summarize as a bulleted list of key points.",
          executive:
            "Provide an executive summary suitable for leadership review.",
        };

        result = await callGemma(
          [
            {
              role: "system",
              content: `You are a summarization expert. ${styleInstructions[style]}${
                args.max_length ? ` Keep it under ${args.max_length} words.` : ""
              }`,
            },
            { role: "user", content: `Summarize this:\n\n${args.text}` },
          ],
          { temperature: 0.3 }
        );
        break;
      }

      case "gemma4_analyze": {
        const focus = args.focus || "general";
        const focusPrompts = {
          architecture:
            "Analyze the architecture and design patterns. Identify strengths and improvement opportunities.",
          security:
            "Perform a security analysis. Identify vulnerabilities, injection risks, and suggest fixes.",
          performance:
            "Analyze for performance issues. Identify bottlenecks, memory leaks, and optimization opportunities.",
          readability:
            "Evaluate code readability and maintainability. Suggest naming, structure, and documentation improvements.",
          bugs:
            "Look for potential bugs, edge cases, and logical errors. Explain what could go wrong.",
          general:
            "Provide a general analysis covering structure, quality, and any notable observations.",
        };

        result = await callGemma(
          [
            { role: "system", content: focusPrompts[focus] },
            { role: "user", content: args.content },
          ],
          { temperature: 0.4 }
        );
        break;
      }

      default:
        return {
          content: [{ type: "text", text: `Unknown tool: ${name}` }],
          isError: true,
        };
    }

    return {
      content: [{ type: "text", text: result }],
    };
  } catch (error) {
    return {
      content: [
        {
          type: "text",
          text: `Error calling Gemma 4: ${error.message}\n\nMake sure Ollama is running: ./scripts/start.sh`,
        },
      ],
      isError: true,
    };
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Gemma 4 MCP Server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
