# System One Demo

Companion code for the talk **"The Two-Tier AI Stack - Decision and Reasoning"** at [SG Agentic Nights: November](https://globalai.community/e/xirlve2e) (Global AI Community Singapore, Tue Nov 24, 2026).

**Thesis: System One decides, it doesn't generate.** Small decision models answer focused questions (classify, route, rank, gate, choose) in around 100-300ms, and plain deterministic code acts on the answers. No LLM in the decision loop.

## What's here

- `workflows/system1-ticket-triage.json` - n8n workflow: four sample support tickets -> ollaya `/api/decide` (urgent? which team?) -> deterministic routing. "Smart-If": the AI perceives, the code decides.
- `workflows/system2-ticket-triage.json` - System Two comparison: same tickets, same routing rule, but a general LLM via Ollama (port 11434) answers. Needs Ollama with a model pulled - default `gemma4:12b-mlx` (Apple Silicon only; see [Fresh machine notes](#fresh-machine-notes) for other platforms). The model name is set in one place, the `S2 Config` workflow. Runs live on the demo Mac with `gemma4:12b-mlx`; a fresh machine still needs a model in Ollama (see [Fresh machine notes](#fresh-machine-notes)).
- `workflows/compare-s1-s2-evaluation.json` - standalone comparison workflow: runs every ticket in a Data Table through BOTH systems in the same canvas run and writes side-by-side results back, scoring each system against ground truth (team pick, urgency call, final route). A `comparison_runs` status table tracks each run so you can tell a finished full run from stale or partial results, under the documented one-operator-at-a-time limits. Leaves the two demo workflows untouched.
- `workflows/compare-s1-s2-metrics-evaluation.json` - the same S1-vs-S2 comparison as scored runs in the Evaluations tab (n8n's newer evaluation panel): per-run S1 and S2 route-correctness scores plus average S1 latency, from the same `tickets` dataset. S1 still calls ollaya over HTTP; S2 runs through a native Ollama chain node (the bootcamp pattern) so the panel accepts the workflow. S2 latency is not measured here - use the plain comparison workflow for timings. See [step 5b](#5b-optional-scored-s1-vs-s2-runs-in-the-evaluations-tab).
- `datasets/tickets.csv` - the tickets dataset for the comparison workflow (import it into an n8n Data Table).
- `workflows/system1-ticket-triage-chat.json` - hosted chat with an S1 intent/maliciousness gate: safe casual messages get a short canned reply, tickets go to S1 triage, and low-confidence ticket triage escalates to S2. An extra demo, not a replacement for the first two workflows.
- `fallback/` - demo-day insurance: canned ollaya responses, a one-field-switch responder workflow, and a recording shot list. See [Fallback plan](#fallback-plan-if-the-live-demo-dies).
- `workflows/s2-config.json` - tiny `S2 Config` workflow: the one place to set the System 2 Ollama model name. Import it first; the four System 2 workflows call it.
- `workflows/five-questions-demo.json` - the talk slide as one workflow: a webhook takes a ticket and System 1 (Laya) decides at each of CLASSIFY, ROUTE, RANK, GATE and CHOOSE in a different way (choice and noul calls), with code applying policy and an escalation to System 2. Sticky notes name each step. See [step 8](#8-optional-the-five-questions-workflow).
- `workflows/system1-choice-poc.json` - minimal question + choices proof of concept against the same endpoint.
- `docker-compose.yml` - slim local n8n stack (just n8n, nothing else).
- `.env.example` - n8n version pin.

## Quickstart (about 5 minutes, plus the one-time model download)

Prerequisites on your machine: **Docker** (Docker Desktop on Mac/Windows), **ollaya** (System 1) and **Ollama** (System 2 and the comparison). Clone this repo first, then:

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

### 3. Install Ollama and pull the System 2 model

Only needed for System 2 and the comparison - System 1 runs without it. Install Ollama from https://ollama.com, then pull the model for your platform:

```bash
# Apple-Silicon Mac (MLX build, the fast option there):
ollama pull gemma4:12b-mlx

# Windows, Linux or Intel Mac:
ollama pull gemma4:12b
```

This is the one heavy download in the whole setup (several GB) - do it on good wifi, not venue wifi. If you pulled `gemma4:12b` or want to use an existing local model (e.g. `mistral:7b` or `llama3.2:latest`), change the model name once in the `S2 Config` workflow (see step 4). All System 2 workflows read it from there and fall back to `gemma4:12b-mlx` if that lookup fails.

### 4. Import the workflows

In n8n: **Workflows -> Import from File**, and pick each JSON from the `workflows/` folder.

Or bulk-import all workflows at once from the terminal (since `docker-compose.yml` mounts `./workflows` at `/data/workflows` inside the container):

```bash
# Import all workflows (or reload after git pull):
docker exec system-one-demo-n8n n8n import:workflow --separate --input=/data/workflows

# Or reload a single workflow file:
docker exec system-one-demo-n8n n8n import:workflow --input=/data/workflows/five-questions-demo.json
```

> **Note on reloading:** All 7 workflow JSON files have fixed `id` fields, so running `n8n import:workflow` via the CLI updates existing workflows **in-place** without creating duplicates. (In the n8n web UI, **Import from File** into a new blank canvas still creates a duplicate copy.)

**Import `s2-config.json` first.** `workflows/s2-config.json` is a tiny workflow named `S2 Config` that holds the System 2 model name (default `gemma4:12b-mlx`). The System 2 triage, the comparison, the chat and the five-questions workflows each call it in a **Get S2 Model** node. To change the model for all of them, edit the value in its **S2 Model Name** node and save; it does not need to be activated. n8n keeps the workflow id on import, so the callers find it. If a **Get S2 Model** node ever shows an error, open that node and pick `S2 Config` from the workflow list. If the call fails, the workflows keep working with `gemma4:12b-mlx` (and ignore your override). To check the link, run one System 2 path and open the **Get S2 Model** node's output: it should show the `model` name.

The System 1 side POSTs to `http://host.docker.internal:11435/api/decide` (ollaya on your host), the System 2 side to `http://host.docker.internal:11434/api/generate` (Ollama on your host).

### 5. (Optional) Run the S1 vs S2 comparison

Runs every ticket in a Data Table through BOTH systems and writes side-by-side results back, scoring each against ground truth. A small status table tells you whether the visible results come from a finished, complete run.

1. In n8n, open **Data tables**, create a table named `tickets`, and import `datasets/tickets.csv` from this repo.
2. Create a second table named `comparison_runs` with text columns: `key`, `status`, `batch`, `expected`, `processed`, `started_at`, `completed_at`.
3. Import `workflows/compare-s1-s2-evaluation.json`. In BOTH evaluation nodes (**When fetching a dataset row** and **Write Results to Dataset**), select your `tickets` table; in **Get Run Status**, **Claim Run** and **Record Progress**, select your `comparison_runs` table. Table ids belong to your n8n instance and can't ship in the JSON, so re-pick them after every re-import.
4. With ollaya and Ollama running, **Execute workflow** on the canvas (full run from the trigger). n8n walks all rows automatically, one execution per row, writing `s1_*` and `s2_*` columns side by side (team, confidence, urgency, computed route, latency in ms) plus per-row flags scoring both systems against the dataset's ground truth (`expected_team` / `expected_urgent` / `expected_route`) and the `agree` flag between systems. Result columns are text so a CSV-imported table accepts them as-is.

**When are the results current?** Check the single row in `comparison_runs`. Your run must be visible from start to finish: it flips the row to `running` with a fresh `started_at` before any ticket is processed, and the `tickets` results are current only once the row shows `complete` with `processed` equal to `expected`. Anything else - you never saw it go `running`, a stuck `running`, or timestamps older than your run - means the visible results are stale or partial.

**Recovery.** If a run failed or was canceled: first stop any active execution of this workflow (Executions list), then set the status cell to `aborted`, then rerun. The stop matters - an old execution that is still going would otherwise keep writing into your new run. A new run refuses to start while a previous one is still marked running.

Operating limits: one operator, one run at a time. Starting a second run while one is in flight errors out before doing any work, but two starts at the exact same instant can still interleave - if you suspect that, do the recovery steps above. Only full canvas runs from the trigger are covered. Running individual nodes cannot write results at all (the write-back node only writes in runs that started from the trigger), and a partial "execute to here" run from the trigger leaves the status row `running` for the recovery steps above. The Evaluations tab's **Run test** does not apply to this workflow (it has no Set Metrics step) - use the workflow in 5b for scored runs.

The four tickets are synthetic examples with hand-picked ground-truth labels - they demonstrate the evaluation mechanics, they are not a general accuracy benchmark. The `comparison_runs` status table only tracks canvas runs of this workflow; scored runs of the 5b workflow live in the Evaluations tab instead.

### 5b. (Optional) Scored S1 vs S2 runs in the Evaluations tab

`compare-s1-s2-metrics-evaluation.json` runs the same comparison through n8n's evaluation panel, so each run gets named, comparable scores in the Evaluations tab rather than table columns: per-case check badges and run averages for both systems, against a fixed labelled dataset - `datasets/tickets-eval-10.csv`, ten synthetic tickets with hand-picked expected routes. S1 keeps calling ollaya over HTTP; only S2 uses the native chain node.

1. Import `workflows/compare-s1-s2-metrics-evaluation.json` and select your `tickets` table in **When fetching a dataset row**.
2. On the **Ollama Chat Model** node, create an Ollama credential. The dialog prefills **Base URL** with `http://localhost:11434` - replace it with `http://host.docker.internal:11434` so the n8n container can reach Ollama on your host. Leave **API Key** blank (it is only needed for Ollama behind an authenticating proxy, such as Open WebUI), then **Save**. Back on the node, select the saved credential in its credential dropdown.
3. In this workflow's own **S2 Config** code node (the one on this canvas - NOT the shared `S2 Config` workflow imported from `s2-config.json`, which this workflow does not call), set the model for this machine (`mistral:7b` on Windows, `gemma4:12b-mlx` on the Mac). The model expression's preview refreshes only when the workflow runs again. If you ever delete and re-add the **Ollama Chat Model** node, the model expression is lost with it - set the new node's model field directly to a model you have pulled instead.
4. Execute the workflow once manually - the panel reads the row shape from a successful non-evaluation run.
5. Open the workflow's **Evaluations** tab, set up tests, and pick **S2 Decide (AI)** as the AI node. Deselect the preselected **Correctness** check (it needs a judge model). Add five custom checks, named and expressed exactly like this (also collected in `datasets/eval-check-expressions.txt` for easy copying):

`s1_route_correct`:

```
={{ $('Collect S1 Result').first().json.s1_route === $('When fetching a dataset row').item.json.expected_route ? 1 : 0 }}
```

`s2_route_correct`:

```
={{ (() => { const raw = String($json.text ?? $json.output ?? '').trim(); let p; try { const c = raw.replace(/```(json)?/gi, ''); const s = c.indexOf('{'); const e = c.lastIndexOf('}'); if (s === -1 || e <= s) return 0; p = JSON.parse(c.slice(s, e + 1)); } catch (err) { return 0; } if (!p || typeof p !== 'object' || Array.isArray(p)) return 0; const team = typeof p.team === 'string' ? p.team.trim() : ''; const prob = (v) => (typeof v === 'number' && Number.isFinite(v) && v >= 0 && v <= 1 ? v : null); const conf = prob(p.confidence); const urg = prob(p.urgent); const route = (!team || conf === null) ? 'no_answer' : (conf < 0.6 ? 'human_review' : (urg >= 0.7 ? 'page_oncall:' + team : 'queue:' + team)); return route === $('When fetching a dataset row').item.json.expected_route ? 1 : 0; })() }}
```

`s1_no_answer`:

```
={{ $('Collect S1 Result').first().json.s1_route === 'no_answer' ? 1 : 0 }}
```

`s2_invalid_output`:

```
={{ (() => { const raw = String($json.text ?? $json.output ?? '').trim(); let p; try { const c = raw.replace(/```(json)?/gi, ''); const s = c.indexOf('{'); const e = c.lastIndexOf('}'); if (s === -1 || e <= s) return 1; p = JSON.parse(c.slice(s, e + 1)); } catch (err) { return 1; } if (!p || typeof p !== 'object' || Array.isArray(p)) return 1; const teamOk = ['infra', 'billing', 'sales'].includes(typeof p.team === 'string' ? p.team.trim() : ''); const probOk = (v) => typeof v === 'number' && Number.isFinite(v) && v >= 0 && v <= 1; return (teamOk && probOk(p.confidence) && probOk(p.urgent)) ? 0 : 1; })() }}
```

`s1_latency_ms`:

```
={{ $('Collect S1 Result').first().json.s1_latency_ms }}
```

6. Add the ten cases. Saving the check suite creates a data table named after this workflow - `Evaluation: System 1 vs System 2 - Ticket Triage (Evaluation + Metrics)` - with one example row in it from the setup wizard. Open that table under **Data tables** and look at its first row:
   - If its ticket is "Production server is down, customers cannot log in, revenue impacted" (row 1 of the dataset), fill its three expected cells (`expected_team` = `infra`, `expected_urgent` = `1`, `expected_route` = `page_oncall:infra`), then use the table's **Import CSV** action with `datasets/tickets-eval-remaining-9.csv`.
   - Otherwise import `datasets/tickets-eval-10.csv` instead, then either label the example row as your own eleventh case or remove it - left unlabelled it scores 0 on the route checks.

   In the import's column review, map `ticket`, `expected_team`, `expected_urgent`, `expected_route`; leave `expectedAnswer` and `caseName` empty.
7. Run. Each case shows a badge per check (expand a case to read the model's raw answer), and the run shows each check's average over the cases.

How the scores work: both route checks apply the same routing policy to their system's answer - confidence below 0.6 routes to `human_review`, urgent at or above 0.7 routes to `page_oncall:<team>`, otherwise `queue:<team>` - and give 1 when the computed route equals the case's `expected_route`, else 0. Only `expected_route` is scored; `expected_team` and `expected_urgent` are not checks in this tab, they document why each expected route is what it is. The two health flags measure different failure shapes per system: `s1_no_answer` is 1 when S1's decision service returned no usable team or confidence at all, while `s2_invalid_output` is 1 when the general model's free-text reply was unparseable JSON, or its team was outside the three options, or its urgent or confidence was not a number between 0 and 1. They are deliberately not the same check - S1's answer arrives structured from ollaya while S2's must be parsed out of prose - and a low-confidence `human_review` can be the correct route even when S2's team field was junk: the flag keeps that visible without changing the route score.

The panel keeps its cases in its own `Evaluation: ...` table - the `tickets` table is only used for the one manual run in step 4. S2 latency cannot be measured in this panel: during an evaluation n8n runs nothing after the AI node, and the chat node does not expose Ollama's timing, so the latency side of the story comes from the plain comparison workflow in step 5. Evaluation runs count toward the instance license's evaluation-workflow allowance. The ten tickets are synthetic with hand-picked labels - they demonstrate the evaluation mechanics, they are not a benchmark. If a case misses, read it as a finding about the model, not a reason to edit the expected answers after the run.

### 6. Run the demos

Open **System 1 (Laya) Ticket Triage**, hit **Execute workflow**, and watch each ticket come back with a team pick, confidence, urgency score, output token count, and latency in milliseconds.

Then run **System 2 (Ollama LLM) Ticket Triage** the same way to compare. The first System 2 run can take a few minutes while Ollama loads the model into memory; later runs are much faster.

### 7. (Optional) Demo through the chat front

`workflows/system1-ticket-triage-chat.json` screens the raw chat message with **Laya Chat Gate** before doing any ticket triage. It uses `laya:en` on ollaya, with an `intent` choice (`support_ticket` vs `casual_chat`) and a `malicious` noul score.

- **Safe casual message:** a short canned conversational reply. No LLM call, no conversation memory. This is a small chat demo, not a general conversational assistant.
- **Support ticket:** the existing S1 triage call and routing rules. A confident decision gets the same team/confidence/urgency/route/latency reply as before.
- **Malicious message:** score >= 0.7 gets a polite refusal before triage. Anger, swearing, criticism or frustration about a legitimate support issue are not malicious by themselves; the gate question says so explicitly.
- **Uncertain ticket triage:** S1 team confidence < 0.6 (`human_review`) calls **Ollama Escalation (System 2)**. The reply says S1 was unsure, shows S1 confidence and triage latency, then S2's team, confidence, urgency, computed route and latency. A failed/malformed S2 response stays `human_review` instead of inventing a decision.

The intent choice needs confidence >= 0.6 to enter ticket triage. An uncertain intent asks for more detail; an invalid/unavailable gate asks the user to retry. Maliciousness takes precedence over intent. These thresholds are demo defaults to test, not a reliable security boundary. Route labels only describe a decision: this workflow does not actually page anyone or create tickets. Casual/refusal replies show gate latency; the existing ticket reply's latency remains the S1 triage call alone, not end-to-end time.

1. Pull the latest repo and import `workflows/system1-ticket-triage-chat.json`. If replacing an older import, deactivate the old chat workflow first, then import the new one and **activate** it. Keep only one active copy for this webhook path. Importing can create a duplicate; an already-imported workflow does not update when you pull.
2. Open http://localhost:5678/webhook/system1-triage-chat/chat in a browser tab. Hosted chat only listens while the workflow is active.
3. Try `hello`, then a real ticket such as `I was charged twice for my subscription this month` or `Production server is down, customers cannot log in, revenue impacted`. Check that an angry but legitimate complaint still gets support. Inspect the gate/triage scores in the execution when testing thresholds and escalation.

The gate and confident-ticket paths need only ollaya on port 11435. The low-confidence escalation also needs Ollama on port 11434 with the model set in the `S2 Config` workflow (default `gemma4:12b-mlx`, Apple Silicon only; change it there to a model installed on your machine - see [Fresh machine notes](#fresh-machine-notes)).

The canned responder currently returns only `urgent` and `team`, not the new gate answers. The one-URL canned fallback applies to the original ticket demos, **not this gated chat workflow**.

### 8. (Optional) The five-questions workflow

`workflows/five-questions-demo.json` is the "All five, in one n8n workflow" slide as a single pipeline. One ticket goes in through a webhook. System 1 (Laya, `laya:en` on ollaya) decides at every stage, in a different way, and sticky notes on the canvas name each step with the slide's words. Plain code only applies policy to what the model decided.

1. **CLASSIFY** - a System 1 *choice* call picks the team (infra, billing or sales) with a confidence.
2. **ROUTE** - a System 1 *noul* call scores urgency from 0 to 1. Then plain code routes: >= 0.7 pages on-call, otherwise the team queue. Once the model decides, routing is just code.
3. **RANK** - a System 1 *noul* call scores business impact. The score becomes a priority: P1 >= 0.8, P2 >= 0.5, otherwise P3. Optionally send `expected_team` and the reply marks the CLASSIFY pick right or wrong. This is a compact score for one ticket, not the Data Table evaluation in step 5.
4. **GATE** - a System 1 *choice* call decides: automate, or a human must handle it (legal threat, security incident, large refund, very upset customer). A human verdict stops the run at `human_review`. An unusable answer fails safe to human.
5. **CHOOSE** - a System 1 *choice* call picks the action: resolve with a help article, hand to the team, or escalate to System 2. Code policy on top: an urgent ticket is never auto-answered, and a CLASSIFY confidence under 0.6 always escalates. Escalation calls System 2 (Ollama, default `gemma4:12b-mlx`). If System 2 is also under 0.6 or fails to answer, the verdict is `human_review`.

A normal ticket makes five System 1 calls in a row (each roughly 0.5 s on the demo Mac) and System 2 only when escalated.

Run it:

1. Import `workflows/s2-config.json` first (see step 4), then `workflows/five-questions-demo.json` (Workflows -> Import from File). If you imported an earlier version, delete or deactivate it first: re-importing creates a duplicate, and an already-imported workflow does not update when you pull.
2. Either click **Execute workflow** (it then waits for one call on the test URL), or **activate** it to use the production URL.
3. Send a ticket from a terminal:

```
curl -X POST http://localhost:5678/webhook-test/five-questions \
  -H 'Content-Type: application/json' \
  -d '{"ticket": "Production server is down, customers cannot log in, revenue impacted", "expected_team": "infra"}'
```

   Use `/webhook/five-questions` instead of `/webhook-test/five-questions` when the workflow is active. Leave out `ticket` to use the double-charge example.
4. The JSON reply has `final_route`, `decided_by`, a `stages` object with the output of each of the five steps (which call type, the scores, that call's latency), `laya_calls`, `laya_total_ms` and `total_ms`. Try a few tickets: an outage (pages on-call), a pricing question (may get a help-article reply), a threat or security-style complaint (the gate sends it to a human), and a vague `hmm` (CLASSIFY confidence is likely under 0.6, so it escalates to System 2).

**Two PowerShell commands, one per path** (pwsh; use `/webhook/` instead of `/webhook-test/` once the workflow is active):

```powershell
# Path 1 - System 1 decides alone (outage: classified infra, paged on-call)
Invoke-RestMethod -Method Post -Uri http://localhost:5678/webhook-test/five-questions -ContentType 'application/json' `
  -Body '{"ticket": "Production server is down, customers cannot log in, revenue impacted", "expected_team": "infra"}' | ConvertTo-Json -Depth 6

# Path 2 - System 1 escalates to System 2 (a vague ticket; CLASSIFY confidence is likely under 0.6)
Invoke-RestMethod -Method Post -Uri http://localhost:5678/webhook-test/five-questions -ContentType 'application/json' `
  -Body '{"ticket": "hmm"}' | ConvertTo-Json -Depth 6
```

Compare `decided_by` and `laya_total_ms` in the two replies: path 1 says System 1 (Laya), path 2 says System 2 (Ollama) and takes seconds longer.

Needs ollaya on port 11435. System 2 only runs on escalation and needs Ollama on port 11434 with the model set in the `S2 Config` workflow (default `gemma4:12b-mlx`; change it there on non-Apple-Silicon machines - see [Fresh machine notes](#fresh-machine-notes)). The CHOOSE branch reads it through its **Get S2 Model** node.

Notes: the thresholds (0.7 urgent, 0.6 confidence, impact bands) are demo values to tune for your own tickets, routes are labels only (nothing is paged, queued or sent), and the gate is a demo guardrail, not a security boundary. S1 can be confidently wrong, and a confident answer passes the gate. Not covered by the canned fallback.

## Fresh machine notes

- **Ollama + the one heavy download.** The System 2 comparison needs Ollama (https://ollama.com) with a model pulled - see step 3 of the Quickstart for the per-platform pull commands. MLX builds only run on Apple Silicon - on Windows, Linux or an Intel Mac pull the standard `gemma4:12b` (or use an existing local model from `ollama list`, such as `mistral:7b`) and change the model name once in the `S2 Config` workflow (open it in n8n, edit the value in **S2 Model Name**, save). All four System 2 workflows read it from there, so no other workflow edits are needed and no environment variables or n8n settings are involved. Everything else (n8n image, ollaya, the workflows) is small.
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
