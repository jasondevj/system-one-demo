# System One Demo

Companion code for the talk "The Two-Tier AI Stack - Decision and Reasoning" at [SG Agentic Nights: November](https://globalai.community/e/xirlve2e) (Global AI Community Singapore, Tue Nov 24, 2026).

Thesis: System One decides, it doesn't generate. Small decision models answer focused questions (classify, route, rank, gate, choose) in around 100-300 ms, and plain deterministic code acts on the answers. No LLM in the decision loop.

n8n is a visual workflow tool: import this repo's JSON files as workflows, then open each workflow's canvas (the diagram of connected steps) to run it. Each box is a node; double-click a node to inspect its settings and input/output data. The CSV files become Data tables, n8n's built-in storage for the comparison inputs and results.

This README is the reference: what each file is and how to set everything up. The demo-day runbook (checklist, warmup, run order, verified commands) is [DEMO.md](DEMO.md).

## What's here

Workflows (in `workflows/`):

- `system1-ticket-triage.json` - System 1 triage: four sample support tickets -> ollaya `/api/decide` (urgent? which team?) -> deterministic routing.
- `system2-ticket-triage.json` - System 2 triage: the same tickets and routing rule, answered by a general LLM via Ollama (port 11434). The model name comes from the `S2 Config` workflow.
- `system2-openai-ticket-triage.json` - OpenAI-compatible variant of the System 2 triage.
- `system1-ticket-triage-chat.json` - chat front: an S1 gate screens each message (casual chat, ticket or abusive) before triage; low-confidence tickets escalate to System 2. See step 7.
- `five-questions-demo.json` - the five-questions slide as one webhook pipeline: System 1 decides at CLASSIFY, ROUTE, RANK, GATE and CHOOSE, code applies policy, with escalation to System 2. See step 8.
- `five-questions-openai-demo.json` - OpenAI-compatible S2 variant of the five-questions pipeline.
- `five-questions-chat-demo.json` - the five-questions pipeline behind an n8n chat window instead of the terminal.
- `s2-config.json` - tiny `S2 Config` workflow holding the System 2 model name. The Ollama System 2 workflows call it; the OpenAI-compatible variants and five-questions chat workflow use their own `Endpoint Config` node. See step 4.
- `compare-s1-s2-evaluation.json` - runs every ticket in a Data Table through both systems in one canvas run and writes side-by-side scored results back. See step 5.
- `compare-s1-s2-metrics-evaluation.json` - the S1 vs S2 comparison as scored runs in n8n's Evaluations tab. See step 5b.
- `eval-s1-tickets-10.json` / `eval-s2-tickets-10.json` - the recommended comparison: two independent runs over the same 10 labelled tickets, results side by side in one table. See step 5c.
- `eval-s2-openai-tickets-10.json` - OpenAI-compatible variant of the System 2 eval.
- `system1-choice-poc.json` - minimal question + choices proof of concept against the ollaya endpoint.

Data and other files:

- `datasets/tickets.csv` - 4-ticket dataset for step 5 (import into a Data Table).
- `datasets/tickets-eval-10.csv` and `datasets/tickets-eval-remaining-9.csv` - the 10-ticket labelled dataset for steps 5b/5c.
- `datasets/comparison_runs.csv` - header-only starter for the `comparison runs` run-status table.
- `datasets/eval-check-expressions.txt` - the five evaluation check expressions for step 5b, for easy copying.
- `fallback/` - demo-day insurance: canned ollaya responses, a responder workflow, a capture script and a recording shot list. See [Fallback plan](#fallback-plan-if-the-live-demo-dies).
- `docker-compose.yml` - slim local n8n stack. `.env.example` - n8n version pin.

## Prerequisites

- Docker (Docker Desktop on Mac/Windows)
- ollaya (System 1) from https://ollaya.dev, with the `laya:en` model, on port 11435
- Ollama (System 2 and the comparisons) from https://ollama.com, on port 11434
- This repo cloned

The System 2 model is the one heavy download (several GB) - pull it on good wifi, not venue wifi.

## Setup

### 1. Start n8n

```bash
cp .env.example .env
docker compose up -d
```

Open http://localhost:5678 and create your n8n owner account. This is your local n8n login, not an Ollama or ollaya account; Docker runs n8n, while the two model services run on your host machine.

### 2. Install ollaya and get the decision model

ollaya is a local daemon that serves small decision models behind a simple HTTP API. Install it from https://ollaya.dev and make sure the `laya:en` model is available:

```bash
ollaya list
```

The workflows expect the ollaya daemon on port `11435` (see ollaya.dev for install and model-pull instructions).

### 3. Install Ollama and pull the System 2 model

Only needed for System 2 and the comparisons - System 1 runs without it. Install Ollama from https://ollama.com, then pull the model for your platform:

```bash
# Apple-Silicon Mac (MLX build, the fast option there):
ollama pull gemma4:12b-mlx

# Windows, Linux or Intel Mac:
ollama pull gemma4:12b
```

To use a different local Ollama model (e.g. `mistral:7b` from `ollama list`), change the model name once in the `S2 Config` workflow (step 4); the Ollama System 2 workflows read it from there. OpenAI-compatible workflows use their own `Endpoint Config` node.

### 4. Import the workflows

In n8n, create a new workflow, open the **...** menu in the canvas header, choose **Import from File**, and pick the JSON files you intend to use from `workflows/`. For workflows that call the shared Ollama model, import `s2-config.json` first. Importing loads the diagram and settings, it does not run the workflow.

Open an imported workflow from the Workflows list. Double-click a node to edit its settings; return to the canvas when done. **Execute workflow** starts a manual test run. For webhook/chat workflows, **Publish** makes their production URLs live (older n8n versions call this **Activate**); "active" below means published and listening, not merely open in the editor. The Ollama and OpenAI-compatible terminal five-questions workflows have different workflow IDs but share `/five-questions`; publish only the intended terminal variant, not both at once.

Or bulk-import from the terminal (`docker-compose.yml` mounts `./workflows` at `/data/workflows` in the container):

```bash
# Import all workflows (or reload after git pull):
docker exec system-one-demo-n8n n8n import:workflow --separate --input=/data/workflows

# Or reload a single workflow file:
docker exec system-one-demo-n8n n8n import:workflow --input=/data/workflows/five-questions-demo.json
```

All workflow JSON files have fixed `id` fields, so a CLI import updates existing workflows in place. (In the web UI, Import from File into a new blank canvas creates a duplicate - delete old copies first.)

Import `s2-config.json` before the Ollama System 2 workflows. It holds the System 2 model name (default `gemma4:12b-mlx`); the Ollama System 2 triage, comparison, chat and original five-questions workflows read it in a Get S2 Model node. OpenAI-compatible workflows and `five-questions-chat-demo.json` instead use their own `Endpoint Config` node. To change the model, edit the value in its S2 Model Name node and save - it does not need to be activated, and no other workflow edits are needed. If a Get S2 Model node shows an error, open it and pick `S2 Config` from the workflow list. If the lookup fails, the workflows fall back to `gemma4:12b-mlx` (ignoring your override); to check the link, run one System 2 path and confirm the node's output shows your `model` name.

The workflows reach ollaya and Ollama on your host through `host.docker.internal` (ports 11435 and 11434). Docker Desktop on Mac and Windows resolves this natively; on Linux see [Fresh machine notes](#fresh-machine-notes).

## Compare System 1 and System 2 (optional)

Three setups, in order of preference: 5c is the recommended comparison; 5 and 5b are older alternatives kept for reference (5 is the manual same-ticket flow, 5b is the Evaluations-tab variant). For a first run, go straight to step 6 after setup; return here when both triage demos work.

For these comparisons, open **Data tables** from n8n's project/Overview area, create a table, and use **Import CSV** to load the named file. To select a table in a workflow, double-click the named node and use its Data table field.

All three use small synthetic datasets with hand-picked expected labels - they demonstrate the evaluation mechanics, they are not accuracy benchmarks.

### 5. (Optional) Run the S1 vs S2 comparison

`compare-s1-s2-evaluation.json` runs every ticket in a Data Table through both systems in the same canvas run and writes side-by-side results back, scoring each against ground truth (team pick, urgency call, final route). A small status table tells you whether the visible results come from a finished run. The two demo workflows are untouched.

1. In n8n, open Data tables, create a table named `tickets`, and import `datasets/tickets.csv`.
2. Create a second table named `comparison_runs` with text columns: `key`, `status`, `batch`, `expected`, `processed`, `started_at`, `completed_at`.
3. Import `workflows/compare-s1-s2-evaluation.json`. In both evaluation nodes (When fetching a dataset row and Write Results to Dataset), select your `tickets` table; in Get Run Status, Claim Run and Record Progress, select your `comparison_runs` table. Table ids belong to your n8n instance and can't ship in the JSON, so re-pick them after every re-import.
4. With ollaya and Ollama running, Execute workflow on the canvas (full run from the trigger). n8n walks all rows, one execution per row, writing `s1_*` and `s2_*` columns side by side (team, confidence, urgency, computed route, latency in ms) plus per-row flags scoring both systems against the dataset's `expected_*` ground truth and the `agree` flag between systems. Result columns are text so a CSV-imported table accepts them as-is.

When are the results current? Check the single row in `comparison_runs`: your run flips it to `running` with a fresh `started_at` before any ticket is processed, and the `tickets` results are current only once the row shows `complete` with `processed` equal to `expected`. Anything else (never went `running`, stuck `running`, old timestamps) means the visible results are stale or partial.

Recovery: stop any active execution of this workflow (Executions list), set the status cell to `aborted`, then rerun. The stop matters - an old execution still going would keep writing into your new run. A new run refuses to start while a previous one is still marked running.

Operating limits: one operator, one run at a time; two starts at the exact same instant can interleave - if you suspect that, do the recovery steps. Only full canvas runs from the trigger are covered: running individual nodes writes nothing (the write-back node only writes in trigger-started runs), and a partial "execute to here" run leaves the status row `running`. The Evaluations tab's Run test does not apply here (no Set Metrics step) - use step 5b for scored runs.

### 5b. (Optional) Scored S1 vs S2 runs in the Evaluations tab

`compare-s1-s2-metrics-evaluation.json` runs the same comparison through n8n's evaluation panel, so each run gets named, comparable scores in the Evaluations tab: per-case check badges and run averages for both systems against `datasets/tickets-eval-10.csv` (ten synthetic tickets with hand-picked expected routes). S1 keeps calling ollaya over HTTP; S2 uses a native Ollama chain node, because the panel requires an AI (langchain) node as the tested endpoint. S2 latency cannot be measured here - during an evaluation n8n runs nothing after the AI node, and the chat node does not expose Ollama's timing - so use step 5 or 5c for timings. Evaluation runs count toward the instance license's evaluation-workflow allowance.

1. Import `workflows/compare-s1-s2-metrics-evaluation.json`. Under Data tables, create a table named `tickets_eval10` from `datasets/tickets-eval-10.csv` (Import CSV), then select it in When fetching a dataset row.
2. On the Ollama Chat Model node, create an Ollama credential: replace the prefilled Base URL `http://localhost:11434` with `http://host.docker.internal:11434` so the n8n container can reach Ollama on your host, leave API Key blank (only needed for Ollama behind an authenticating proxy, such as Open WebUI), Save, then select the saved credential on the node.
3. In this workflow's own S2 Config code node (the one on this canvas - not the shared `S2 Config` workflow, which this workflow does not call), set the model for this machine. The model expression's preview refreshes only when the workflow runs again. If you ever delete and re-add the Ollama Chat Model node, the model expression is lost with it - set the new node's model field directly to a model you have pulled.
4. Execute the workflow once manually - the panel reads the row shape from a successful non-evaluation run.
5. Open the workflow's Evaluations tab, set up tests, and pick S2 Decide (AI) as the AI node. Deselect the preselected Correctness check (it needs a judge model). Add five custom checks, named and expressed exactly like this (also collected in `datasets/eval-check-expressions.txt` for easy copying):

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

6. Add the ten cases. Saving the check suite creates a data table named after this workflow - `Evaluation: System 1 vs System 2 - Ticket Triage (Evaluation + Metrics)` - with one example row in it from the setup wizard. Open that table under Data tables and look at its first row:
   - If its ticket is "Production server is down, customers cannot log in, revenue impacted" (row 1 of the dataset), fill its three expected cells (`expected_team` = `infra`, `expected_urgent` = `1`, `expected_route` = `page_oncall:infra`), then use the table's Import CSV action with `datasets/tickets-eval-remaining-9.csv`.
   - Otherwise - including when it holds a leftover row from the old `tickets` table - import `datasets/tickets-eval-10.csv` instead, then either label the example row as your own eleventh case or remove it; left unlabelled it scores 0 on the route checks.

   In the import's column review, map `ticket`, `expected_team`, `expected_urgent`, `expected_route`; leave `expectedAnswer` and `caseName` empty.
7. Run. Each case shows a badge per check (expand a case to read the model's raw answer), and the run shows each check's average over the cases.

How the scores work: both route checks apply the same routing policy to their system's answer - confidence below 0.6 routes to `human_review`, urgent at or above 0.7 routes to `page_oncall:<team>`, otherwise `queue:<team>` - and give 1 when the computed route equals the case's `expected_route`, else 0. Only `expected_route` is scored; `expected_team` and `expected_urgent` are not checks, they document why each expected route is what it is. The two health flags measure different failure shapes per system: `s1_no_answer` is 1 when S1's decision service returned no usable team or confidence at all, while `s2_invalid_output` is 1 when the general model's free-text reply was unparseable JSON, its team was outside the three options, or its urgent or confidence was not a number between 0 and 1. They are deliberately not the same check - S1's answer arrives structured from ollaya while S2's must be parsed out of prose - and a low-confidence `human_review` can be the correct route even when S2's team field was junk: the flag keeps that visible without changing the route score. The panel keeps its cases in its own `Evaluation: ...` table; the `tickets_eval10` table only feeds manual canvas runs. If a case misses, read it as a finding about the model, not a reason to edit the expected answers after the run.

### 5c. (Recommended) Separate S1 and S2 runs over the same 10 tickets

`eval-s1-tickets-10.json` and `eval-s2-tickets-10.json` are the fair-comparison pair: two independent workflows, the same 10 labelled tickets (`datasets/tickets-eval-10.csv`), the same expected answers, the same routing policy, and latency measured the same way on both sides. Neither system runs inside the other's test.

Setup (one time):

1. Import both workflows. If you have not yet, import `datasets/tickets-eval-10.csv` into a Data table - the importer names it `tickets eval 10` (separators become spaces), and the run-state nodes look it up by exactly that name.
2. Required - the two status columns: a fresh import of `datasets/tickets-eval-10.csv` already includes blank `s1_status` and `s2_status` Text columns. If your eval table was imported from the earlier CSV without them, add both Text columns by hand (Add Column) - do not re-import and duplicate the tickets. The run-claim step writes these markers before any row is scored, and the plain data-table update node does not auto-create columns, so without them the first run stops before making any model call. The CSV predeclares every result column as blank Text, paired S1/S2 by metric: input tokens, output tokens, wall latency, server latency, route, route correctness, team, team correctness, confidence, urgency, urgency correctness, run timestamp, status; the S2-only parse-error column follows. Ticket text and expected labels come first. Write Results fills these existing columns by name and can still create missing result columns for older tables.
3. Create `comparison runs` if it does not exist yet - fastest: import `datasets/comparison_runs.csv` as a new data table (header-only on purpose: n8n types every column Text, zero rows; the workflows fill it). Or create it by hand under that exact name with Text columns `key`, `status`, `batch`, `expected`, `processed`, `started_at`, `completed_at`.
4. Only one node per workflow needs a table pick: When fetching a dataset row - select your `tickets eval 10` table there (its node type has no by-name mode; pick `tickets eval 10` specifically, since the name-based nodes resolve that exact table). Write Results to Dataset follows that pick automatically through an expression - do not touch its table field. The four run-state nodes - Get Run Status, Claim Run, Mark Rows Stale (S1/S2), Record Progress - find `comparison runs` / `tickets eval 10` by name and need no selection. Do not touch the table picker on those four: picking a table by hand switches the node off name lookup and can blank its column mapping.
5. Fallback only - restore a blanked column mapping. The four name-based nodes keep their shipped mappings as long as you never pick a table in them by hand. If a mapping did get blanked (or you renamed a table and had to repoint a node), open the node and restore only the blank values, exactly as written (switch the field to Expression when the value starts with `={{`). Blank fields are never sent, so leave every other field untouched - in particular, never type anything into the `ticket` or `expected_*` fields of Mark Rows Stale.
   - Claim Run (upsert into `comparison_runs`): `key` = `latest_s1`; `status` = `running`; `batch` = `={{ $execution.id }}`; `expected` = `={{ String($('When fetching a dataset row').first().json._rowsLeft + 1) }}`; `processed` = `0`; `started_at` = `={{ $now.toISO() }}`; `completed_at` = leave empty.
   - Mark Rows Stale (S1) (update the eval table - this is its only mapped field): `s1_status` = `={{ 'STALE since ' + $now.toISO() + ' - a new S1 run is in progress; s1_* values on this row are from a previous run' }}`.
   - Record Progress (upsert into `comparison_runs`): `key` = `latest_s1`; `status` = `={{ $('When fetching a dataset row').first().json._rowsLeft === 0 ? 'complete' : 'running' }}`; `processed` = `={{ String($('When fetching a dataset row').first().json.row_number + 1) }}`; `completed_at` = `={{ $('When fetching a dataset row').first().json._rowsLeft === 0 ? $now.toISO() : '' }}`.
   - S2 workflow: same three nodes and values, except `key` = `latest_s2`, and Mark Rows Stale (S2) maps `s2_status` = `={{ 'STALE since ' + $now.toISO() + ' - a new S2 run is in progress; s2_* values on this row are from a previous run' }}`.
6. ollaya on port 11435 for the S1 workflow; Ollama on port 11434 for the S2 workflow (model name from the `S2 Config` workflow, as in step 4).

Run: Execute workflow on the S1 canvas, then on the S2 canvas (either order - they are independent; run one at a time). n8n walks all 10 rows per run, one execution per row. Each run writes only its own `s1_*` or `s2_*` columns onto the shared rows; the `expected_*` label columns are never written.

Reading results: the same 10 rows show both systems side by side - computed route, per-field correctness flags (`correct` / `WRONG`), and two latency columns per system. `s1_wall_ms` / `s2_wall_ms` are the client-side wall time around each call with an identical measurer in both workflows - the headline comparison. `s1_server_ms` / `s2_server_ms` are each backend's own reported `total_duration`: the same named boundary (server-side total per call, model load included, transport excluded) but not identical internal composition (ollaya reports load + eval; Ollama load + prompt eval + eval), so treat server numbers as corroboration, not the headline. Every row also carries `s1_run_at` / `s2_run_at` marking which run produced it.

Freshness is fail-closed and visible in the table itself, per system: when a run claims, every row's `s1_status` / `s2_status` is set to `STALE since <timestamp> - a new run is in progress`; as each row completes, its status becomes `current as of <s1_run_at / s2_run_at>`. A row showing STALE still holds its previous-run values, clearly marked - an interrupted run can never leave old results looking current.

Token columns: `s1_input_tokens` / `s1_output_tokens` are ollaya's own reported `usage.input_tokens` / `usage.output_tokens`; `s2_input_tokens` / `s2_output_tokens` are Ollama's `prompt_eval_count` / `eval_count`. A 0 is a real measurement (S1's classifier generates no text); a blank means the backend did not report a count for that call - counts are never invented. Input counts come from different tokenizers, so read them as each backend's reported usage, not identical units of work. Older tables get missing columns automatically on the next run; earlier results stay blank until rerun.

Reruns and failure handling: in `comparison_runs`, the `latest_s1` / `latest_s2` key independently shows `running` -> `complete` with `processed` = `expected`; a run stuck at `running` blocks the next run until you set the cell to `aborted` and rerun. Reruns overwrite the same rows' `s1_*` / `s2_*` cells - no duplicate rows. One operator, one system at a time - concurrent runs against the same table have not been verified. One residual window, stated plainly: the claim and the stale-marking are one node apart, so a kill exactly between them can leave previous values unmarked - but that failure always leaves `comparison_runs` stuck at `running`, blocks every later run until set to `aborted`, and no new results are written, so a table whose key shows `running` is never a finished run.

## Run the demos

### 6. Run the triage demos

Open System 1 (Laya) Ticket Triage from the Workflows list, hit Execute workflow on its canvas, and watch each ticket come back with a team pick, confidence, urgency score, output token count, and latency in milliseconds. Then run System 2 (Ollama LLM) Ticket Triage the same way to compare. The first System 2 run can take a few minutes while Ollama loads the model into memory; later runs are much faster.

Double-click a completed node to read its output; the final routing node shows the decision. These two demos contain sample tickets already, so no chat message or terminal request is needed.

[DEMO.md](DEMO.md) has the demo-day runbook: setup checklist, model warmup, run order, and the rehearsed commands for each path.

### 7. (Optional) Demo through the chat front

`system1-ticket-triage-chat.json` screens the raw chat message with a Laya Chat Gate before doing any ticket triage. It uses `laya:en` on ollaya, with an `intent` choice (`support_ticket` vs `casual_chat`) and a `malicious` noul score.

- Safe casual message: a short canned conversational reply. No LLM call, no conversation memory - a small chat demo, not a general assistant.
- Support ticket: the existing S1 triage call and routing rules; a confident decision gets the same team/confidence/urgency/route/latency reply.
- Malicious message: score >= 0.7 gets a polite refusal before triage. Anger, swearing or frustration about a legitimate support issue are not malicious by themselves; the gate question says so explicitly.
- Uncertain ticket triage: S1 team confidence < 0.6 calls Ollama Escalation (System 2). The reply says S1 was unsure, shows S1 confidence and triage latency, then S2's team, confidence, urgency, computed route and latency. A failed or malformed S2 response stays `human_review` instead of inventing a decision.

The intent choice needs confidence >= 0.6 to enter ticket triage; an uncertain intent asks for more detail, an invalid or unavailable gate asks the user to retry. Maliciousness takes precedence over intent. These thresholds are demo defaults to test, not a reliable security boundary. Route labels only describe a decision: this workflow does not actually page anyone or create tickets.

1. Import `workflows/system1-ticket-triage-chat.json`. If replacing an older import, deactivate the old chat workflow first, then import the new one and activate it - keep only one active copy for this webhook path. Importing can create a duplicate; an already-imported workflow does not update when you pull.
2. Open http://localhost:5678/webhook/system1-triage-chat/chat in a browser tab. Hosted chat only listens while the workflow is active; click **Publish** in the workflow header first (or **Activate** on older versions), then type into the chat page.
3. Try `hello`, then a real ticket such as `I was charged twice for my subscription this month` or `Production server is down, customers cannot log in, revenue impacted`. Check that an angry but legitimate complaint still gets support. Inspect the gate/triage scores in the execution when testing thresholds and escalation.

The gate and confident-ticket paths need only ollaya (port 11435). The low-confidence escalation also needs Ollama (port 11434) with the model set in the `S2 Config` workflow. Not covered by the canned fallback.

### 8. (Optional) The five-questions workflow

`five-questions-demo.json` is the "All five, in one n8n workflow" slide as a single pipeline. One ticket goes in through a webhook. System 1 (Laya, `laya:en` on ollaya) decides at every stage, in a different way; sticky notes on the canvas name each step with the slide's words; plain code applies policy to what the model decided.

1. CLASSIFY - a choice call picks the team (infra, billing or sales) with a confidence.
2. ROUTE - a noul call scores urgency from 0 to 1. Code routes: >= 0.7 pages on-call, otherwise the team queue.
3. RANK - a score call picks a business-impact level (low, medium or high). Code maps it to a priority: P1 >= 1.5, P2 >= 0.5, otherwise P3. Optionally send `expected_team` and the reply marks the CLASSIFY pick right or wrong. This is a compact score for one ticket, not the Data Table evaluation in step 5.
4. GATE - a choice call decides: automate, or a human must handle it (legal threat, security incident, large refund, very upset customer). A human verdict stops the run at `human_review`; an unusable answer fails safe to human.
5. CHOOSE - a choice call picks the action: resolve with a help article, hand to the team, or escalate to System 2. Code policy on top: an urgent ticket is never auto-answered, and a CLASSIFY confidence under 0.6 always escalates. Escalation calls System 2 (Ollama, through the `S2 Config` workflow). If System 2 is also under 0.6 or fails to answer, the verdict is `human_review`.

A normal ticket makes five System 1 calls in a row (each roughly 0.5 s on the demo Mac) and System 2 only when escalated.

Run it:

1. Import `s2-config.json` first (step 4), then `five-questions-demo.json` (canvas **...** menu -> **Import from File**). If you use the OpenAI-compatible `five-questions-openai-demo.json` instead, it has its own `Endpoint Config` node and does not use `s2-config.json`. The two terminal workflows share `/five-questions`, so publish only the intended variant. If you imported an earlier version, delete or deactivate it first: re-importing creates a duplicate, and an already-imported workflow does not update when you pull.
2. Either click Execute workflow (it then waits for one call on the test URL), or publish/activate it to use the production URL. A webhook is an HTTP address that starts the workflow when it receives a request; clicking Execute alone does not supply a ticket.
3. Send a ticket from a terminal:

```
curl -X POST http://localhost:5678/webhook-test/five-questions \
  -H 'Content-Type: application/json' \
  -d '{"ticket":"Every Tuesday around 2pm our export job fails, but only for customers on the German login page. Rest of the week it works fine."}'
```

   Use `/webhook/five-questions` instead of `/webhook-test/five-questions` when the workflow is active. The test URL listens only during a manual test; click Execute again before sending another test request. The production URL stays available while published, without a canvas run waiting. Leave out `ticket` to use the double-charge example.
4. The JSON reply has `final_route`, `decided_by`, a `stages` object with each step's output, `laya_calls`, `laya_total_ms` and `total_ms`. There are three terminal verdicts: System 1 decided, human via gate, and System 2 answered. The last can still return `human_review` if System 2 is unsure or unavailable. Help-article and team-handoff actions share the System 1 terminal.

To tell the paths apart: four Laya calls with CHOOSE skipped indicates the gate-human terminal; five calls and a System 1 verdict indicates S1 alone; `stages.choose.system_2_usable` and System 2 confidence distinguish a usable S2 answer from its human-review fallback.

[DEMO.md](DEMO.md) (sections 3.1 and 3.2) has the three rehearsed paths - gate to human, System 1 alone, escalation to System 2 - with the exact prompts and PowerShell commands, plus the chat variant of this pipeline (`five-questions-chat-demo.json`).

The thresholds (0.7 urgent, 0.6 confidence, impact bands) are demo values to tune for your own tickets; routes are labels only (nothing is paged, queued or sent); the gate is a demo guardrail, not a security boundary. S1 can be confidently wrong, and a confident answer passes the gate. Not covered by the canned fallback.

## Fresh machine notes

- Ollama and the one heavy download: the System 2 comparison needs Ollama (https://ollama.com) with a model pulled - see step 3 for the per-platform pull commands. MLX builds only run on Apple Silicon; on Windows, Linux or an Intel Mac pull the standard `gemma4:12b` (or use an existing local model from `ollama list`, such as `mistral:7b`) and change the model name once in the `S2 Config` workflow (open it in n8n, edit the value in S2 Model Name, save). All System 2 workflows read it from there, so no other workflow edits, environment variables or n8n settings are involved. Everything else (n8n image, ollaya, the workflows) is small.
- Evaluations "Run test" needs a registered Community edition - still free: Settings > Usage and plan > Unlock, enter your email, and activate the key from the email n8n sends. Registration is per instance, but the same Community key can be activated up to 5 times (n8n FAQ), so one email covers several machines. Without it the comparison workflow still imports and runs manually - only the Run test button asks.
- host.docker.internal: the workflows reach ollaya and Ollama on your host through `host.docker.internal`. Docker Desktop on Mac and Windows resolves this natively - nothing to configure. On Linux, add `extra_hosts: ["host.docker.internal:host-gateway"]` to the n8n service in the compose file (or swap in your host's gateway IP).

## Fallback plan (if the live demo dies)

Two independent safety nets in `fallback/`:

- Canned path (stays interactive): import `fallback/canned-ollaya-responder.json`, activate it, and change one field - point the demo's Laya Decide URL from ollaya to `http://host.docker.internal:5678/webhook/canned-ollaya`. Same workflow, same logic, static answers with realistic latencies.
- Recording: `fallback/recording-shot-list.md` is a shot-by-shot capture script (screens, order, what to say per shot). Record the backup video in about 15 minutes.
- `fallback/capture-canned.sh` regenerates the canned responses from a healthy live ollaya in one command - run it before the talk so the cans are real captures.

The canned responder covers the original ticket demos, not the gated chat or five-questions workflows.

## Ports

| Service | Port | What it is |
| --- | --- | --- |
| n8n | 5678 | Workflow editor |
| ollaya | 11435 | System One decision API (`/api/decide`) |
| Ollama | 11434 | Local LLM (System Two comparison only) |
