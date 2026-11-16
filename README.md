# System One Demo

Companion code for the talk **"The Two-Tier AI Stack - Decision and Reasoning"** at [SG Agentic Nights: November](https://globalai.community/e/xirlve2e) (Global AI Community Singapore, Tue Nov 24, 2026).

**Thesis: System One decides, it doesn't generate.** Small decision models answer focused questions (classify, route, rank, gate, choose) in around 100-300ms, and plain deterministic code acts on the answers. No LLM in the decision loop.

## What's here

- `workflows/system1-ticket-triage.json` - n8n workflow: four sample support tickets -> ollaya `/api/decide` (urgent? which team?) -> deterministic routing. "Smart-If": the AI perceives, the code decides.
- `workflows/system2-ticket-triage.json` - System Two comparison: same tickets, same routing rule, but a general LLM via Ollama (port 11434) answers. Needs Ollama with a model pulled - default `gemma4:12b-mlx` (Apple Silicon only; see [Fresh machine notes](#fresh-machine-notes) for other platforms), swap it in the **Ollama Generate (System 2)** node. Untested on a live machine yet.
- `workflows/compare-s1-s2-evaluation.json` - standalone comparison workflow (n8n Evaluations): runs every ticket in a Data Table through BOTH systems in the same run and writes side-by-side results back, scoring each system against ground truth (team pick, urgency call, final route). Leaves the two demo workflows untouched.
- `datasets/tickets.csv` - the tickets dataset for the comparison workflow (import it into an n8n Data Table).
- `workflows/system1-ticket-triage-chat.json` - hosted chat with an S1 intent/maliciousness gate: safe casual messages get a short canned reply, tickets go to S1 triage, and low-confidence ticket triage escalates to S2. An extra demo, not a replacement for the first two workflows.
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

Uses n8n's Evaluations feature - free on self-hosted, but the **Run test** button needs a registered Community edition (free, one minute - see [Fresh machine notes](#fresh-machine-notes)).

1. In n8n, open **Data tables**, create a table named `tickets`, and import `datasets/tickets.csv` from this repo.
2. Import `workflows/compare-s1-s2-evaluation.json`, then in BOTH evaluation nodes (**When fetching a dataset row** and **Write Results to Dataset**), select your `tickets` table.
3. With ollaya and Ollama running, open the workflow's **Evaluations** tab and hit **Run test**.
4. Open the Data Table: each row now has `s1_*` and `s2_*` columns side by side (team, confidence, urgency, computed route, latency in ms), per-row flags scoring both systems against the dataset's ground truth (`expected_team` / `expected_urgent` / `expected_route`), and the `agree` flag between systems. Result columns are text so a CSV-imported table accepts them as-is.

### 5. Run the demos

Open **System 1 (Laya) Ticket Triage**, hit **Execute workflow**, and watch each ticket come back with a team pick, confidence, urgency score, output token count, and latency in milliseconds.

### 6. (Optional) Demo through the chat front

`workflows/system1-ticket-triage-chat.json` screens the raw chat message with **Laya Chat Gate** before doing any ticket triage. It uses `laya:en` on ollaya, with an `intent` choice (`support_ticket` vs `casual_chat`) and a `malicious` noul score.

- **Safe casual message:** a short canned conversational reply. No LLM call, no conversation memory. This is a small chat demo, not a general conversational assistant.
- **Support ticket:** the existing S1 triage call and routing rules. A confident decision gets the same team/confidence/urgency/route/latency reply as before.
- **Malicious message:** score >= 0.7 gets a polite refusal before triage. Anger, swearing, criticism or frustration about a legitimate support issue are not malicious by themselves; the gate question says so explicitly.
- **Uncertain ticket triage:** S1 team confidence < 0.6 (`human_review`) calls **Ollama Escalation (System 2)**. The reply says S1 was unsure, shows S1 confidence and triage latency, then S2's team, confidence, urgency, computed route and latency. A failed/malformed S2 response stays `human_review` instead of inventing a decision.

The intent choice needs confidence >= 0.6 to enter ticket triage. An uncertain intent asks for more detail; an invalid/unavailable gate asks the user to retry. Maliciousness takes precedence over intent. These thresholds are demo defaults to test, not a reliable security boundary. Route labels only describe a decision: this workflow does not actually page anyone or create tickets. Casual/refusal replies show gate latency; the existing ticket reply's latency remains the S1 triage call alone, not end-to-end time.

1. Pull the latest repo and import `workflows/system1-ticket-triage-chat.json`. If replacing an older import, deactivate the old chat workflow first, then import the new one and **activate** it. Keep only one active copy for this webhook path. Importing can create a duplicate; an already-imported workflow does not update when you pull.
2. Open http://localhost:5678/webhook/system1-triage-chat/chat in a browser tab. Hosted chat only listens while the workflow is active.
3. Try `hello`, then a real ticket such as `I was charged twice for my subscription this month` or `Production server is down, customers cannot log in, revenue impacted`. Check that an angry but legitimate complaint still gets support. Inspect the gate/triage scores in the execution when testing thresholds and escalation.

The gate and confident-ticket paths need only ollaya on port 11435. The low-confidence escalation also needs Ollama on port 11434 with the model named in **Ollama Escalation (System 2)** (default `gemma4:12b-mlx`, Apple Silicon only; change it to a model installed on that machine - see [Fresh machine notes](#fresh-machine-notes)). The new gate questions and full hosted-chat flow still need a live test on your machine.

The canned responder currently returns only `urgent` and `team`, not the new gate answers. The one-URL canned fallback applies to the original ticket demos, **not this gated chat workflow**.

## Fresh machine notes

- **Ollama + the one heavy download.** The System 2 comparison needs Ollama (https://ollama.com) with a model pulled. On an Apple-Silicon Mac: `ollama pull gemma4:12b-mlx` (MLX build, the fast option there). MLX builds only run on Apple Silicon - on Windows, Linux or an Intel Mac use `ollama pull gemma4:12b` instead, then set that model name in the **Ollama Generate (System 2)** node (and in **Ollama Escalation (System 2)** if you use the chat front). This is the only large download in the whole setup (several GB) - pull it on good wifi before the event, not on venue wifi. Everything else (n8n image, ollaya, the workflows) is small. To use a different model, change it in the **Ollama Generate (System 2)** node.
- **Evaluations "Run test" needs a registered Community edition.** Still free: **Settings > Usage and plan > Unlock**, enter your email, and activate the key from the email n8n sends. Registration is per instance, but the same Community key can be activated up to 5 times (n8n FAQ), so one email covers several machines. Without it the comparison workflow still imports and runs manually - only the **Run test** button asks.
- **host.docker.internal.** The workflows reach ollaya and Ollama on your host through `host.docker.internal`. Docker Desktop on Mac and Windows resolves this natively - nothing to configure. On Linux, add `extra_hosts: ["host.docker.internal:host-gateway"]` to the n8n service in the compose file (or swap in your host's gateway IP).

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
