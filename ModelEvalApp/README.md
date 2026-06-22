# Model Eval App

macOS SwiftUI wrapper for `script/model_eval_runner.py`.

Run it from this folder:

```bash
swift run ModelEvalApp
```

Build a double-clickable macOS app:

```bash
./package_app.sh
open dist
```

This creates `dist/Model Eval Runner.app` with the Python runner bundled inside
the app, so users do not need to install `openpyxl` or use Terminal.

Download a packaged build:

- [Model Eval Runner 1.0.0](https://github.com/okkle-lab/AI-Finder/releases/tag/model-eval-runner-v1.0.0)
- Direct zip: [Model.Eval.Runner-1.0.0-mac.zip](https://github.com/okkle-lab/AI-Finder/releases/download/model-eval-runner-v1.0.0/Model.Eval.Runner-1.0.0-mac.zip)

`dist/` is a local packaging output and is intentionally ignored by Git. To use
the app on another computer, download the release zip or rebuild locally with
`./package_app.sh`.

Default spreadsheets:

- `Defaults/Model_Test_Prompts_for_Automation.xlsx`
- `Defaults/AI_model_variants.xlsx`
- `Defaults/Model_Testing_Rubric.xlsx`
- `Defaults/model_variants.csv`

The app preselects these files on launch. Replace the files in `Defaults/` and
run `./package_app.sh` again to ship updated defaults. The package script also
refreshes the bundled rubric from `PromptGradeApp/Defaults/Model_Testing_Rubric.xlsx`.

Versioning:

- `VERSION` is the app version source of truth.
- `./package_app.sh` writes `VERSION` into the packaged app's `Info.plist` and
  creates both `Model Eval Runner-<version>-mac.zip` and
  `Model Eval Runner-mac.zip`.
- Set `BUILD_NUMBER=2 ./package_app.sh` when producing another build of the
  same version.
- Add release notes to the root `CHANGELOG.md` whenever `VERSION` changes.

Inputs:

- Prompt spreadsheet: first sheet with `TESTID`, `Prompt`, and optional `Additional source information`.
- Model spreadsheet: first sheet with `Model ID`, plus optional `OpenRouter Model ID`, `Model Name`, `Provider`, `Capabilities`, and `Enabled`.
- Rubric workbook: optional but preselected. The runner verifies that selected
  prompt `Test ID` values have enabled rubric rows before it spends API calls.
- API key: cloud providers need authentication. For the default text route, paste one OpenRouter key into the app.
- Image generation: off by default. Turn on Image Generation and paste an
  OpenAI API key to run the bundled `gpt-image-2` image model row.
- GitHub Models / Copilot-style tests: paste a GitHub token with `models:read`
  into the GitHub Models Token field, then enable a workbook row that uses
  `Provider=github_models` and a GitHub Models catalog ID such as
  `openai/gpt-4.1`.
- Parallel Products: off by default. Turn it on to run different product lanes
  at the same time while keeping models within each product in series.
- Reuse Matching Results: on by default. The runner scans previous output
  folders and reuses successful rows when the same model, `Test ID`, prompt
  text/input material, and rubric row were already tested.
- Only Changed Prompts: on by default with result reuse. The runner only calls
  the API for prompt `Test ID` values whose prompt/input content is new or
  changed compared with previous model-test workbooks, so it does not backfill
  old missing or errored pairs unless you turn this off.
- Only Test IDs: optional comma-separated prompt IDs to run. Use the Failed
  preset to fill the token-cap rerun question set.
- Reasoning Effort: optional OpenRouter override. Use `None` or `Minimal` when
  the 4000-token app cap still produces token-budget warnings.
- Skip Already Scored: fallback mode for when result reuse is off. It uses
  `model_variants.csv` to skip model keys that already have website scores.

The bundled model workbook includes disabled catalogue rows for comparable
coding products such as GitHub Copilot, Claude Code, OpenAI Codex, Devin
Desktop, JetBrains Junie, Tabnine, Sourcegraph Amp, and Cursor. Their
`best_for` notes capture strengths and tradeoffs, while disabled rows avoid
requiring product-specific credentials during normal benchmark runs.

If your model spreadsheet contains only ChatGPT/OpenAI text rows and no
explicit provider settings, the runner uses direct OpenAI and only needs the
OpenAI key. Mixed-provider sheets keep blank text providers on OpenRouter.

Use Dry Run to validate the prompt/model spreadsheets, rubric coverage, and
result reuse plan without making API calls or needing a key. When result reuse
finds matching prior rows, those rows are copied into the new workbook and only
changed or missing prompt/model/rubric pairs are sent to the API.

If OpenRouter returns HTTP 402 saying the request requires more credits or fewer
`max_tokens`, lower the app's Max Tokens value. The same app setting is sent as
`max_completion_tokens` for direct OpenAI text models. The default is `1000`.
Direct OpenAI text requests omit custom `temperature` by default because some
newer OpenAI models only accept the provider default.

If OpenAI returns HTTP 429, your account hit a rate, usage, or budget limit.
The runner now shows the provider's message and skips the rest of that model
after three rate-limit failures so the run can move on.

If OpenRouter returns HTTP 400 saying a model is not valid, add an
`OpenRouter Model ID` column with the exact slug from `https://openrouter.ai/models`.
For example, use `anthropic/claude-opus-4.8` instead of `claude-opus-4-8`.

Output:

- `responses.xlsx` live Excel results, refreshed while the run is active
- `model_test_results.xlsx`
- `responses.jsonl`
- `responses.csv`
- generated images under `images/<model-key>/`

`responses.csv`, `responses.xlsx`, and the final workbook's `Run Results` sheet
show per-call prompt, completion, hidden reasoning-token, and total token counts
when the provider returns usage.
If a text response reaches the configured token cap and is blank or likely
truncated, the runner prints a `TOKEN WARNING` line and the app shows a warning
banner above the run log.

When run from Swift Package Manager, the app creates a timestamped output folder
under `AI-Finder/outputs/model_tests/` unless another folder is selected. When
run from the packaged `.app`, the default output folder is
`~/Documents/Model Eval Runner/outputs/model_tests/`.
