# Changelog

All notable changes to AI Finder are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and the project follows
[Semantic Versioning](https://semver.org/) (pre-1.0: minor versions may include
breaking changes).

## [Unreleased]

## [0.5.1] — 2026-06-17

### Changed
- Started a follow-up improvement release after the rubric v3 update.
- Review scorecard model headers now wrap within the card instead of
  overflowing when several long model names are shown.
- Verdict cards now summarize the best-scoring model with best-for,
  not-ideal-for, model-count, and free-tier guidance instead of listing
  individual model score rows.
- Verdict cards now place the overall score inside the summary body and use
  tighter heading spacing.
- Product pages are now focused on the verdict summary, with visit actions
  below the card and detailed pricing, availability, and full specs moved to
  the review page.
- Product-page compare controls now appear above the external visit button.
- Product-page compare controls now sit right-aligned without a card frame,
  with the compare action styled as a text link.

## [0.5.0] — 2026-06-17

### Added
- Added rubric v3 score fields and capability booleans to the seed CSVs,
  database schema, catalogue lint, scoring metadata, product facts, and compare
  page.

### Changed
- Category scores now use the rubric's atomic-score weights, while overall
  score remains an equal average of category composites.
- Review-page score details are collapsed under category aggregate rows by
  default and can be expanded on click.

## [0.4.1] — 2026-06-17

### Changed
- Clarified scorecard copy so "Our verdict" refers to the best model's
  overall score.
- Moved the product-page compare control below the full specs section.
- Updated the compare page with the new score categories and availability/data
  facts.

## [0.4.0] — 2026-06-16

### Added
- Added a double-clickable macOS launcher (`Launch AI Finder.command`) backed by
  `bin/launch`, which checks dependencies, prepares the database, starts the
  Rails server, and opens the app in a browser.
- Search ranking now uses the user's inferred intent: the parser can identify a
  priority score dimension (for example coding, writing, accuracy, privacy, or
  ease of use), and results are ranked by that relevant score plus the tool's
  overall score. Tools actually scored on the relevant dimension are ranked
  ahead of tools that have not been evaluated there.
- Tool detail pages now explain search-driven recommendations with a
  "Why you're seeing this" score strip when the user arrives from an intent
  search, showing the matched score alongside the overall score.
- Search results can now be sorted by relevance, overall score, or price. The
  relevance search still chooses the result set first; score and price only
  reorder those selected tools.
- Model variant seed data now includes explicit editable columns for every new
  rubric sub-score plus `free_to_try`, so score updates can be made directly
  through Git.

### Changed
- Reworked the scoring rubric around category averages: subcategory scores
  roll up into category scores, then category scores average into the overall
  score.
- Review pages now show the full score table vertically by criterion, while
  product pages keep the scorecard compact.
- Product and review pages now surface availability and data facts separately
  from the score table, including model-level `free_to_try`.
- Enlarged the review-page "Our verdict" card and colour-coded verdict numbers
  on a red-to-green 1-10 scale.
- Simplified the product-page scorecard: direct visits show the overall score
  only, while intent-search visits show the relevant matched score plus the
  overall score when that matched score exists.
- Back links now climb the product hierarchy predictably — review page to tool
  page, tool page to home — instead of relying on browser history.
- Renamed the per-model scorecard column "Verdict" → "Overall" to avoid
  clashing with the headline "Our verdict" (which is the best model's overall
  score).
- Reframed reviews as a per-tool page (`/tools/:id/review`): the full score
  overview (scorecard, extracted to a shared partial) followed by our written
  review if one exists, else just the scores + a link to visit the product.
  Linked as "See review for complete score overview" inside the "Our verdict"
  card on the tool detail page. Replaces the old per-`Review` page and the
  conditional card badge.
  The review page shows every criterion and the individual scores assigned
  (including the five output sub-scores per model); the detail page keeps its
  compact scorecard.
- The catalogue lint now accepts and validates the new model rubric columns in
  `model_variants.csv`.
- Cards now use a subtler white-to-light-grey surface gradient with soft depth.

## [0.3.0] — 2026-06-12

### Added
- Collaborator editing via GitHub: the seed CSVs are the editing surface
  (GitHub web editor → auto-PR), guarded by a catalogue lint
  (`script/validate_catalogue.rb` + a PR workflow) that checks headers,
  allowed values, score ranges and cross-references.
- Human reviews now live as markdown files with front matter in
  `db/seeds/reviews/`, imported idempotently by `db/seeds.rb` — so reviews are
  written and edited the same way as the catalogue.
