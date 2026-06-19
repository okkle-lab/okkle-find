# Prompt output grading runner

This runner reads test outputs from the Model Eval Runner, grades each response
with one or more judge models, and writes:

- `grades.jsonl` for resumable raw grading results
- `grades.xlsx` for live Excel grading results while the run is active
- `grades.csv` for quick review
- `prompt_output_grades.xlsx` with the source workbook plus `Grade Summary`,
  `Model Scores`, `Grades`, and `Skipped Outputs`

## SwiftUI App

Build and launch the macOS app:

```bash
cd PromptGradeApp
swift run PromptGradeApp
```

Build the double-clickable macOS app bundle:

```bash
cd PromptGradeApp
./package_app.sh
open dist
```

Drop in:

- a test output workbook from the Model Eval Runner
- a grading model spreadsheet
- a rubric workbook

Choose an output folder and press Grade. Use Dry Run first to validate the
workbooks without making API calls.

## Test Output Workbook

Use `model_test_results.xlsx` or `responses.xlsx` from the Model Eval Runner.
The grading runner reads `Run Results` by default. It also scans the other
sheets in `model_test_results.xlsx` for the original prompt text and input
material using the prompt workbook headers.

## Grading Model Spreadsheet

Use the same model spreadsheet format as the Model Eval Runner. Enabled
text-capable rows become judge models. Image-only model rows are ignored.

## Rubric Workbook

The first sheet should contain one of these columns:

- `Rubric`
- `Scoring Rubric`
- `Scoring Guidance`
- `Grading Instructions`
- `What it measures`

Add `TESTID` to apply a rubric row to a specific prompt. If `TESTID` is blank,
the runner can match on `Category` and `Criterion`, then on `Category`, then on
a global row where all three are blank.

Optional columns include `Prompt`, `Additional source information`,
`Minimum Score`, `Maximum Score`, `Weight`, and `Enabled`.

For the model-testing rubric format, the runner combines `What it measures`
with the score-band columns `1-3 (Poor)`, `4-6 (Adequate)`, `7-8 (Strong)`,
and `9-10 (Excellent)` into the judge instructions.

## Dry Run

```bash
python3 script/prompt_output_grader.py \
  --results-workbook "/path/to/model_test_results.xlsx" \
  --models-workbook "/path/to/grading_models.xlsx" \
  --rubric-workbook "/path/to/rubric.xlsx" \
  --dry-run
```

## Run Grading

```bash
python3 script/prompt_output_grader.py \
  --results-workbook "/path/to/model_test_results.xlsx" \
  --models-workbook "/path/to/grading_models.xlsx" \
  --rubric-workbook "/path/to/rubric.xlsx"
```

Useful filters:

```bash
python3 script/prompt_output_grader.py --results-workbook "..." --models-workbook "..." --rubric-workbook "..." --only-tests W1,C1
python3 script/prompt_output_grader.py --results-workbook "..." --models-workbook "..." --rubric-workbook "..." --only-source-models gpt-5,claude-opus
python3 script/prompt_output_grader.py --results-workbook "..." --models-workbook "..." --rubric-workbook "..." --only-models judge-1,judge-2
python3 script/prompt_output_grader.py --results-workbook "..." --models-workbook "..." --rubric-workbook "..." --parallel-products
```

By default, source outputs without a matching rubric row are skipped. Use
`--allow-missing-rubric` to grade them with generic output-quality guidance.

The `Model Scores` sheet is the second sheet in the generated workbook. It
shows one row per tested/source model, each grader model's average score, and a
final numerical `Model Score` that averages those grader averages.
