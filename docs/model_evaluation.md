# Automated model evaluation runner

This runner reads a prompt spreadsheet, reads a model spreadsheet, runs eligible tests against configured chat/image models, and writes:

- `responses.jsonl` for resumable raw results
- `responses.xlsx` for live Excel results while the run is active
- `responses.csv` for quick review
- `model_test_results.xlsx` with the original prompt library plus `Run Summary`, `Run Results`, and `Skipped Tests`
- generated image files under `images/<model-key>/` inside the run output directory

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

Drop in:

- a prompt spreadsheet
- a model spreadsheet

Choose an output folder and press Run. Use Dry Run to validate the spreadsheets without API calls.

Cloud model providers still require an API key. With the default model spreadsheet path, the app expects one OpenRouter key for text models. Image models usually need an OpenAI key unless your model spreadsheet points them somewhere else.

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

Models are routed by `Capabilities`:

- `["text"]` models run the text prompts.
- `["image"]` models run the image prompts.
- `["text", "image"]` or `["both"]` can be used for a provider/model entry that supports both paths.

## Setup

Set the relevant API key:

```bash
export OPENROUTER_API_KEY="..."
export OPENAI_API_KEY="..."
```

In the SwiftUI app, paste the same keys into the API key fields instead of exporting them in Terminal.

If you use a local OpenAI-compatible server that does not require authentication, add a `Provider` value such as `local`, set `Base URL`, and leave `API Key Env` blank in the model spreadsheet.

If OpenRouter returns HTTP 402 saying a request requires more credits or fewer
`max_tokens`, lower the SwiftUI app's Max Tokens value or pass `--max-tokens`
on the CLI. The app defaults to `1000`.

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
  --dry-run
```

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

The runner saves generated images to the run output directory and records local file paths in `responses.csv` and the `Run Results` workbook sheet. Image outputs are left unscored by the judge model; score them manually in the workbook.

The current workbook's `IG4` row is an image-editing prompt but has no source image. The runner skips it until `Input Material` contains a local source image path.

## Run and auto-score

Auto-scoring still uses a judge model from `config/model_eval_models.example.json` / JSON config. The SwiftUI app currently leaves scoring out so the app only needs the two spreadsheets.

```bash
python3 script/model_eval_runner.py \
  --workbook "/path/to/prompts.xlsx" \
  --models-workbook "/path/to/models.xlsx" \
  --config config/model_eval_models.json \
  --score
```

The judge returns a 1-10 quality score and short reasoning for each model response. Human review is still recommended for close calls, current-web shopping prompts, and anything where sources need checking.

## Useful filters

Run only a few prompts while testing:

```bash
python3 script/model_eval_runner.py --workbook "..." --models-workbook "..." --only-tests W1,C1 --limit 2
```

Run only selected models:

```bash
python3 script/model_eval_runner.py --workbook "..." --models-workbook "..." --only-models model_01,model_07
```

Include evidence-review rows if you later want to capture reviewer notes through the same output format:

```bash
python3 script/model_eval_runner.py --workbook "..." --models-workbook "..." --include-evidence --include-manual-review
```
