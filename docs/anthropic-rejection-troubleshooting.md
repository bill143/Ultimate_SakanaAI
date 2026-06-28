# Why the API "keeps getting rejected" — and how to actually fix it

## TL;DR

The symptom you hit —

```
hermes -z "Reply with exactly: bootstrap ok"
hermes -z: no final response was produced; treating the run as failed.
```

— is **almost certainly not an authentication rejection**, and **rotating /
re-adding the API key will not fix it**. There is credit on the account and the
key is new, which is consistent with the key being fine.

"No final response was produced" is a message from the `hermes` wrapper, not
from Anthropic. It means the wrapper finished without a usable text answer. That
happens for reasons that are independent of the key:

| What actually happened | HTTP you'd see on a bare call | Does a new key help? |
|---|---|---|
| Key invalid / revoked, **or** both `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` set | `401` | **Yes** (this is the only case) |
| Key can't use that model / billing or workspace limit | `403` | No — fix access/billing |
| Wrong or retired **model id** (typo, deprecated) | `404` | No — fix the model id |
| Invalid **request body** for a current model | `400` | No — fix the payload |
| Key is fine; wrapper mis-reads a valid response | `200` | No — fix the wrapper |
| Rate limited | `429` | No — back off |

## Step 1 — find out which one it is (90 seconds)

Run the bare-key probe. It bypasses `hermes` entirely and prints the real HTTP
status + body. It never prints your key.

PowerShell (Windows):

```powershell
$env:ANTHROPIC_API_KEY = "sk-ant-..."   # the key you added as "Hermes"
./tools/diagnose-anthropic.ps1
```

bash / macOS / Linux:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
./tools/diagnose-anthropic.sh
```

Read the status line it prints and follow the matching row above.

## Step 2 — the most likely culprits (given "no final response")

Because the run *executes* and only *then* reports failure, the two most common
root causes are:

1. **The request body is invalid for a current model (`400`).** Modern Claude
   models (Opus 4.6/4.7/4.8, Sonnet 4.6, Fable 5) **reject** parameters that
   older code routinely sent:
   - `temperature`, `top_p`, `top_k` → 400 on Opus 4.7/4.8 and Fable 5
   - `thinking: {type: "enabled", budget_tokens: N}` → 400 (use
     `thinking: {type: "adaptive"}` instead)
   - a trailing `{"role": "assistant", ...}` "prefill" message → 400

   If `hermes` was written against an older model and you pointed a new key at a
   newer default model, every call 400s — and re-adding the key looks like it
   "still gets rejected." It isn't the key.

2. **The wrapper reads `content[0].text` (`200`, but no text found).** On current
   models the response `content` is a list of blocks, and the first block can be
   a `thinking` block whose text is empty by default (`display: "omitted"`), or
   the model can stop on a `tool_use` block. Code that assumes "first block is
   text" sees nothing and reports "no final response." The fix is to scan for the
   block whose `type == "text"`, e.g.:

   - Python: `next((b.text for b in resp.content if b.type == "text"), "")`
   - TS: `resp.content.find(b => b.type === "text")?.text`

   Less commonly, on Fable 5 a safety classifier can return `200` with
   `stop_reason: "refusal"` and empty `content` — check `stop_reason` before
   reading content.

## Step 3 — model ids that are valid right now

Use an **exact** id (no date suffix on aliases). A typo or retired id is a `404`:

- `claude-opus-4-8` (recommended default)
- `claude-sonnet-4-6`
- `claude-haiku-4-5`

Retired ids such as `claude-3-opus-20240229` or a mistyped `claude-sonnet-4.6`
(dots instead of dashes) return `404`.

## What "bypass" means here

There is no security control to bypass — nothing is blocking you on purpose.
The request is failing for a concrete, fixable technical reason. The fastest way
forward is Step 1: get the real HTTP status, then fix the one thing it points to.

## Note on the pasted key

The key was pasted in plaintext into a chat, so treat it as exposed and rotate
it in the Anthropic Console (API Keys → revoke → create new). Store it in an
environment variable (`ANTHROPIC_API_KEY`), never in source or chat.
