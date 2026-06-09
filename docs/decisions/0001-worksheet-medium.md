# 0001 — Worksheet medium: print-first now, interactive on-screen later

**Status:** Accepted (A), with B explicitly deferred — 2026-06-09
**Context:** Training-session collateral that "shows off" the lean dev-workflow principles.

## Decision

Build **A — print-first worksheets**: self-contained HTML that prints beautifully to
A4/Letter and gets filled in with a pen during the session. Interactive flourishes are
welcome only where they degrade gracefully on paper.

## Deferred — B: interactive on-screen edition (we WILL return to this)

A laptop-first, screen-native version: animated diagrams, clickable state machines,
hover-to-reveal, live "try it" widgets, dark mode. Deferred, not dropped.

### What B will need (capture so A doesn't foreclose it)

A must be authored so B is a later *enhancement of the same source*, not a rewrite:

- **Diagrams as live DOM/SVG, never flattened raster.** A worktree lifecycle or CI pyramid
  drawn in SVG/HTML can later be animated/made interactive; a PNG cannot.
- **Semantic, layered markup.** Content structured by meaning (sections, steps, exercise
  blocks) so a screen stylesheet can re-flow it without touching content.
- **Progressive enhancement.** Any JS is additive; the sheet is complete and correct with
  JS off (which is also what makes it print-safe). B turns the same hooks "on."
- **Theme as a seam.** Author colour/contrast via CSS custom properties + a print stylesheet,
  so a dark on-screen theme is a variable swap, not a redesign.
- **One content source.** Ideally the exercise/explainer/takeaway content lives in a form
  that both the print sheet and the future screen edition render — avoid duplicating prose.

**Net constraint on A:** prefer SVG/DOM diagrams, semantic structure, CSS-variable theming,
and optional-JS interactivity — even though A itself is static print — purely to keep B cheap.
