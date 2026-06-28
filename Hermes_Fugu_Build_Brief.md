# BUILD BRIEF — Hermes Agent + Sakana Fugu Ultra Integration

**For:** Claude Code (fresh session)
**Owner:** Bill
**Machine:** Windows
**My working/notes folder:** `C:\dev\01_PRODUCTION\SakanaAI` (MY files only — not the agent tree)
**My GitHub repo (my files only):** `git@github.com:bill143/Ultimate_SakanaAI.git`
**Agent installs to:** its own managed layout `~/.hermes/hermes-agent` (via installer — leave it there)

---

## 0. READ THIS FIRST — what you are building (and what you are NOT)

You are setting up **Hermes Agent** (the open-source autonomous agent by Nous Research)
on a **Windows** machine, and configuring **Sakana Fugu Ultra** as its model provider.

Fugu Ultra is **not** a model you download, host, or "deploy." It is a cloud API in
**OpenAI-compatible format**. Integrating it means: point Hermes at Fugu's endpoint +
API key, then select the model. That's the whole integration. Do not build a model
server, do not set up CUDA, do not clone any Sakana model weights.

**This is NOT a chat-UI project. This is NOT the AI-Scientist research pipeline.**
It is: install Hermes (one installer) → run it on a cheap/known model first to prove it
works → then switch the provider to Fugu Ultra for the high-reasoning work.

**Ask me nothing to start.** Every decision you need is answered in Section 1 below.
Stop and check with me only at the two explicit CHECKPOINTS marked in Section 3.

---

## 1. PRE-ANSWERED CONFIGURATION (do not re-ask any of this)

**Environment**
- OS: Windows. Hermes now runs **natively on Windows — do NOT require or install WSL2.**
  The official installer bundles its own uv, Python 3.11, Node.js, ripgrep, ffmpeg, and a
  portable Git Bash (no admin needed). Let the installer handle all of it.
- Package manager: whatever the installer uses. Do not substitute.

**Repos — CONFIRMED-ONLY policy (important)**
- Only TWO repos are verified real and approved for use:
  1. `NousResearch/hermes-agent` — the canonical agent. **Do NOT `git clone` this by hand.**
     Install it via the official installer, which clones it into its own managed layout
     (`~/.hermes/hermes-agent`). Cloning manually breaks `hermes update` and the CLI.
  2. `nesquena/hermes-webui` — OPTIONAL community web UI. Only add if I ask. Vet before use.
- The following were NOT confirmed to exist — **DO NOT attempt to clone or install them**,
  do not "find a substitute," do not improvise: `fathah/hermes-desktop`,
  `NousResearch/hermes-example-plugins`, `NVIDIA/NemoClaw`.
- If any repo, skill, or plugin cannot be verified to exist, **do not use it.** Tell me instead.

**Install location & my repo (read carefully — two separate things)**
- **The Hermes AGENT installs to its own managed layout** (`~/.hermes/hermes-agent`, via the
  installer). Do NOT force the agent's install tree into `C:\dev\`. Do NOT clone or fork the
  agent into my repo. `hermes update` and the CLI depend on the managed layout.
- **MY working/notes folder (for MY files only):** `C:\dev\01_PRODUCTION\SakanaAI`
  - Use this for: this brief, my config notes, SOUL.md/persona, custom skills I write,
    redacted reference docs. NOT for the agent's own source files.
- **MY GitHub repo (destination for MY files only):** `git@github.com:bill143/Ultimate_SakanaAI.git`
  - This repo backs up the working folder above. It must contain MY materials only —
    never the Hermes agent tree, and **never any file containing a key** (see Security).
  - NOTE on naming: the folder/repo say "SakanaAI" / "Ultimate_SakanaAI" for historical
    reasons. What actually lives here is a **Hermes Agent setup + Fugu config**, not Sakana
    source code. Use the names as given; just don't let the label confuse the architecture.
  - Before pushing: confirm `.gitignore` excludes `.env`, `config.yaml`, and anything with
    secrets. If SSH auth to GitHub isn't already working, tell me — do not switch remotes or
    improvise credentials.

**Version policy**
- **Never run `main` in production.** Check out a specific tagged release. Read the README
  of that exact tag before running anything — Python version, env var names, and install
  steps can differ between releases.

**Model provider — the integration target**
- Provider = **Sakana Fugu**, via its **OpenAI-compatible API**. Two models exist:
  `fugu` (balanced) and `fugu-ultra` (deep reasoning). We want **`fugu-ultra`** for the
  review/QA/reasoning work.
- Fugu Ultra pricing to budget against (verify live before relying on it):
  ~$5 / 1M input tokens, ~$30 / 1M output tokens, ~$0.50 / 1M cached input.
  NOTE: Fugu orchestrates multiple models under the hood and bills their tokens as normal
  input/output — so token consumption per task can be higher than a single-model call.
  Do not assume the cheap-sounding input price reflects total cost.
- Privacy caveat to surface to me, not decide for me: standard `fugu` allows opting agents
  out of its pool; **`fugu-ultra` uses a fixed pool with no opt-out.** Flag this; don't act on it.

**Bootstrap provider (to prove Hermes works BEFORE spending on Fugu)**
- Hermes supports a local subscription proxy for OAuth-backed providers (e.g. Claude Pro,
  ChatGPT Pro, SuperGrok) and also OpenRouter / OpenAI keys.
