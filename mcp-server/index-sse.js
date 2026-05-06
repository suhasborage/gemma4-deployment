#!/usr/bin/env node
/**
 * Gemma 4 E4B MCP Server — SSE Transport
 *
 * Same tools as index.js (stdio), but exposed over HTTP via Server-Sent Events.
 * Designed to run inside a Docker container alongside Ollama.
 *
 * Endpoints:
 *   GET  /sse     → SSE stream (MCP client connects here)
 *   POST /message → MCP messages from client
 *   GET  /health  → Health check
 *
 * Environment:
 *   OLLAMA_BASE_URL  - Ollama API (default: http://localhost:11434)
 *   GEMMA_MODEL      - Model name (default: gemma4:e4b)
 *   MCP_PORT         - SSE server port (default: 3001)
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import http from "node:http";

const OLLAMA_BASE_URL = process.env.OLLAMA_BASE_URL || "http://localhost:11434";
const MODEL_NAME = process.env.GEMMA_MODEL || "gemma4:e4b";
const MCP_PORT = parseInt(process.env.MCP_PORT || "3001", 10);

// ─── Ollama API helper ───────────────────────────────────────────────
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

// ─── Tool definitions (shared with index.js) ────────────────────────
const TOOLS = [
  {
    name: "gemma4_chat",
    description:
      "Chat with Gemma 4 E4B (local model). Use for general questions, brainstorming, drafting, or getting a second opinion from a different AI model.",
    inputSchema: {
      type: "object",
      properties: {
        prompt: { type: "string", description: "The message or question to send to Gemma 4" },
        system: { type: "string", description: "Optional system prompt to set context/role" },
        temperature: { type: "number", description: "Creativity level 0.0-1.0 (default: 0.7)" },
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
        task: { type: "string", enum: ["generate", "review", "refactor", "explain", "debug"], description: "Type of coding task" },
        code: { type: "string", description: "The code to review/refactor/explain (if applicable)" },
        instruction: { type: "string", description: "What you want Gemma to do with the code" },
        language: { type: "string", description: "Programming language (e.g., python, javascript, rust)" },
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
        text: { type: "string", description: "The text to summarize" },
        style: { type: "string", enum: ["brief", "detailed", "bullet_points", "executive"], description: "Summary style (default: brief)" },
        max_length: { type: "number", description: "Approximate max words for the summary" },
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
        content: { type: "string", description: "The code or text to analyze" },
        focus: {
          type: "string",
          enum: ["architecture", "security", "performance", "readability", "bugs", "general"],
          description: "What aspect to focus the analysis on",
        },
      },
      required: ["content"],
    },
  },
];

// ─── Tool handlers ───────────────────────────────────────────────────
async function handleToolCall(name, args) {
  switch (name) {
    case "gemma4_chat": {
      const messages = [];
      if (args.system) messages.push({ role: "system", content: args.system });
      messages.push({ role: "user", content: args.prompt });
      return callGemma(messages, { temperature: args.temperature ?? 0.7 });
    }

    case "gemma4_code": {
      const systemPrompt = `You are an expert programmer. Task type: ${args.task}. ${
        args.language ? `Language: ${args.language}.` : ""
      } Provide clean, well-commented code with explanations.`;
      const userContent = args.code
        ? `${args.instruction}\n\nCode:\n\`\`\`${args.language || ""}\n${args.code}\n\`\`\``
        : args.instruction;
      return callGemma(
        [{ role: "system", content: systemPrompt }, { role: "user", content: userContent }],
        { temperature: 0.3 }
      );
    }

    case "gemma4_summarize": {
      const style = args.style || "brief";
      const styleInstructions = {
        brief: "Provide a concise 2-3 sentence summary.",
        detailed: "Provide a comprehensive summary covering all key points.",
        bullet_points: "Summarize as a bulleted list of key points.",
        executive: "Provide an executive summary suitable for leadership review.",
      };
      return callGemma(
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
    }

    case "gemma4_analyze": {
      const focus = args.focus || "general";
      const focusPrompts = {
        architecture: "Analyze the architecture and design patterns. Identify strengths and improvement opportunities.",
        security: "Perform a security analysis. Identify vulnerabilities, injection risks, and suggest fixes.",
        performance: "Analyze for performance issues. Identify bottlenecks, memory leaks, and optimization opportunities.",
        readability: "Evaluate code readability and maintainability. Suggest naming, structure, and documentation improvements.",
        bugs: "Look for potential bugs, edge cases, and logical errors. Explain what could go wrong.",
        general: "Provide a general analysis covering structure, quality, and any notable observations.",
      };
      return callGemma(
        [{ role: "system", content: focusPrompts[focus] }, { role: "user", content: args.content }],
        { temperature: 0.4 }
      );
    }

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

// ─── Create MCP Server instance ──────────────────────────────────────
function createMCPServer() {
  const server = new Server(
    { name: "gemma4-local", version: "1.0.0" },
    { capabilities: { tools: {} } }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    try {
      const result = await handleToolCall(name, args);
      return { content: [{ type: "text", text: result }] };
    } catch (error) {
      return {
        content: [{ type: "text", text: `Error calling Gemma 4: ${error.message}` }],
        isError: true,
      };
    }
  });

  return server;
}

// ─── HTTP + SSE Server ───────────────────────────────────────────────
async function main() {
  // Track active transports for cleanup
  const transports = new Map();

  const httpServer = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://localhost:${MCP_PORT}`);

    // CORS headers for all responses
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.writeHead(204);
      res.end();
      return;
    }

    // Health check endpoint
    if (url.pathname === "/health" && req.method === "GET") {
      let ollamaOk = false;
      try {
        const r = await fetch(`${OLLAMA_BASE_URL}/api/tags`);
        ollamaOk = r.ok;
      } catch {}

      const status = ollamaOk ? 200 : 503;
      res.writeHead(status, { "Content-Type": "application/json" });
      res.end(JSON.stringify({
        mcp: "ok",
        ollama: ollamaOk ? "ok" : "unavailable",
        model: MODEL_NAME,
        transport: "sse",
      }));
      return;
    }

    // SSE endpoint — client connects here for the event stream
    if (url.pathname === "/sse" && req.method === "GET") {
      console.error(`[SSE] New client connection from ${req.socket.remoteAddress}`);

      const transport = new SSEServerTransport("/message", res);
      const server = createMCPServer();

      transports.set(transport._sessionId, { transport, server });

      // Clean up on disconnect
      res.on("close", () => {
        console.error(`[SSE] Client disconnected (session: ${transport._sessionId})`);
        transports.delete(transport._sessionId);
        server.close().catch(() => {});
      });

      await server.connect(transport);
      return;
    }

    // Message endpoint — client POSTs MCP messages here
    if (url.pathname === "/message" && req.method === "POST") {
      const sessionId = url.searchParams.get("sessionId");
      const entry = transports.get(sessionId);

      if (!entry) {
        res.writeHead(404, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Session not found. Connect to /sse first." }));
        return;
      }

      await entry.transport.handlePostMessage(req, res);
      return;
    }

    // Root — info page
    if (url.pathname === "/" && req.method === "GET") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({
        name: "gemma4-local MCP Server",
        version: "1.0.0",
        transport: "sse",
        endpoints: {
          sse: "/sse",
          message: "/message",
          health: "/health",
        },
        model: MODEL_NAME,
        ollama: OLLAMA_BASE_URL,
      }));
      return;
    }

    // 404
    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Not found" }));
  });

  httpServer.listen(MCP_PORT, "0.0.0.0", () => {
    console.error(`Gemma 4 MCP Server (SSE) listening on http://0.0.0.0:${MCP_PORT}`);
    console.error(`  SSE endpoint:    http://localhost:${MCP_PORT}/sse`);
    console.error(`  Health check:    http://localhost:${MCP_PORT}/health`);
    console.error(`  Ollama backend:  ${OLLAMA_BASE_URL}`);
    console.error(`  Model:           ${MODEL_NAME}`);
  });

  // Graceful shutdown
  for (const sig of ["SIGINT", "SIGTERM"]) {
    process.on(sig, () => {
      console.error(`\n[SSE] Received ${sig}, shutting down...`);
      for (const { server } of transports.values()) {
        server.close().catch(() => {});
      }
      httpServer.close(() => process.exit(0));
    });
  }
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
