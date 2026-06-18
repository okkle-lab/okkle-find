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

Inputs:

- Prompt spreadsheet: first sheet with `TESTID`, `Prompt`, and optional `Additional source information`.
- Model spreadsheet: first sheet with `Model ID`, plus optional `OpenRouter Model ID`, `Model Name`, `Provider`, `Capabilities`, and `Enabled`.
- API key: cloud providers need authentication. For the default text route, paste one OpenRouter key into the app.

Use Dry Run to validate both spreadsheets without making API calls or needing a key.

If OpenRouter returns HTTP 402 saying the request requires more credits or fewer
`max_tokens`, lower the app's Max Tokens value. The default is `1000`.

If OpenRouter returns HTTP 400 saying a model is not valid, add an
`OpenRouter Model ID` column with the exact slug from `https://openrouter.ai/models`.
For example, use `anthropic/claude-opus-4.8` instead of `claude-opus-4-8`.

Output:

- `responses.xlsx` live Excel results, refreshed while the run is active
- `model_test_results.xlsx`
- `responses.jsonl`
- `responses.csv`
- generated images under `images/<model-key>/`

When run from Swift Package Manager, the app creates a timestamped output folder
under `AI-Finder/outputs/model_tests/` unless another folder is selected. When
run from the packaged `.app`, the default output folder is
`~/Documents/Model Eval Runner/outputs/model_tests/`.
