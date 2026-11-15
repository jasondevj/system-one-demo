# Fallback recording - shot list

Goal: a 2-3 minute backup video of the System 1 ticket-triage demo (plus a short System 2 contrast) that can be played if the live demo fails. Record in one sitting, two takes per shot, 1080p.

## Prep (before recording)

- [ ] Do Not Disturb on, hide the browser bookmark bar, close unrelated tabs and windows
- [ ] n8n open in one window with the canvas zoomed so the whole workflow fits; terminal in a second window
- [ ] Screen recorder at 1080p (QuickTime / OBS), quick mic check
- [ ] Record against the LIVE stack (ollaya + n8n running) - this video is the backup for when live fails, so it should look exactly like the real demo

## Shots (in order)

1. **Terminal: the model** (~5s) - `ollaya list`, `laya:en` visible.
   Say: "The decision model is small enough to run on this laptop."
2. **Canvas overview** (~10s) - whole S1 workflow on screen.
   Say: "Four tickets, one decision model, one if-statement."
3. **The ask** (~15s) - open the **Laya Decide (System 1)** node, show the request body (the noul + choice questions).
   Say: "We ask two focused questions: is it urgent, and whose problem is it. The model answers with numbers, not prose."
4. **The run** (~20s) - close the node, hit **Execute workflow**, let the nodes light up. Say nothing, or: "One forward pass per question."
5. **The result** (~20s) - open the **Route Decision** output: the 4-ticket table with team, confidence and latency_ms visible. Zoom so the numbers are readable from the back row.
   Say: "Every ticket decided in a few hundred milliseconds. And look at 'hmm' - confidence collapses, so the code, not the model, sends it to a human."
6. **The contrast** (~20s) - switch to the S2 workflow, run it, show its latency_ms column (seconds).
   Say: "Same questions, general model. Right answers too - eventually."
7. **(Optional) Side by side** (~15s) - the comparison Data Table with the s1_* and s2_* columns.
   Say: "Same tickets, both systems, one table."

## Capture notes

- Two takes per shot; mark keepers immediately after each take.
- If a run stutters, keep rolling - a slow frame in the backup video is fine. It is Plan B.
- Export MP4 to the laptop AND a USB stick. If possible, test playback in the venue's setup before the session.