- **FIRST run Hermes on whatever low-cost/existing credential I provide at Checkpoint 1.**
  Only after the agent is confirmed working do we wire in Fugu Ultra. Do not start on Fugu.

**Messaging surface**
- Start with **CLI only.** Do NOT set up Telegram/Discord/any gateway until the core agent
  is proven. (Rule: the machine running the gateway must be the one responding — don't add
  that complexity first.)

**Security — non-negotiable on Windows**
- On Windows, Hermes stores secrets (API keys) in **plaintext** `config.yaml` / `.env`
  (no Windows DPAPI/Keychain). Therefore:
  - Lock down the install/config directory permissions.
  - Add any secret files to `.gitignore`. **Never commit keys.** Never paste keys into chat.
  - I will enter keys myself / you reference them by env var — you do not echo them back.
- If you enable Hermes's OpenAI-compatible API **server**, it allows **unauthenticated
  access when no key is set.** If you turn that server on, you MUST set an auth key on it.
  (For this build, do NOT enable that server unless I explicitly ask.)
- Treat community skills with suspicion (the comparable ecosystem had malicious skills
  flagged in 2026 audits). Scope credentials tightly; install only skills I approve.

**Definition of "done" for this project**
- Hermes installed and running on Windows, on the bootstrap provider, responding correctly
  in the CLI; THEN Fugu Ultra configured as a selectable provider and confirmed with one
  real test prompt. That is the finish line — not a hosted site, not a gateway, not a fleet.

---

## 2. STARTING STATE
- Fresh start. There is **no existing Hermes project** to resume (we checked `C:\dev`;
  only stray references inside unrelated projects were found). Build clean.
- First action: ensure my working folder `C:\dev\01_PRODUCTION\SakanaAI` exists (create it
  if missing), confirm it is the local checkout of `git@github.com:bill143/Ultimate_SakanaAI.git`,
  save a copy of this brief there, and set up `.gitignore` to exclude `.env`, `config.yaml`,
  and any secret-bearing files BEFORE anything else is committed.

---

## 3. EXECUTION PLAN (run in order; pause only at the two checkpoints)

**Step 1 — Verify, then install Hermes (native Windows)**
- Confirm the official install method from `NousResearch/hermes-agent` for the current
  tagged release (read that tag's README). Run the official Windows-native installer.
- Do not install WSL. Do not clone the repo by hand.

**Step 2 — Pin the release**
- Ensure you are on a specific release tag, not `main`. Record which tag.

**=== CHECKPOINT 1 (stop, ask me) ===**
- Tell me the release tag you pinned and the install location.
- Ask me which **bootstrap credential** to use (Claude Pro / ChatGPT Pro / OpenRouter key /
  OpenAI key). I will provide it securely — you reference it, never echo it.

**Step 3 — First run on bootstrap provider**
- Configure that provider, select a low-cost model, and confirm Hermes responds in the CLI.
- Run `hermes doctor` (or the tag's equivalent) and confirm a clean diagnostic.
- Verify secret files are gitignored and the config dir is locked down.

**Step 4 — Add Sakana Fugu as an OpenAI-compatible provider**
- Add Fugu as a custom provider: its OpenAI-compatible base URL + my Sakana API key
  (I provide the key at the next checkpoint; do not hardcode or echo it).
- Select model `fugu-ultra`.

**=== CHECKPOINT 2 (stop, ask me) ===**
- Confirm you're about to switch to a **paid** provider (`fugu-ultra`).
- Ask me for the Sakana API key (entered securely) and confirm the billing mode I want
  (pay-as-you-go to start — do NOT assume a subscription tier).
- Restate the privacy caveat: `fugu-ultra` has a fixed model pool, no opt-out.

**Step 5 — Verify the integration**
- Send ONE real test prompt through `fugu-ultra`. Confirm a correct response and that the
  call was billed/logged as expected.
- Report token usage from that single call so we can sanity-check real cost before scaling.

**Step 6 — Hand back**
- Summarize: installed tag, bootstrap provider, Fugu provider config (key redacted),
  how to switch models (`hermes model`), and where config/secrets live.
- Commit MY notes/config (this brief, SOUL.md, any skills, redacted setup notes) to
  `C:\dev\01_PRODUCTION\SakanaAI` and push to `git@github.com:bill143/Ultimate_SakanaAI.git`.
  Confirm no `.env`, `config.yaml`, or any key-bearing file is staged. The agent's own
  install tree (`~/.hermes/...`) is NOT committed.
- Do NOT add gateways, web UI, extra skills, or automations unless I ask next.

---

## 4. HARD RULES (apply throughout)
1. Confirmed-real repos/skills only. If you can't verify it exists, don't use it — tell me.
2. No WSL. Native Windows install via the official installer.
3. Never clone `hermes-agent` by hand; never run `main`; always pin a release tag.
4. Never commit, hardcode, log, or echo API keys. They're plaintext on Windows — protect them.
5. Don't enable the OpenAI-compatible API server unless I ask; if enabled, require an auth key.
6. CLI first. No messaging gateway until I ask.
7. Bootstrap provider first; Fugu Ultra second. Two checkpoints are mandatory stops.
8. Don't pick a Fugu subscription tier for me — pay-as-you-go to start.
