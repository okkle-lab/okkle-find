# Prompt Output Grader

macOS SwiftUI wrapper for `script/prompt_output_grader.py`.

Run it from this folder:

```bash
swift run PromptGradeApp
```

Build a double-clickable macOS app:

```bash
./package_app.sh
open dist
```

This creates `dist/Prompt Output Grader.app` with the Python grader bundled
inside the app, so users do not need to install `openpyxl` or use Terminal.

Inputs:

- Test output workbook: `model_test_results.xlsx` or `responses.xlsx` from the
  Model Eval Runner. The grader reads the `Run Results` sheet by default.
- Grading model spreadsheet: same model-list format used by the Model Eval
  Runner. Text-capable enabled rows become judge models. The app ships with a
  grading-specific default at `PromptGradeApp/Defaults/AI_model_variants.xlsx`
  containing one ChatGPT grader and one Claude grader.
- Rubric workbook: first sheet with a `Rubric`, `Scoring Rubric`, `Scoring
  Guidance`, or `Grading Instructions` column. The app also accepts the
  banded model-testing rubric layout with `What it measures`, `1-3 (Poor)`,
  `4-6 (Adequate)`, `7-8 (Strong)`, and `9-10 (Excellent)` columns. Add
  `TESTID` to make rubric rows apply to specific prompts.
- API key: cloud providers need authentication. Paste OpenRouter and/or OpenAI
  keys into the app as needed by the grading model spreadsheet.

Default spreadsheets:

- `Defaults/AI_model_variants.xlsx`
- `Defaults/Model_Testing_Rubric.xlsx`
- `Defaults/model_variants.csv`

This folder is intentionally separate from `ModelEvalApp/Defaults/`, so the
grading app can use a smaller, cheaper judge-model lineup without changing the
model testing app. The app preselects the bundled grading model workbook and
rubric workbook on launch. The bundled `model_variants.csv` is used only as
metadata for the generated website upload CSV.

Useful rubric columns:

| Column | Required | Notes |
|---|---:|---|
| `Rubric` | Yes | Scoring instructions sent to the judge model. |
| `What it measures` | No | Alternative to `Rubric`; combined with score-band columns. |
| `1-3 (Poor)` | No | Poor score-band guidance. |
| `4-6 (Adequate)` | No | Adequate score-band guidance. |
| `7-8 (Strong)` | No | Strong score-band guidance. |
| `9-10 (Excellent)` | No | Excellent score-band guidance. |
| `TESTID` | No | Matches a row from the source output workbook. |
| `Category` | No | Used when `TESTID` is blank. |
| `Criterion` | No | Used with `Category` when `TESTID` is blank. |
| `Prompt` | No | Fallback original prompt if the source workbook does not include one. |
| `Additional source information` | No | Fallback input material for the judge. |
| `Minimum Score` | No | Defaults to `1`. |
| `Maximum Score` | No | Defaults to `10`. |
| `Weight` | No | Used in weighted grade summaries. |
| `Enabled` | No | Defaults to yes. Use `no` to keep a rubric row but skip it. |

Use Dry Run to validate the three spreadsheets without making API calls or
needing a key.

Output:

- `grades.xlsx` live Excel grading results, refreshed while the run is active
- `prompt_output_grades.xlsx` with the source workbook plus `Grade Summary`,
  `Model Scores`, `Results`, `Consensus`, `AI Scores`, `Grades`, and
  `Skipped Outputs`
- `grades.jsonl`
- `grades.csv`
- `db_upload/model_variants_db_upload.csv` when the website
  `db/seeds/model_variants.csv` file is available
- `db_upload/model_variant_score_audit.csv` explaining which test IDs fed each
  website score column

When run from Swift Package Manager, the app creates a timestamped output folder
under `AI-Finder/outputs/prompt_grades/` unless another folder is selected. When
run from the packaged `.app`, the default output folder is
`~/Documents/Prompt Output Grader/outputs/prompt_grades/`.

The `Consensus` sheet averages judge scores for each `Test ID` and model,
excluding self-judging by default. The `Results` sheet then applies the
per-test weights from `Scoring Guide`, applies category weights from the
`Weights` sheet for the overall score, and ranks the tested models. Use
`--include-self-judging` if you need to keep self-judge rows in those
calculations.

For website uploads, the generated `model_variants_db_upload.csv` preserves the
existing seed metadata and writes rounded whole-number scores because
`script/validate_catalogue.rb` requires model variant scores to be integers
from 1 to 10. When the app can see this repository it passes
`--update-website-seed`, so `db/seeds/model_variants.csv` is updated directly;
then run `bin/rails db:seed` to apply those scores locally. When the repo is
not available, the app still writes the upload CSV under `db_upload/` using the
bundled seed metadata.
