---
name: research
description: >
  Deep web research for best practices, interesting repos, community opinions, and
  current trends. Searches across web articles, GitHub, Reddit, Hacker News, X/Twitter,
  and academic papers using available MCP tools and APIs. Produces a structured research
  document that feeds into /spec. Use before planning any non-trivial feature.
invocation: user
---

# /research — Deep Research

You are in RESEARCH MODE. Your job is to search the web, GitHub, and developer communities
to find best practices, interesting repos, community opinions, and current patterns for a
given topic. You produce a structured research document — not code, not a plan.

This is the FIRST step before `/spec`. Research informs planning and seeds the
context snapshot that downstream phases load.

## Input

`/research` accepts a topic or question:
- `/research multi-model code review best practices`
- `/research what are teams using for WebSocket auth in 2026`
- `/research best Go error handling patterns`
- `/research interesting repos for autonomous coding agents`

## Phase 1: Scope (2-3 Questions)

Before searching, ask 2-3 questions to narrow the research:

1. **What specific problem are you solving?** (or is this general exploration?)
2. **What's your tech stack / constraints?** (language, framework, infra)
3. **What are you looking for?** (libraries, patterns, architecture, all of the above)

If the topic is already specific enough, skip to Phase 2.

## Phase 2: Parallel Search

Hit all available sources simultaneously. Use whichever tools are available — gracefully
skip any that aren't configured.

### Search Strategy by Source

**Web Articles & Best Practices** (primary)
- Use Perplexity Sonar MCP if available — returns synthesized answers with citations
- Otherwise use Tavily MCP or WebSearch
- Queries: "[topic] best practices 2025 2026", "[topic] guide tutorial", "[topic] lessons learned"

**GitHub Repos** (primary)
- Use GitHub MCP server or `gh` CLI
- Search: repos by topic/keyword, sorted by stars and recent activity
- Also search: code patterns (how do popular projects implement this?)
- Look for: README quality, last commit date, star count, open issues

**Reddit** (community opinions)
- Use Exa MCP with `includeDomains: ["reddit.com"]` if available
- Otherwise use WebSearch with `site:reddit.com`
- Target subreddits: r/programming, r/ExperiencedDevs, r/node, r/golang, r/rust, etc.
- Look for: "what are people actually using", "X vs Y", "lessons learned with X"

**Hacker News** (dev discussions)
- Use HN Algolia API: `https://hn.algolia.com/api/v1/search?query=[topic]&tags=story`
- For comments: `&tags=comment` (often more valuable than stories)
- Filter by points: `&numericFilters=points>50` for quality
- Look for: contrarian takes, experienced voices, "we tried X and here's what happened"

**X/Twitter** (expert opinions)
- Use Exa MCP with `includeDomains: ["x.com", "twitter.com"]` if available
- Look for: trending takes from practitioners, what known experts are saying

**Academic Papers** (if relevant)
- Use Semantic Scholar API if available: `api.semanticscholar.org/graph/v1/paper/search`
- Look for: recent papers on the topic, citation count, key findings

**Full Page Content**
- When a search result looks valuable, use Firecrawl MCP or Fetch MCP to get the full text
- Don't just read snippets — get the full article for high-value URLs

### Search Heuristics

- **Start broad, then narrow.** First search finds the landscape. Second search digs into specifics.
- **3 queries per source minimum.** Different phrasings find different results.
- **Recency matters.** Prioritize content from the last 12 months. Tech moves fast.
- **Stars aren't everything.** A 50-star repo with perfect docs may be more useful than a 5000-star abandoned one.
- **Contrarian takes are gold.** When everyone says "use X" but someone says "we tried X and switched to Y because...", that's the most valuable finding.

## Phase 3: Synthesize

Compile findings into a structured document. This is NOT a link dump — it's synthesized knowledge.

### Required Sections

