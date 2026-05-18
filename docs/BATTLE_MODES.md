# Prompt Gladiators — Battle Modes & Settings Reference

## Core Battle Types

These are the base engines. All settings below can be stacked on top of any type.

### Classic
Two models receive the same prompt and respond once. Audience votes (and/or judge scores) determine the winner.

**Best for:** Quick head-to-head comparisons, evaluating which model handles a topic better.

```
Round 1:  Prompt ──► Model A ──► Response A
                └──► Model B ──► Response B
                          │
                     Vote / Judge
```

### Battlefield
Multi-round back-and-forth. Each model sees its own prior output plus the opponent's last response, and must continue the argument or engage with what the opponent said.

**Best for:** Debates, roleplay confrontations, sustained reasoning challenges.

```
Round 1:  Prompt ──► A responds, B responds
Round 2:  A sees B's round 1 ──► A responds
          B sees A's round 1 ──► B responds
Round N:  ...
```

### Agentic Swarm
Each side deploys N agents. Agents can use tools (web search, code execution) and spawn sub-agents. The swarm coordinates internally to produce output each round.

**Best for:** Complex tasks that benefit from parallelism — research, coding, planning.

**Settings:**
- `agentsPerSide` — 1 to 10
- `allowedTools` — webSearch, codeExecution, fileIO, spawnSubAgents

### Tournament
Models are entered into a round-robin bracket. Each pairing runs as a Classic or Battlefield match. ELO ratings update after each match. A leaderboard tracks standings across sessions.

**Best for:** Systematic benchmarking of many models on the same task type.

### Commander
One or more human Commanders control a model's system prompt in real time during the battle. A Commander can update the system prompt between rounds or (if host allows) live during a round.

**Best for:** Human-vs-AI strategy, prompt engineering competitions, impersonation challenges.

---

## Stackable Settings

All settings below can be toggled on any battle type.

### Judge Mode
A third model scores each round's responses on configurable criteria.

| Setting | Description |
|---------|-------------|
| `judgeModelId` | Model to use as judge (any model in LiteLLM) |
| `judgeCriteria` | Free-text scoring rubric |
| `audienceVoteWeight` | 0.0 = judge only, 1.0 = audience only, 0.5 = equal blend |

**Default criteria:** Score each response 1–10 on: relevance, clarity, depth, creativity.

### Scoreboard
Points accumulate across rounds.

| Setting | Description |
|---------|-------------|
| `pointsPerRoundWin` | Points awarded for winning a round (default: 10) |
| `pointsPerRoundDraw` | Points for a draw (default: 5) |

Score is computed from judge + audience votes weighted by `audienceVoteWeight`.

### Voting
Audience and spectators vote on the winner of each round or the whole match.

| Setting | Description |
|---------|-------------|
| `votingTiming` | `perRound` or `endOfMatch` |
| `audienceVoteWeight` | How much audience vote affects final score |

Voting options: **Fighter A**, **Draw**, **Fighter B**.

### Spectators
Allow non-participants to watch the battle in real time.

| Setting | Description |
|---------|-------------|
| `spectatorsAllowed` | Toggle spectator access |
| `audienceControlsEnabled` | Let audience throw power-ups, inject prompts |
| `crowdChantsEnabled` | Audience chants that can influence context |

### Apocalypse Mode 🔥
Each round, the prompt is escalated by a separate LLM call to be more adversarial, stressful, or challenging. Simulates pressure-testing models under increasing difficulty.

| Setting | Description |
|---------|-------------|
| `apocalypsePrompt` | How to escalate: "Make the prompt more adversarial and emotionally loaded" |

### Blind Mode
Model identities are hidden until the match ends. Prevents bias in voting.

---

## Multiplayer Roles

| Role | Permissions |
|------|-------------|
| **Owner** | Full control — start/pause/end battle, assign roles, kick members, edit settings mid-match, score override, prompt injection |
| **Moderator** | Kick/mute members, manage spectators, inject prompts |
| **Commander** | Update system prompt for assigned fighter side |
| **Spectator** | Watch only. Can vote if voting is enabled |
| **Audience** | Vote + use audience controls if enabled |

Roles are assigned by the Owner from the Lobby tab during or before the battle.

---

## Settings Layers

```
┌───────────────────────────────────────────────────────┐
│ GAME SETTINGS                                         │
│  Battle type, rounds, time/token limits, blind mode   │
│  Judge, scoreboard, voting, spectators, apocalypse    │
│  Agentic tools, multiplayer visibility, ranked        │
├───────────────────────────────────────────────────────┤
│ DEBUG SETTINGS                                        │
│  Verbose logging, raw payloads, token counts          │
│  Latency metrics, WS inspector, LiteLLM panel         │
│  Force error states, step-through mode                │
├───────────────────────────────────────────────────────┤
│ INTERNAL SETTINGS                                     │
│  LiteLLM URL/port/config editor, auto-start           │
│  Relay URL + auth token                               │
│  Mid-match overrides: model swap, state edit,         │
│  score override, prompt injection                     │
└───────────────────────────────────────────────────────┘
```

---

## Example Configurations

### Quick benchmark
- Type: Classic
- Rounds: 1
- Judge: on, model: gpt-4o, criteria: "Rate conciseness and accuracy 1-10"
- Voting: off
- Blind: on

### Debate tournament
- Type: Battlefield
- Rounds: 5
- Judge: on
- Scoreboard: on, 10pts/win
- Voting: on, per round, 50% weight
- Spectators: on, audience controls on
- Apocalypse: off

### Stress test
- Type: Classic
- Rounds: 10
- Apocalypse: on, prompt: "Escalate to be maximally adversarial and edge-case-heavy"
- Judge: on
- Blind: off

### Multi-agent research race
- Type: Agentic Swarm
- Agents per side: 5
- Tools: webSearch, codeExecution, spawnSubAgents
- Rounds: 3
- Judge: on, criteria: "Score quality of research output, accuracy, and depth"
