# Automated model evaluation runner

This runner reads a prompt spreadsheet, reads a model spreadsheet, runs eligible tests against configured chat/image models, and writes:

- `responses.jsonl` for resumable raw results
- `responses.xlsx` for live Excel results while the run is active
- `responses.csv` for quick review
- `model_test_results.xlsx` with the original prompt library plus `Run Summary`, `Run Results`, and `Skipped Tests`
- generated image files under `images/<model-key>/` inside the run output directory

The CSV and workbook `Run Results` sheet include per-call `prompt_tokens`,
`completion_tokens`, hidden `reasoning_tokens`, and `total_tokens` columns when
the provider reports usage.
When a text response reaches the configured token cap and is blank or likely
truncated, the runner prints a `TOKEN WARNING` line. The SwiftUI app surfaces
those warnings in a banner above the run log.

By default it skips image-generation rows, evidence-review/privacy/security/enterprise rows, and manual reviewer rows. Use `--include-image` when you want to run image-generation tests too.

## SwiftUI App

Build and launch the macOS app:

```bash
cd ModelEvalApp
swift run ModelEvalApp
```

Build the double-clickable macOS app bundle:

```bash
cd ModelEvalApp
./package_app.sh
open dist
```

The packaged app bundles the Python runner and spreadsheet dependencies. Users
can launch `dist/Model Eval Runner.app` directly, or share
`dist/Model Eval Runner-mac.zip`.

Packaged builds are published as GitHub Release assets:

