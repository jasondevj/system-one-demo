# Demo-day runbook (Nov 24)

A checklist, not documentation. Setup details live in the [README](README.md).

## Before the talk

- [ ] `docker compose up -d` in this repo, then open http://localhost:5678
- [ ] ollaya running on port 11435, Ollama running on port 11434 (model: `gemma4:12b-mlx`)
- [ ] All workflows imported and published (active): S2 Config first, then the rest. Keep this copy untouched until the talk.
- [ ] `tickets` data table still selected in both evaluation nodes of the comparison workflow
- [ ] Fallback ready: `fallback/capture-canned.sh` re-run, backup recording captured (see the end of this file)

### Warm up both tiers (do this right before going on stage)

Both models pay a cold-start tax. Fire one throwaway call at each, then keep them warm.

1. **System 1 warmup** - run the pricing command below once.
2. **System 2 warmup** - run the enterprise command below once and wait for it to finish. A cold gemma can take longer than the 120 s node timeout; if the reply says `human_review`, run it again. Do not go on stage until it returns a System 2 answer.
3. gemma is dropped from memory after a few idle minutes. If you wait longer than that, repeat step 2.

## Live run order

### 1. System 1 triage (canvas)

Run `system1-ticket-triage` from the canvas on the four tickets. Instant answers set the baseline: System 1 gets 4/4 right in well under a second per ticket.

### 2. Five questions - pricing ticket (System 1 alone)

```powershell
Invoke-RestMethod -Uri http://localhost:5678/webhook/five-questions -Method Post -ContentType 'application/json' -Body '{"ticket":"Do you offer volume discounts for 500 seats?"}' | ConvertTo-Json -Depth 6
```

Expect: all five stages (classify, route, rank, gate, choose), `decided_by` = System 1 (Laya), about 150 ms in total. Say: "five decisions, five different call types, and the code only applies the rules."

### 3. Five questions - enterprise ticket (escalates to System 2)

```powershell
Invoke-RestMethod -Uri http://localhost:5678/webhook/five-questions -Method Post -ContentType 'application/json' -Body '{"ticket":"We are a 500-seat enterprise: your export fails every Tuesday, we were charged twice this month, and we need volume discount pricing. Can someone own all of this?"}' | ConvertTo-Json -Depth 6
```

Expect: CLASSIFY confidence about 0.28, so CHOOSE escalates (`policy_overrides` shows "classify confidence < 0.6"). `decided_by` = System 2 (Ollama), after System 1 escalated. Warm, it takes roughly 15 to 110 s. Narrate the wait: "this is what deep reasoning costs. System 1 knew it was unsure in about 300 ms."

### 4. Chat demo (last)

Open http://localhost:5678/webhook/system1-triage-chat/chat (workflow active).

1. Type `hello` - a short canned reply, no triage.
2. Type the Tuesday ticket: `Every Tuesday around 2pm our export job fails, but only for customers on the German login page. Rest of the week it works fine.`
   Expect: System 1 is unsure (confidence under 0.6), the reply shows that and then System 2's answer. This one also waits on gemma, so keep it warm.

## If something breaks

- Slow or hung System 2: wait up to two minutes, then re-run (the model is loaded by then).
- ollaya down: use the canned responder (README, "Fallback plan").
- Everything down: play the recorded backup (`fallback/recording-shot-list.md` has the shot order).

## Fallback pointers

- `fallback/canned-ollaya-responder.json` - import, activate, point **Laya Decide** at it (one field).
- `fallback/capture-canned.sh` - regenerate the canned responses from a healthy ollaya.
- `fallback/recording-shot-list.md` - the backup video script.
- The canned responder covers the original ticket demos, not the gated chat or the five-questions workflow.
