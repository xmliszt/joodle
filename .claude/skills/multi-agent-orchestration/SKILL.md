---
name: multi-agent-orchestration
description: Decide whether to decompose work across agents and how to scope a hand-off — start simple, split only at real boundaries, pass a contract (intent) not an implementation, and own the integrated whole.
---

# Decomposition & Delegation

How to decide whether to split work across agents — and how to hand it off. Distilled from
multi-agent orchestration practice; apply it whenever you scope, split, or delegate a task.

## When to split (and when NOT to)

- **Start simple.** Prefer one capable agent with the right skills/tools. Reach for a
  sub-task only at a real boundary — splitting is not free (extra latency, context
  switching, merge risk).
- **Split when a unit** is its own domain of expertise, needs different tools / permissions
  / governance, is independently shippable *and* parallelizable, or is reused across parents.
- **Do NOT split** for tidiness or symmetry. If coordination cost exceeds the work, keep it
  in one unit. Avoid both monoliths (one agent juggling many branching decisions) and
  over-shredding (a swarm of trivially-coupled tasks).

## How to scope a hand-off — contract, not implementation

- Write the **what and why**, never the **how**. The executing agent owns the implementation.
- A good task contract carries: the outcome (mission), why it matters, **acceptance
  criteria** (what done looks like), **context** (where to look — files, prior art), and
  **out of scope** (explicit non-goals). Reserve verbatim content (exact file text) for the
  implementation-notes escape hatch only.
- Keep each unit to **one narrow responsibility** with a clear, gate-verifiable definition
  of done.
- Hand off **structured data, not a chat dump**: goal, acceptance criteria, tool/data scope,
  and ordering via `depends_on`. Favour disjoint file/owner boundaries so parallel units
  don't collide.

## Topology

- Use a **supervisor/hierarchical** shape: a coordinator decomposes and delegates; workers
  execute narrow units; results roll back up. Run independent units in parallel; serialize
  only along real dependencies.
- The coordinator owns the **integrated whole** — delegating does not complete you. You are
  re-activated when children land to judge the combined result and either finish or delegate
  more. Decompose for a coherent integrated outcome, not just tidy parts.

## Using the protocol's scope block

- Read `task.scope` (size, splittable, parallelizable, candidate sub-tasks) as the starting
  signal — it is a **hint, not an order**.
- When you split, author each child's contract yourself (mission, context, acceptance
  criteria, out of scope) and set the child's own `scope` if it is further splittable.

## Staffing — spawn from existing roles, never invent them

- Call `list_team` to see the roles you can staff and which agents already exist. Staff each
  `create_task` with the role that fits (e.g. "Engineer", "Reviewer").
- If no agent of that role is currently free, `create_task` **spawns a fresh one from the
  role automatically** — you do not need an idle agent on hand to delegate.
- You may staff from existing roles only. You **cannot create or edit roles** — that is the
  operator's job. If the work needs a capability no role covers, flag it rather than forcing
  a poor fit.