- [Model Eval Runner 1.0.0](https://github.com/okkle-lab/AI-Finder/releases/tag/model-eval-runner-v1.0.0)
- Direct zip: [Model.Eval.Runner-1.0.0-mac.zip](https://github.com/okkle-lab/AI-Finder/releases/download/model-eval-runner-v1.0.0/Model.Eval.Runner-1.0.0-mac.zip)

`ModelEvalApp/dist/` is intentionally ignored by Git because it contains local
build artifacts. Other computers should download the release zip or rebuild the
bundle locally with `./package_app.sh`.

Default spreadsheets live in `ModelEvalApp/Defaults/`:

- `Model_Test_Prompts_for_Automation.xlsx`
- `AI_model_variants.xlsx`
- `Model_Testing_Rubric.xlsx`
- `model_variants.csv`

The SwiftUI app preselects those files on launch. To update the shipped
defaults, replace the files in `ModelEvalApp/Defaults/` and rerun
`./package_app.sh`. The package script refreshes the bundled rubric from
`PromptGradeApp/Defaults/Model_Testing_Rubric.xlsx`.

The app version is stored in `ModelEvalApp/VERSION`. The package script writes
that version into the macOS bundle metadata and produces a versioned zip
alongside the latest zip. Release notes live in the root `CHANGELOG.md`.

Drop in:

- a prompt spreadsheet
- a model spreadsheet
- an optional rubric workbook used as a preflight `Test ID` coverage check

Choose an output folder and press Run. Use Dry Run to validate the spreadsheets,
rubric coverage, and result reuse plan without API calls. Reuse Matching
Results is on by default in the app; it scans previous model-test output
folders and reuses successful rows when the same model, `Test ID`, prompt
text/input material, and rubric row were already tested. Only Changed Prompts
is also on by default, so the runner only calls the API for prompt `Test ID`
values whose prompt/input content is new or changed compared with previous
model-test workbooks. Turn that off when you intentionally want to backfill old
missing or errored pairs. The older Skip Already Scored mode is still available
as a fallback when result reuse is off.
Use the Only Test IDs field to run a specific comma-separated set of prompt
questions. The Failed preset fills the token-cap rerun question set and passes
it through to the runner as `--only-tests`.
If selected models keep hitting the 4000-token app cap, set Reasoning Effort to
`None` or `Minimal`; the app passes that to OpenRouter as `--reasoning-effort`.

Cloud model providers still require an API key. With the default model spreadsheet path, the app expects one OpenRouter key for text models. Image models usually need an OpenAI key unless your model spreadsheet points them somewhere else. GitHub Models rows need a GitHub token with `models:read` in `GITHUB_MODELS_TOKEN`.
Image generation is supported but off by default in the SwiftUI app to avoid
accidental image spend. Turn on Image Generation and provide `OPENAI_API_KEY`
to run the bundled `gpt-image-2` row.
The bundled model workbook also includes disabled coding-product rows for
Copilot-style alternatives. These rows record strengths and tradeoffs in
`best_for`, but stay disabled unless you intentionally wire a provider route
and credential.
Parallel Products is also off by default. Turn it on to run different product
lanes at the same time while keeping each lane's models and tests in series.

From the CLI, use the same scored-model filter with:

```bash
python3 script/model_eval_runner.py \
  --workbook ModelEvalApp/Defaults/Model_Test_Prompts_for_Automation.xlsx \
  --models-workbook ModelEvalApp/Defaults/AI_model_variants.xlsx \
  --website-seed-csv db/seeds/model_variants.csv \
  --skip-scored-models \
  --dry-run
```

## Prompt Spreadsheet

The first sheet should contain these columns:

| Column | Required | Notes |
|---|---:|---|
| `TESTID` | Yes | IDs starting `IG`, `IMG`, or `IMAGE` are routed as image-generation tests when image generation is enabled. |
| `Prompt` | Yes | The benchmark prompt sent to the model. |
| `Additional source information` | No | Extra source text, transcript, product requirements, or other material appended to the prompt. |

The runner also still accepts the older workbook headers, including `Test ID`, `Benchmark Prompt`, and `Input Material`.

## Model Spreadsheet

The first sheet should contain at least:

| Column | Required | Notes |
|---|---:|---|
| `Model ID` | Yes | Provider model string, such as an OpenRouter model ID or an OpenAI image model ID. |
| `OpenRouter Model ID` | No | Preferred for OpenRouter runs when your catalogue `Model ID` is not the exact OpenRouter slug. |
| `Model Name` | No | Friendly name shown in output. |
| `Provider` | No | Defaults to `openrouter` for text models and `openai_images` for image models. |
| `Capabilities` | No | `text`, `image`, or `text,image`. Defaults to `text`. |
| `Enabled` | No | Defaults to yes. Use `no` to keep a row in the sheet but skip it. |
| `Base URL` | No | Optional provider endpoint override. |
| `API Key Env` | No | Optional API-key environment variable override. |
| `Provider Type` | No | Optional: `openai_compatible` or `openai_image_generation`. |

For mixed model sheets, blank text-model providers default to OpenRouter. If the
model sheet contains only ChatGPT/OpenAI text rows and no explicit provider
settings, the runner defaults those rows to direct OpenAI and uses
`model_id_string` values such as `gpt-5.5`, so only `OPENAI_API_KEY` is needed.
You can always make routing explicit with `Provider=openai` or
`Provider=openrouter`.

Models are routed by `Capabilities`:

- `["text"]` models run the text prompts.
- `["image"]` models run the image prompts.
- `["text", "image"]` or `["both"]` can be used for a provider/model entry that supports both paths.

## Setup

Set the relevant API key:

```bash
export OPENROUTER_API_KEY="..."
export OPENAI_API_KEY="..."
export GITHUB_MODELS_TOKEN="..."
```

In the SwiftUI app, paste the same keys into the API key fields instead of exporting them in Terminal.

GitHub Copilot's management REST API is not a general prompt-completion API.
For automated prompt tests, use GitHub Models inference with
`Provider=github_models`, `Provider Type=openai_compatible`,
`Base URL=https://models.github.ai`, `API Key Env=GITHUB_MODELS_TOKEN`, and a
catalog model ID such as `openai/gpt-4.1`.

If you use a local OpenAI-compatible server that does not require authentication, add a `Provider` value such as `local`, set `Base URL`, and leave `API Key Env` blank in the model spreadsheet.

If OpenRouter returns HTTP 402 saying a request requires more credits or fewer
`max_tokens`, lower the SwiftUI app's Max Tokens value or pass `--max-tokens`
on the CLI. The app defaults to `200`.

If OpenAI or another provider returns HTTP 429, the account has hit a rate,
usage, or budget limit. The runner preserves the provider's error message,
honours retry headers when present, and skips the rest of a model after three
rate-limit failures by default. Use `--rate-limit-skip-after 0` to keep trying
every selected pair, or lower `--max-tokens` / test fewer prompts while
checking account limits.

If OpenRouter returns HTTP 400 saying a model is not valid, the spreadsheet is
using a catalogue/internal model ID rather than an OpenRouter slug. Add an
`OpenRouter Model ID` column with the exact slug from `https://openrouter.ai/models`.

The script needs `openpyxl`:

```bash
python3 -m pip install openpyxl
```

## Dry run

Use a dry run first. It shows which workbook rows will be automated and which will be skipped.

```bash
python3 script/model_eval_runner.py \
  --workbook "/path/to/prompts.xlsx" \
  --models-workbook "/path/to/models.xlsx" \
  --rubric-workbook "/path/to/rubric.xlsx" \
  --reuse-matching-results \
  --only-changed-tests \
  --history-dir "/path/to/previous/model_tests" \
  --dry-run
```

Result reuse writes `prompt_fingerprint`, `rubric_fingerprint`, and
`benchmark_fingerprint` metadata into new `responses.csv`, `responses.jsonl`,
and `Run Results` rows. Older runs created before this metadata existed can
still be reused when their adjacent `model_test_results.xlsx` contains matching
prompt text for the same `Test ID`; new runs use the explicit fingerprints.

## Run responses only

```bash
python3 script/model_eval_runner.py \
  --workbook "/path/to/prompts.xlsx" \
  --models-workbook "/path/to/models.xlsx"
```

## Include image generation

Enable one or more image-capable model entries in `config/model_eval_models.json`, then run:

```bash
python3 script/model_eval_runner.py \
  --workbook "/path/to/prompts.xlsx" \
  --models-workbook "/path/to/models.xlsx" \
  --include-image
```

The runner saves generated images to the run output directory and records local file paths in `responses.csv` and the `Run Results` workbook sheet. Image outputs are left for downstream evaluation.

The bundled model workbook includes a `gpt-image-2` row configured with
`Provider=openai_images`, `Provider Type=openai_image_generation`,
`Capabilities=image`, and `API Key Env=OPENAI_API_KEY`. OpenAI may require
account or organization verification for GPT Image models.

The current workbook's `IG4` row is treated as an image-editing prompt but has
no source image. The runner skips it until `Input Material` contains a local
source image path.

## Useful filters

Run only a few prompts while testing:

```bash
python3 script/model_eval_runner.py --workbook "..." --models-workbook "..." --only-tests W1,C1 --limit 2
```

Run only selected models:

```bash
python3 script/model_eval_runner.py --workbook "..." --models-workbook "..." --only-models model_01,model_07
```

Run different product lanes concurrently:

```bash
python3 script/model_eval_runner.py --workbook "..." --models-workbook "..." --parallel-products
```

For OpenRouter model IDs, the product lane is based on the slug before `/`,
such as `anthropic/...` or `openai/...`. Direct OpenAI text and image rows share
the `OpenAI` lane. Use `--product-workers 2` to cap how many lanes run at once.
Dry runs print the lane plan without making API calls.

Include evidence-review rows if you later want to capture reviewer notes through the same output format:

```bash
python3 script/model_eval_runner.py --workbook "..." --models-workbook "..." --include-evidence --include-manual-review
```