- Model variants: individual models under a product (e.g. Claude → Fable 5 /
  Opus 4.8 / Sonnet 4.6 / Haiku 4.5), with per-model API pricing, context
  window, a "best for" line, and their own `last_verified` date. Shown as
  compact chips on result cards (price/best-for in the tooltip) and as a
  "Models & pricing" table on the tool detail page. Seeded from
  `db/seeds/model_variants.csv` (idempotent); only verified lineups belong in
  the CSV, and tools without variants simply omit the row. Seeded with
  web-verified lineups for seven tools (Claude, ChatGPT, Google Gemini,
  DeepSeek, Llama, Mistral Le Chat, Whisper — 20 variants). Variants are
  preloaded with results to avoid N+1. Search still matches at the product
  level — variants are evidence, not results.

### Changed
- Result card footer: "Read our review" is right-aligned so "See the full
  specs" and "Visit site" stay consistently left-aligned.
- "Read our review" button recoloured to dark purple.
- Reworked the evaluation model around four criteria: **output quality**
  (average of per-model text-generation / email-writing / logic / coding /
  image-generation sub-scores), **accuracy & trustworthiness** (a gate — a low
  score caps the verdict via `min`), **ease of use**, and **privacy & data
  safety**. Output-quality sub-scores + accuracy live per model variant; ease +
  privacy per tool. A tool's headline verdict is its best model's verdict, and
  ranking now weights by it. Old `quality_score`/`value_score` retired.
- Tools without a model lineup carry their own output-quality sub-scores +
  accuracy (the product's "one model"), so single-model tools get a full
  verdict too; their detail scorecard shows all four criteria instead of a
  per-model table. Shared scoring lives in a `Scoreable` concern.
- Result cards show an overall-verdict badge; the detail page gains an "Our
  verdict" scorecard (four criteria + a per-model output/accuracy/verdict
  table), degrading to "Not yet rated" until scored. Scores start blank for the
  team to fill via the CSVs; the lint validates the new columns (1–10).

### Removed
- The daily Claude + web-search freshness Action (`script/freshness.rb` and
  `.github/workflows/catalogue-freshness.yml`). Catalogue curation is now done
  by trusted collaborators editing the seed files directly on GitHub, guarded
  by the catalogue lint on PRs — so the automated-PR loop is redundant.
- The `catalogue_review.csv` worksheet and `generate_review_sheet.rb`. It
  duplicated the seed catalogue and was an easy file to edit by mistake; the
  single source of truth is now `db/seeds/ai_tool_catalogue_text_models.csv`.

## [0.2.0] — 2026-06-09

### Added
- Human reviews: a `Review` model tied to a tool, a "Read our review" link on
  result cards and the tool detail page when a published review exists, and a
  per-review page (`/reviews/:slug`) with a star rating. Seeded a sample Claude
  Code review linked from the Claude card. Reviews are preloaded to avoid N+1
  on results pages.

## [0.1.0] — 2026-06-09

First working prototype — plain-English search that returns a few honest AI tool
recommendations, built on Rails + PostgreSQL.

### Added

**Search & matching pipeline**
- Plain-English search with an LLM parse (Claude, Haiku-class, forced tool-use)
  that falls back to a deterministic keyword parser on any failure.
- Strict hard filter (free / private / runs-locally / category) that never pads
  results with tools failing a stated requirement.
- Weighted-random pick of 4–5 tools, value-weighted when cost is signalled.
- Honest empty/insufficient states ("we won't pad the list").

**Catalogue**
- `tools`, `categories`, `tool_categories` schema with string-backed enums.
- 22 starter tools + 7 categories, seeded from a CSV via an idempotent importer.
- `catalogue_review.csv` curation worksheet with per-tool "what to verify" notes.

**Pages & UI**
- Landing page: search bar + browse-by-category grid.
- Results as a vertical, Google-style list with human labels and the catch.
- Tool detail page with full specs and a `last_verified` trust signal.
- Side-by-side `/compare` view (up to 4 tools), scoped to your previous search
  results, shareable by URL.
- Blog ("Latest in AI"): landing-page section, `/blog` index, and per-post pages.

**Data & automation**
- Event logging: `search`, `specs_expand`, and outbound `card_click`.
- Daily GitHub Action that researches current figures (Claude + web search) and
  opens a review PR proposing catalogue updates — never auto-commits.

**Tooling**
- App version surfaced in the footer (`AiFinder::VERSION`).

### Notes

- Deployment is deferred (runs locally). The LLM parse and freshness job need an
  `ANTHROPIC_API_KEY` with API credit; without it everything falls back to the
  keyword parser and still works.
- Catalogue figures are reasonable approximations pending human curation.

[Unreleased]: https://github.com/okkle-lab/AI-Finder/compare/v0.5.1...HEAD
[0.5.1]: https://github.com/okkle-lab/AI-Finder/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/okkle-lab/AI-Finder/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/okkle-lab/AI-Finder/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/okkle-lab/AI-Finder/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/okkle-lab/AI-Finder/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/okkle-lab/AI-Finder/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/okkle-lab/AI-Finder/releases/tag/v0.1.0