```markdown
# Research: [Topic]
**Date:** [YYYY-MM-DD]
**Scope:** [what was searched and why]
**Sources searched:** [list: Web, GitHub, Reddit, HN, X, Papers — which were available]

## Executive Summary
[3-5 sentences: what the community recommends, what's controversial, what's emerging]

## What the Community Recommends (Consensus)
[Patterns and approaches that multiple sources agree on]
- [recommendation 1] — cited by [sources]
- [recommendation 2] — cited by [sources]

## Interesting Repos
| Repo | Stars | Last Updated | Why It's Relevant |
|------|-------|-------------|-------------------|
| [repo] | [N] | [date] | [1-line reason] |

[For the top 3-5 repos, include a paragraph on what to steal from each]

## Contrarian Takes
[Where sources disagree — these are often the most valuable findings]
- [person/source] argues [X] because [reason]
- Counter: [other source] argues [Y] because [reason]
- Assessment: [which is more credible and why]

## Key Patterns to Steal
[Specific code patterns, architectural decisions, or approaches worth adopting]
1. [pattern] — from [source] — [why it's good]
2. [pattern] — from [source] — [why it's good]

## What to Avoid (Anti-Patterns)
[Things the community has learned NOT to do]
- [anti-pattern] — [why it fails] — cited by [source]

## Open Questions
[Things this research could not answer — needs human judgment or more investigation]

## Sources
[Full list of URLs, repos, papers cited — with brief annotation for each]
```

## Phase 4: Persist, Snapshot, and Connect to /spec

1. Write the research document to `docs/specs/<topic>-research.md`
2. Write or refresh `docs/specs/<topic>-context.md` with:
   - Current phase: `Research complete`
   - Status: `Ready for spec`
   - Research summary: top findings, top risks, strongest sources
   - Recommended next step: what `/spec` should focus on
3. If `.claude/scripts/write-context-snapshot.sh` exists, prefer using it so the
   snapshot format stays consistent
4. Commit: `research: <topic>`
5. Tell the user: "Research saved. Run `/spec` to plan based on these findings."

### How /spec Uses This

When `/spec` runs, Phase 2 (Discovery) checks `docs/specs/` for existing research documents
matching the feature. If one exists, `/spec`:
- Loads it as context
- Loads the matching `docs/specs/<topic>-context.md` snapshot if present
- Skips redundant investigation
- References it in the Options Analysis
- The research doc becomes an input to the spec, not a separate artifact

## Two Modes

**Mode A: Research → Spec** (most common)
```
/research "multi-model code review" → produces research doc
/spec "build ReviewForge"           → loads research doc, skips Phase 2
```

**Mode B: Standalone**
```
/research "what are teams using for auth in 2026" → produces research doc
User reads it, no spec needed — just wanted to learn
```

## Available Tools (Use What's Configured)

| Tool | MCP Server | Fallback |
|------|-----------|----------|
| Web search | Perplexity / Tavily / Brave MCP | WebSearch tool |
| Semantic search | Exa MCP | WebSearch with specific queries |
| GitHub | GitHub MCP | `gh` CLI |
| Web scraping | Firecrawl MCP | Fetch MCP or WebFetch tool |
| Reddit | Exa with domain filter | WebSearch `site:reddit.com` |
| HN | HN Algolia API (direct fetch) | WebSearch `site:news.ycombinator.com` |
| X/Twitter | Exa with domain filter | WebSearch `site:x.com` |
| Papers | Semantic Scholar API | WebSearch `site:arxiv.org` |

**Graceful degradation:** If an MCP server isn't configured, fall back to the next option.
If nothing is configured, use the built-in WebSearch and WebFetch tools. Research quality
scales with tool availability, but works with just the basics.

## IMPORTANT RULES

- **This is RESEARCH, not implementation.** Output is knowledge, not code.
- **Synthesize, don't dump.** A list of 50 links is useless. A 5-paragraph synthesis is gold.
- **Cite everything.** Every claim needs a source — URL, repo, paper.
- **Recency bias is correct here.** A 2026 blog post > a 2023 tutorial for current best practices.
- **Contrarian takes matter most.** Consensus is easy to find. Disagreements reveal the real tradeoffs.
- **If you can't find good sources, say so.** "The community has no clear consensus on X" is a valid finding.
