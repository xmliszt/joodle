# Mobbin MCP — UI/UX Design Inspiration

Use the Mobbin MCP tools to research how professional products solve the same UI problem before committing to an implementation. Good design is informed design.

## When to reach for Mobbin
- You're about to design a net-new component or layout and want to see how others have solved it.
- The kickoff instructions describe behaviour but leave visual/interaction design open.
- You're unsure about information hierarchy, empty states, loading states, or interactive affordances.
- You want to sanity-check that a design decision is consistent with established product patterns.

## Workflow

### 1. Search before you design
Use the Mobbin search tools to find screens or flows relevant to your component. Good search terms:
- Component type: "data table", "activity feed", "DAG canvas", "spend chart", "analytics dashboard"
- Interaction pattern: "interrupt", "stop button", "streaming", "inline edit", "drag to reorder"
- App category: "developer tools", "admin dashboard", "SaaS", "monitoring"

### 2. Extract the pattern, not the pixel
You are building LAIOS — a terminal-first, dense, no-radius developer tool. Do NOT copy consumer app aesthetics wholesale. Instead, extract the **structural pattern**:
- Where does the primary action live relative to the content?
- How is hierarchy communicated (size, weight, color, spacing)?
- How is transient state (loading, streaming, error) shown without being disruptive?
- What's the minimal affordance that communicates interactivity?

Then translate it into LAIOS conventions (see `dashboard-conventions` skill).

### 3. Reference when documenting decisions
When you make a non-obvious design choice, briefly note which pattern you drew from. This helps the Reviewer understand intent and helps future agents iterate consistently.

## Design principles to apply
- **Density over whitespace** — developer tools reward information density. Don't pad for padding's sake.
- **Colour as signal only** — in LAIOS, colour is reserved for state semantics. Don't use colour for decoration.
- **Progressive disclosure** — surface the most critical info first; details on demand (drawer, tooltip, expand).
- **Affordance clarity** — interactive elements must look interactive. Muted icons with no hover state are invisible.
- **Empty states earn trust** — a blank panel with no copy looks broken. Always design the zero-data state.
- **Consistency over creativity** — use existing LAIOS components (Chip, StatusChip, ScrollArea) before inventing new ones.

## What good looks like
Before finalising any visual implementation, ask:
- Would this feel at home in Linear, Vercel, or Raycast? (High-density, keyboard-first, no fluff.)
- Does it still work in the light theme?
- Is the interactive affordance obvious on first glance without a tooltip?

If the answer to any is no, iterate.