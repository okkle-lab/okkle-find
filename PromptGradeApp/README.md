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

This folder is intentionally separate from `ModelEvalApp/Defaults/`, so the
grading app can use a smaller, cheaper judge-model lineup without changing the
model testing app. The app preselects the bundled grading model workbook and
rubric workbook on launch.

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
  `Model Scores`, `Grades`, and `Skipped Outputs`
- `grades.jsonl`
- `grades.csv`

When run from Swift Package Manager, the app creates a timestamped output folder
under `AI-Finder/outputs/prompt_grades/` unless another folder is selected. When
run from the packaged `.app`, the default output folder is
`~/Documents/Prompt Output Grader/outputs/prompt_grades/`.

The `Model Scores` sheet is the second sheet in the generated workbook. It
shows one row per tested model, per-grader average columns, and a final
numerical `Model Score` that averages the grader averages.
