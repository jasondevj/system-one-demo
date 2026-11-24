# System One Demo

Companion code for the talk "The Two-Tier AI Stack - Decision and Reasoning" at [SG Agentic Nights: November](https://globalai.community/e/xirlve2e) (Global AI Community Singapore, Tue Nov 24, 2026).

Thesis: System One decides, it doesn't generate. Small decision models answer focused questions (classify, route, rank, gate, choose) in around 100-300 ms, and plain deterministic code acts on the answers. No LLM in the decision loop.

This guide walks you through running the demos on your own machine, no n8n or Docker experience needed. Setup takes about 15 minutes plus one large model download. Deeper reference material - the full file inventory, the System 1 vs System 2 evaluation setups, the demo-day fallback plan - lives in [REPO_DETAILS.md](REPO_DETAILS.md). [DEMO.md](DEMO.md) is the talk's demo-day runbook.

## What you can try

- **Ticket triage, two ways** - the same four support tickets decided by a small System 1 model, then by a general LLM (System 2). The speed contrast is the point.
- **A chat front** - message the triage workflow in an n8n chat window; a System 1 gate screens each message first.
- **The five-questions pipeline** - one webhook where System 1 classifies, routes, ranks, gates and chooses, escalating to System 2 only when it should.
- **Side-by-side scoring** - run both systems over 10 labelled tickets and compare correctness and latency. Optional; see [REPO_DETAILS.md](REPO_DETAILS.md).

## New to n8n?

n8n is a visual workflow tool that runs on your own machine. Each workflow in this repo is a JSON file you import; it appears as a canvas, a diagram of connected steps called nodes. Double-click a node to inspect its settings and its input/output data. **Execute workflow** starts a test run from the canvas. **Publish** (called **Activate** in older versions) makes a webhook or chat workflow listen on its live URL. The CSV files become Data tables, n8n's built-in storage for the comparison inputs and results.

## What you'll need

- **Docker** - runs n8n for you, so there is nothing else to install for it. Docker Desktop on Mac or Windows, Docker Engine on Linux: https://docs.docker.com/get-docker/
- **ollaya** - the System 1 decision service, with the `laya:en` model, on port 11435: https://ollaya.dev
- **Ollama** - runs the System 2 LLM (escalation and comparisons only), on port 11434: https://ollama.com
- **This repo cloned** - `git clone https://github.com/whatevergeek/system-one-demo.git`

Heads-up: the System 2 model is the one heavy download (several GB) - pull it on good wifi.

## 1. Start n8n

In the cloned repo:

```bash
cp .env.example .env
docker compose up -d
```

Open http://localhost:5678 and create your n8n owner account. This is a local login for your own n8n, not an Ollama or ollaya account. Docker runs n8n in a container; the two model services run on your machine itself, and the workflows reach them through `host.docker.internal` (built into Docker Desktop on Mac and Windows; on Linux see [Troubleshooting](#troubleshooting)).

## 2. Install ollaya and get the decision model

ollaya is a small local daemon that serves decision models behind a simple HTTP API. Install it from https://ollaya.dev and make sure the `laya:en` model is available:

```bash
ollaya list
```

The workflows expect ollaya on port `11435` (see ollaya.dev for install and model-pull instructions).

## 3. Install Ollama and pull the System 2 model

Only needed for System 2 escalation and the comparisons - System 1 runs without it. Install Ollama from https://ollama.com, then pull the model for your platform:

```bash
# Apple-Silicon Mac (MLX build, the fast option there):
ollama pull gemma4:12b-mlx

# Windows, Linux or Intel Mac:
ollama pull gemma4:12b
```

Prefer a model you already have (`ollama list`)? Set its name once in the `S2 Config` workflow after importing (step 4); the Ollama System 2 workflows read it from there. OpenAI-compatible workflows use their own `Endpoint Config` node instead.

## 4. Import the workflows

In n8n, create a new workflow, open the **...** menu in the canvas header, choose **Import from File**, and pick the JSON files you want from `workflows/`. Importing loads the diagram and settings; it doesn't run anything.

Import `s2-config.json` first if you'll use the Ollama System 2 workflows: it holds the System 2 model name (default `gemma4:12b-mlx`), and they read it through a Get S2 Model node. To change the model, edit the value in its S2 Model Name node and save - no activation needed, no other workflow edits. If a Get S2 Model node shows an error, open it and pick `S2 Config` from the workflow list. If the lookup fails, the workflows fall back to `gemma4:12b-mlx` (ignoring your override); run one System 2 path and confirm the node's output shows your `model` name.

The OpenAI-compatible variants and `five-questions-chat-demo.json` don't use `S2 Config`; each has its own **Endpoint Config** node (base URL, model, API key if required) to edit instead.

Two publishing notes:

- A webhook or chat workflow only listens while published (**Activate** in older n8n). "Active" below means published and listening, not merely open in the editor.
- The Ollama and OpenAI-compatible terminal five-questions workflows share the `/five-questions` webhook path. Publish only the one you intend to use, not both at once.

Prefer the terminal? A bulk-import command that reloads everything after a `git pull` is in [REPO_DETAILS.md](REPO_DETAILS.md).

## 5. Run your first demo

Open **System 1 (Laya) Ticket Triage** from the Workflows list, hit **Execute workflow** on its canvas, and watch each ticket come back with a team pick, confidence, urgency score, output token count, and latency in milliseconds. Then run **System 2 (Ollama LLM) Ticket Triage** the same way to compare. The first System 2 run can take a few minutes while Ollama loads the model into memory; later runs are much faster.

Double-click a completed node to read its output; the final routing node shows the decision. These two demos carry their own sample tickets, so no chat message or terminal request is needed.

## 6. Try the chat front (optional)

`system1-ticket-triage-chat.json` screens each chat message with a System 1 gate before doing any triage:

- Safe casual message: a short canned conversational reply. No LLM call, no conversation memory - a small chat demo, not a general assistant.
- Support ticket: the usual System 1 triage and routing; a confident decision gets the same team/confidence/urgency/route/latency reply.
- Malicious message: score >= 0.7 gets a polite refusal before triage. Anger or swearing about a legitimate support issue is not malicious by itself; the gate question says so explicitly.
- Uncertain ticket triage: System 1 team confidence < 0.6 escalates to System 2. The reply says System 1 was unsure, then shows both systems' answers and latencies. A failed or malformed System 2 response stays `human_review` instead of inventing a decision.

The intent choice needs confidence >= 0.6 to enter triage; an uncertain intent asks for more detail, an invalid or unavailable gate asks you to retry. Maliciousness takes precedence over intent. These thresholds are demo defaults to play with, not a security boundary. Routes are labels only: nothing is paged or created.

1. Import `workflows/system1-ticket-triage-chat.json` and publish it. Keep only one active copy for this webhook path - re-importing creates a duplicate, so delete or deactivate old copies first.
2. Open http://localhost:5678/webhook/system1-triage-chat/chat and type into the chat page.
3. Try `hello`, then a real ticket such as `I was charged twice for my subscription this month` or `Production server is down, customers cannot log in, revenue impacted`. Check that an angry but legitimate complaint still gets support.

The gate and confident-ticket paths need only ollaya (port 11435). The low-confidence escalation also needs Ollama (port 11434) with the model set in `S2 Config`.

## 7. Try the five-questions pipeline (optional)

`five-questions-demo.json` is the "All five, in one n8n workflow" slide as a single pipeline. One ticket goes in through a webhook. System 1 decides at every stage, in a different way; sticky notes on the canvas name each step; plain code applies policy to what the model decided.

1. CLASSIFY - a choice call picks the team (infra, billing or sales) with a confidence.
2. ROUTE - a noul call scores urgency from 0 to 1. Code routes: >= 0.7 pages on-call, otherwise the team queue.
3. RANK - a score call picks a business-impact level (low, medium or high), mapped to a priority: P1 >= 1.5, P2 >= 0.5, otherwise P3.
4. GATE - a choice call: automate, or a human must handle it (legal threat, security incident, large refund, very upset customer). A human verdict stops the run at `human_review`; an unusable answer fails safe to human.
5. CHOOSE - a choice call: resolve with a help article, hand to the team, or escalate to System 2. Code policy on top: an urgent ticket is never auto-answered, and a CLASSIFY confidence under 0.6 always escalates. If System 2 is also under 0.6 or fails to answer, the verdict is `human_review`.

A normal ticket makes five System 1 calls in a row (each roughly 0.5 s on the demo Mac) and System 2 only when escalated.

Run it:

1. Import `s2-config.json` first (step 4), then `five-questions-demo.json`. The OpenAI-compatible `five-questions-openai-demo.json` uses its own Endpoint Config node instead of `s2-config.json` - and shares the `/five-questions` webhook path, so publish only one of the two. If you imported an earlier version, delete or deactivate it first.
2. Click **Execute workflow** (it then waits for one call on the test URL), or publish the workflow to use the production URL. A webhook is an HTTP address that starts the workflow when it receives a request.
3. Send a ticket from a terminal:

```bash
curl -X POST http://localhost:5678/webhook-test/five-questions \
  -H 'Content-Type: application/json' \
  -d '{"ticket":"Every Tuesday around 2pm our export job fails, but only for customers on the German login page. Rest of the week it works fine."}'
```

   Use `/webhook/five-questions` instead of `/webhook-test/five-questions` when the workflow is published. The test URL listens only during a manual test; click Execute again before each new test request. Leave out `ticket` to use a built-in example.
4. The JSON reply has `final_route`, `decided_by`, a `stages` object with each step's output, `laya_calls`, `laya_total_ms` and `total_ms`. Three terminal verdicts: System 1 decided, human via gate, and System 2 answered - the last can still be `human_review` if System 2 is unsure or unavailable.

To tell the paths apart: four Laya calls with CHOOSE skipped is the gate-human terminal; five calls with a System 1 verdict is System 1 alone; `stages.choose.system_2_usable` distinguishes a usable System 2 answer from its human-review fallback.

[DEMO.md](DEMO.md) (sections 3.1 and 3.2) has three rehearsed paths with exact prompts and PowerShell commands, plus a chat variant of this pipeline (`five-questions-chat-demo.json`).

The thresholds (0.7 urgent, 0.6 confidence, impact bands) are demo values to tune for your own tickets; routes are labels only; the gate is a demo guardrail, not a security boundary. System 1 can be confidently wrong, and a confident answer passes the gate.

## Compare the two systems

Want numbers? Three evaluation setups score System 1 against System 2 over labelled tickets, including the recommended pair of independent runs over the same 10 tickets with side-by-side correctness and latency. They are optional and assume the demos above already run: [REPO_DETAILS.md](REPO_DETAILS.md).

## Troubleshooting

- **The first System 2 run is very slow.** Ollama loads the model into memory on first use and drops it after a few idle minutes. Wait it out (the workflows allow 300 s); later runs are fast.
- **Linux: workflows can't reach ollaya or Ollama.** Add `extra_hosts: ["host.docker.internal:host-gateway"]` to the n8n service in `docker-compose.yml` (or swap in your host's gateway IP). Docker Desktop on Mac and Windows resolves `host.docker.internal` natively.
- **The Evaluations tab asks for a key.** The "Run test" button needs a free registered Community edition (Settings > Usage and plan > Unlock). Only the evaluation setups in [REPO_DETAILS.md](REPO_DETAILS.md) use it; the demos don't.

## Ports

| Service | Port | What it is |
| --- | --- | --- |
| n8n | 5678 | Workflow editor |
| ollaya | 11435 | System One decision API (`/api/decide`) |
| Ollama | 11434 | Local LLM (System Two comparison only) |
