# Fallback plan (demo-day insurance)

Two independent safety nets for the live System 1 demo, in case the model, the daemon, or the venue Wi-Fi dies on stage.

## Option A - canned responses (keeps the demo interactive)

`canned-ollaya-responder.json` is an n8n workflow that answers `POST /webhook/canned-ollaya` exactly like ollaya's `/api/decide`: it reads the ticket from the request body and returns a matching canned response with the same fields the demo workflow parses (`answers.urgent.noul`, `answers.team.choice/confidence`, `usage.output_tokens`, `total_duration`).

1. Import `canned-ollaya-responder.json` into n8n and **activate** it (webhooks only listen while active).
2. In the demo workflow, change ONE field: the URL of **Laya Decide (System 1)** (and **Ollaya Decide** in the choice PoC) from `http://host.docker.internal:11435/api/decide` to `http://host.docker.internal:5678/webhook/canned-ollaya`. On Linux, use `http://localhost:5678/...` if `host.docker.internal` does not resolve.
3. Run the demo as normal - same workflow, same routing logic, same outputs.

The raw responses live in `canned/*.json`. They are hand-written placeholders with realistic values and latencies (140-190ms). Run `./capture-canned.sh` once against a healthy live ollaya before the talk to replace them with real captures (and paste the real ones into the responder workflow's Code node if you want the responder to serve real data too).

## Option B - fallback recording

`recording-shot-list.md` is a shot-by-shot capture script: which screens, in what order, what to say per shot. Recording the backup video takes ~15 minutes following it.

## One-time check before the talk

- [ ] Run `./capture-canned.sh`, eyeball the 4 files, commit
- [ ] Import + activate the responder, switch the demo URL, run all 4 tickets, confirm the outputs look right, switch back
- [ ] Record the backup video per the shot list, export MP4 to laptop AND USB stick
