# System One Demo

Companion code for the talk **"The Two-Tier AI Stack - Decision and Reasoning"** at [SG Agentic Nights: November](https://globalai.community/e/xirlve2e) (Global AI Community Singapore, Tue Nov 24, 2026).

**Thesis: System One decides, it doesn't generate.** Small decision models answer focused questions (classify, route, rank, gate, choose) in around 100-300ms, and plain deterministic code acts on the answers. No LLM in the decision loop.

## What's here

- `workflows/system1-ticket-triage.json` - n8n workflow: four sample support tickets -> ollaya `/api/decide` (urgent? which team?) -> deterministic routing. "Smart-If": the AI perceives, the code decides.
- `workflows/system2-ticket-triage.json` - System Two comparison: same tickets, same routing rule, but a general LLM via Ollama (port 11434) answers. Needs an installed Ollama model - default `gemma4:12b-mlx` (confirmed installed), swap it in the **Ollama Generate (System 2)** node. Untested on a live machine yet.
- `workflows/compare-s1-s2-evaluation.json` - standalone comparison workflow (n8n Evaluations): runs every ticket in a Data Table through BOTH systems in the same run and writes side-by-side results back. Leaves the two demo workflows untouched.
- `datasets/tickets.csv` - the tickets dataset for the comparison workflow (import it into an n8n Data Table).
- `workflows/system1-ticket-triage-chat.json` - the same S1 triage engine with a chat front (n8n hosted chat): a ticket arrives as a chat message, the decision posts back as the reply. An extra option for the live demo, not a replacement.
- `fallback/` - demo-day insurance: canned ollaya responses, a one-field-switch responder workflow, and a recording shot list. See [Fallback plan](#fallback-plan-if-the-live-demo-dies).
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

The System 1 side POSTs to `http://host.docker.internal:11435/api/decide` (ollaya on your host), the System 2 side to `http://host.docker.internal:11434/api/generate` (Ollama on your host).

### 4. (Optional) Run the S1 vs S2 comparison

Uses n8n's Evaluations feature - free on self-hosted community.

1. In n8n, open **Data tables**, create a table named `tickets`, and import `datasets/tickets.csv` from this repo.
2. Import `workflows/compare-s1-s2-evaluation.json`, then in BOTH evaluation nodes (**When fetching a dataset row** and **Write Results to Dataset**), select your `tickets` table.
3. With ollaya and Ollama running, open the workflow's **Evaluations** tab and hit **Run test**.
4. Open the Data Table: each row now has `s1_*` and `s2_*` columns side by side (team, confidence, urgency, latency in ms), plus `agree` and per-system `correct` flags against `expected_team`. Result columns are text so a CSV-imported table accepts them as-is.

### 5. Run the demos

Open **System 1 (Laya) Ticket Triage**, hit **Execute workflow**, and watch each ticket come back with a team pick, confidence, urgency score, output token count, and latency in milliseconds.

### 6. (Optional) Demo through the chat front

`workflows/system1-ticket-triage-chat.json` runs the identical ollaya call and routing rules, but the audience watches a chat: a ticket arrives as a chat message, the workflow runs, and the decision (team, confidence, urgency, route, latency) posts back as the reply.

1. Import `workflows/system1-ticket-triage-chat.json` and **activate** it - the hosted chat only listens while the workflow is active.
2. Open http://localhost:5678/webhook/system1-triage-chat/chat in a browser tab (the Chat Trigger node is in hosted-chat mode; the four demo tickets are pre-filled in its opening message).
3. Paste a ticket, send, and the routing decision appears in the chat a beat later.

Good on a big screen for "tickets arriving as messages" discussion. The canned fallback works here too: point the same one URL field at the canned responder (see `fallback/README.md`).

## Fallback plan (if the live demo dies)

Two independent safety nets in `fallback/`:

- **Canned path (stays interactive):** import `fallback/canned-ollaya-responder.json`, activate it, and change ONE field - point the demo's **Laya Decide** URL from ollaya to `http://host.docker.internal:5678/webhook/canned-ollaya`. Same workflow, same logic, static answers with realistic latencies.
- **Recording:** `fallback/recording-shot-list.md` is a shot-by-shot capture script (screens, order, what to say per shot). Record the backup video in about 15 minutes.
- `fallback/capture-canned.sh` regenerates the canned responses from a healthy live ollaya in one command - run it before the talk so the cans are real captures.

## Ports

| Service | Port | What it is |
| --- | --- | --- |
| n8n | 5678 | Workflow editor |
| ollaya | 11435 | System One decision API (`/api/decide`) |
| Ollama | 11434 | Local LLM (System Two comparison only) |

## Still being added (talk prep in progress)

- [ ] Fallback recording captured (shot list ready in `fallback/recording-shot-list.md`) and canned responses regenerated from live ollaya (`fallback/capture-canned.sh`)
- [ ] Measured latency table: System One vs System Two on the same ticket
