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

Default spreadsheets:

- `Defaults/Model_Test_Prompts_for_Automation.xlsx`
- `Defaults/AI_model_variants.xlsx`

The app preselects these files on launch. Replace the files in `Defaults/` and
run `./package_app.sh` again to ship updated defaults.

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
- API key: cloud providers need authentication. For the default text route, paste one OpenRouter key into the app.
- Image generation: off by default. Turn on Image Generation and paste an
  OpenAI API key to run the bundled `gpt-image-2` image model row.
- Parallel Products: off by default. Turn it on to run different product lanes
  at the same time while keeping models within each product in series.

If your model spreadsheet contains only ChatGPT/OpenAI text rows and no
explicit provider settings, the runner uses direct OpenAI and only needs the
OpenAI key. Mixed-provider sheets keep blank text providers on OpenRouter.

Use Dry Run to validate both spreadsheets without making API calls or needing a key.

If OpenRouter returns HTTP 402 saying the request requires more credits or fewer
`max_tokens`, lower the app's Max Tokens value. The same app setting is sent as
`max_completion_tokens` for direct OpenAI text models. The default is `200`.
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

When run from Swift Package Manager, the app creates a timestamped output folder
under `AI-Finder/outputs/model_tests/` unless another folder is selected. When
run from the packaged `.app`, the default output folder is
`~/Documents/Model Eval Runner/outputs/model_tests/`.
