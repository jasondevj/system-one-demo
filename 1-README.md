# System One Demo

Companion code for the talk **"The Two-Tier AI Stack - Decision and Reasoning"** at [SG Agentic Nights: November](https://globalai.community/e/xirlve2e) (Global AI Community Singapore, Tue Nov 24, 2026).

**Thesis: System One decides, it doesn't generate.** Small decision models answer focused questions (classify, route, rank, gate, choose) in around 100-300ms, and plain deterministic code acts on the answers. No LLM in the decision loop.

## What's here

- `workflows/system1-ticket-triage.json` - n8n workflow: four sample support tickets -> ollaya `/api/decide` (urgent? which team?) -> deterministic routing. "Smart-If": the AI perceives, the code decides.
- `workflows/system1-choice-poc.json` - minimal question + choices proof of concept against the same endpoint.
- `docker-compose.yml` - slim local n8n stack (just n8n, nothing else).
- `.env.example` - n8n version pin.

## Quickstart (about 5 minutes)

### 1. Start n8n

```bash
cp .env.example .env
docker compose up -d
```

Open http://localhost:5678 and create your n8n owner account.

### 2. Install ollaya and get the decision model

ollaya is a local daemon that serves small decision models behind a simple HTTP API. Install it from https://ollaya.dev and make sure the `laya:en` model is available:

```bash
ollaya list
```

The workflows expect the ollaya daemon reachable on port `11435` (see ollaya.dev for install and model-pull instructions).

### 3. Import the workflows

In n8n: **Workflows -> Import from File**, and pick each JSON from the `workflows/` folder. (The compose file also mounts that folder read-only at `/data/workflows` inside the container.)

Both workflows POST to `http://host.docker.internal:11435/api/decide`, which reaches ollaya running on your host machine.

### 4. Run it

Open **System 1 (Laya) Ticket Triage**, hit **Execute workflow**, and watch each ticket come back with a team pick, confidence, urgency score, output token count, and latency in milliseconds.

## Ports

| Service | Port | What it is |
| --- | --- | --- |
| n8n | 5678 | Workflow editor |
| ollaya | 11435 | System One decision API (`/api/decide`) |
| Ollama | 11434 | Local LLM (System Two comparison only) |

## Still being added (talk prep in progress)

- [ ] **System Two variant** of the ticket triage: same tickets, same routing rule, answered by a local LLM via Ollama - for the live latency comparison
- [ ] Canned ollaya JSON responses and a fallback recording, in case the demo gods frown
- [ ] Measured latency table: System One vs System Two on the same ticket
