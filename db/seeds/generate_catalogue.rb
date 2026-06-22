# Regenerates db/seeds/ai_tool_catalogue_text_models.csv from the data below.
# Run with:  bin/rails runner db/seeds/generate_catalogue.rb
#
# This is a *starter* catalogue: real, well-known tools with reasonable but
# APPROXIMATE figures. Prices rot fast (see spec §9) — `last_verified` and
# `data_pricing_confidence` are honest about that. Curate before any launch.
require "csv"

HEADERS = %w[
  name provider website_url status last_verified data_pricing_confidence
  input_usd_per_m output_usd_per_m pricing_unit price_low_usd price_high_usd
  context_window api_free_tier consumer_free_app data_retention runs_locally
  privacy_label price_label ease_label why_this_one
  quality_score ease_score value_score categories
].freeze

VERIFIED = "2026-06-03"

# data_retention: none / optional / yes / unclear
# booleans expressed as yes/no
ROWS = [
  {
    name: "ChatGPT", provider: "OpenAI", website_url: "https://chatgpt.com",
    confidence: "medium", input: 2.5, output: 10, unit: "per 1M tokens",
    context: 128000, api_free: "no", free_app: "yes", retention: "optional", local: "no",
    privacy: "you can turn off chat history & training", price: "free tier; Plus is ~$20/mo",
    ease: "just open it and type", quality: 9, easy: 10, value: 8,
    why: "The default all-rounder for everyday AI work: strong writing, coding, summarisation, file handling, and a generous free tier, with model choices from fast/cheap to flagship.",
    cats: "chat-assistant,write-things,summarize,code"
  },
  {
    name: "Claude", provider: "Anthropic", website_url: "https://claude.ai",
    confidence: "medium", input: 3, output: 15, unit: "per 1M tokens",
    context: 200000, api_free: "no", free_app: "yes", retention: "optional", local: "no",
    privacy: "doesn't train on your chats by default", price: "free tier; Pro is ~$20/mo",
    ease: "just open it and type", quality: 9, easy: 9, value: 8,
    why: "Especially good at longer writing careful reasoning and working through big documents in one go.",
    cats: "chat-assistant,write-things,summarize,code"
  },
  {
    name: "Google Gemini", provider: "Google", website_url: "https://gemini.google.com",
    confidence: "medium", input: 1.25, output: 5, unit: "per 1M tokens",
    context: 1000000, api_free: "yes", free_app: "yes", retention: "optional", local: "no",
    privacy: "review activity settings to limit data use", price: "free tier; Advanced via Google One",
    ease: "just open it and type", quality: 8, easy: 9, value: 8,
    why: "Handy if you live in Gmail Docs and Android. Huge context window for very long inputs.",
    cats: "chat-assistant,write-things,research,summarize"
  },
  {
    name: "Microsoft Copilot", provider: "Microsoft", website_url: "https://copilot.microsoft.com",
    confidence: "low", input: nil, output: nil, unit: nil,
    context: nil, api_free: "no", free_app: "yes", retention: "optional", local: "no",
    privacy: "enterprise data protections on work accounts", price: "free; Pro is ~$20/mo",
    ease: "built into Windows and Office", quality: 7, easy: 9, value: 7,
    why: "Convenient if you already use Windows and Microsoft 365 — it sits right inside the apps you have.",
    cats: "chat-assistant,write-things,summarize"
  },
  {
    name: "Perplexity", provider: "Perplexity AI", website_url: "https://perplexity.ai",
    confidence: "low", input: nil, output: nil, unit: nil,
    context: nil, api_free: "no", free_app: "yes", retention: "optional", local: "no",
    privacy: "can opt out of data used for training", price: "free; Pro is ~$20/mo",
    ease: "works like a smarter search engine", quality: 8, easy: 9, value: 8,
    why: "Best when you want answers with sources cited — it searches the live web and shows where facts came from.",
    cats: "research,chat-assistant,summarize"
  },
  {
    name: "GitHub Copilot", provider: "GitHub", website_url: "https://github.com/features/copilot",
    confidence: "medium", input: nil, output: nil, unit: nil,
    context: nil, api_free: "no", free_app: "yes", retention: "optional", local: "no",
    privacy: "code suggestions not retained on paid tiers", price: "free tier; Pro is ~$10/mo",
    ease: "installs into your code editor", quality: 8, easy: 7, value: 8,
    why: "The most established coding helper — autocompletes code right inside VS Code and other editors.",
    cats: "code"
  },
  {
    name: "Cursor", provider: "Anysphere", website_url: "https://cursor.com",
    confidence: "low", input: nil, output: nil, unit: nil,
    context: nil, api_free: "no", free_app: "yes", retention: "optional", local: "no",
    privacy: "privacy mode keeps code off their servers", price: "free tier; Pro is ~$20/mo",
    ease: "a full code editor — some setup", quality: 9, easy: 6, value: 8,
    why: "An AI-first code editor that understands your whole project. A favourite of serious developers.",
    cats: "code"
  },
  {
    name: "Whisper", provider: "OpenAI", website_url: "https://github.com/openai/whisper",
    confidence: "high", input: nil, output: nil, unit: nil,
    context: nil, api_free: "yes", free_app: "no", retention: "none", local: "yes",
    privacy: "runs on your own machine — nothing leaves it", price: "free and open source",
    ease: "a bit techy: needs the command line", quality: 9, easy: 3, value: 10,
    why: "Open-source transcription you can run entirely offline. Nothing is uploaded — ideal for sensitive interviews.",
    cats: "audio-to-text"
  },
  {
    name: "MacWhisper", provider: "Good Snooze", website_url: "https://goodsnooze.gumroad.com/l/macwhisper",
    confidence: "low", input: nil, output: nil, unit: nil,
    context: nil, api_free: "no", free_app: "yes", retention: "none", local: "yes",
    privacy: "transcribes locally on your Mac", price: "free tier; Pro is a one-off ~$60",
    ease: "friendly app — drag in a file", quality: 8, easy: 9, value: 9,
    why: "Whisper's accuracy wrapped in a simple Mac app. Local transcription without touching the command line.",
    cats: "audio-to-text"
  },
  {
    name: "Otter.ai", provider: "Otter.ai", website_url: "https://otter.ai",
    confidence: "low", input: nil, output: nil, unit: nil,
    context: nil, api_free: "no", free_app: "yes", retention: "yes", local: "no",
    privacy: "stores your recordings on their servers", price: "free tier; Pro is ~$17/mo",
    ease: "polished app — records meetings live", quality: 7, easy: 9, value: 7,
    why: "Great for live meeting notes and speaker labels. Note it keeps your recordings in the cloud.",
    cats: "audio-to-text,summarize"
  },
  {
    name: "Llama", provider: "Meta", website_url: "https://llama.com",
    confidence: "high", input: nil, output: nil, unit: nil,
    context: 128000, api_free: "yes", free_app: "no", retention: "none", local: "yes",
    privacy: "open weights — run it fully offline", price: "free and open source",
    ease: "needs a runner like Ollama to use", quality: 8, easy: 4, value: 10,
    why: "Meta's open model family. The backbone of most local-AI setups when you want full control and privacy.",
    cats: "chat-assistant,write-things,code"
  },
  {
    name: "Mistral Le Chat", provider: "Mistral AI", website_url: "https://chat.mistral.ai",
    confidence: "medium", input: 2, output: 6, unit: "per 1M tokens",
    context: 128000, api_free: "no", free_app: "yes", retention: "optional", local: "no",
    privacy: "EU-based with opt-out of training", price: "generous free tier; Pro ~$15/mo",
    ease: "just open it and type", quality: 7, easy: 9, value: 9,
    why: "A fast capable European option. Many of its models are also open-weight if you want to self-host later.",
    cats: "chat-assistant,write-things,code"
  },
  {
    name: "DeepSeek", provider: "DeepSeek", website_url: "https://deepseek.com",
    confidence: "low", input: 0.27, output: 1.1, unit: "per 1M tokens",
    context: 128000, api_free: "no", free_app: "yes", retention: "yes", local: "no",
    privacy: "data stored on servers in China", price: "free app; very cheap API",
    ease: "just open it and type", quality: 8, easy: 8, value: 9,
    why: "Strong reasoning and coding at a remarkably low price. Check the data policy before sensitive use.",
    cats: "chat-assistant,code,write-things"
  },
  {
    name: "Ollama", provider: "Ollama", website_url: "https://ollama.com",
    confidence: "high", input: nil, output: nil, unit: nil,
    context: nil, api_free: "yes", free_app: "yes", retention: "none", local: "yes",
    privacy: "everything runs and stays on your computer", price: "free and open source",
    ease: "a bit techy to set up", quality: 8, easy: 5, value: 10,
    why: "The easiest way to download and run open models locally. Free private and offline once it's set up.",
    cats: "chat-assistant,code,write-things"
  },
  {
    name: "LM Studio", provider: "LM Studio", website_url: "https://lmstudio.ai",
    confidence: "high", input: nil, output: nil, unit: nil,
    context: nil, api_free: "yes", free_app: "yes", retention: "none", local: "yes",
    privacy: "models run locally — nothing uploaded", price: "free for personal use",
    ease: "friendly app for running local models", quality: 7, easy: 7, value: 9,
    why: "A point-and-click app for running open models on your own machine — local AI without the terminal.",
    cats: "chat-assistant,write-things,code"
  },
  {
    name: "NotebookLM", provider: "Google", website_url: "https://notebooklm.google.com",
    confidence: "low", input: nil, output: nil, unit: nil,
    context: nil, api_free: "no", free_app: "yes", retention: "optional", local: "no",
    privacy: "says it doesn't train on your uploads", price: "free",
    ease: "upload your docs and ask away", quality: 8, easy: 9, value: 9,
    why: "Point it at your own documents and it answers only from them with citations. Excellent for research and study.",
    cats: "research,summarize"
  },
  {
    name: "DeepL", provider: "DeepL", website_url: "https://deepl.com",
    confidence: "medium", input: nil, output: nil, unit: nil,
    context: nil, api_free: "yes", free_app: "yes", retention: "optional", local: "no",
    privacy: "Pro deletes text after translating", price: "free tier; Pro from ~$9/mo",
    ease: "paste text and pick a language", quality: 9, easy: 10, value: 8,
    why: "Widely considered the most natural-sounding translator — noticeably better than the free generic ones.",
    cats: "translate"
  },
  {
    name: "Grammarly", provider: "Grammarly", website_url: "https://grammarly.com",
    confidence: "low", input: nil, output: nil, unit: nil,
    context: nil, api_free: "no", free_app: "yes", retention: "yes", local: "no",
    privacy: "processes your text on their servers", price: "free tier; Premium from ~$12/mo",
    ease: "works everywhere you type", quality: 7, easy: 10, value: 7,
    why: "Catches grammar and tone issues as you write across email docs and the web. The gentle everyday writing helper.",
    cats: "write-things"
  },
  {
    name: "Poe", provider: "Quora", website_url: "https://poe.com",
    confidence: "low", input: nil, output: nil, unit: nil,
    context: nil, api_free: "no", free_app: "yes", retention: "optional", local: "no",
    privacy: "depends on the underlying model you pick", price: "free tier; Pro is ~$20/mo",
    ease: "one app many AI models", quality: 7, easy: 9, value: 8,
    why: "Lets you try many different AI models in one place — useful when you're not sure which one suits you.",
    cats: "chat-assistant,write-things"
  },
  {
    name: "DeepGram", provider: "Deepgram", website_url: "https://deepgram.com",
    confidence: "medium", input: nil, output: nil, unit: "per audio hour",
    context: nil, api_free: "yes", free_app: "no", retention: "optional", local: "no",
    price_low: 0.26, price_high: 0.46,
    privacy: "can request no data retention on paid plans", price: "free credits; then ~$0.26+/audio hour",
    ease: "developer API — needs coding", quality: 8, easy: 3, value: 8,
    why: "Fast accurate transcription built for developers. Reach for this when you're wiring transcription into an app.",
    cats: "audio-to-text"
  },
  {
    name: "Cohere Command", provider: "Cohere", website_url: "https://cohere.com",
    confidence: "low", input: 0.5, output: 1.5, unit: "per 1M tokens",
    context: 128000, api_free: "yes", free_app: "no", retention: "optional", local: "no",
    privacy: "business-focused with opt-out controls", price: "free trial key; usage-based API",
    ease: "developer API — needs coding", quality: 7, easy: 4, value: 7,
    why: "A business-oriented text model with strong search and retrieval features. Aimed at developers and teams.",
    cats: "write-things,summarize,code"
  },
  {
    name: "Jasper", provider: "Jasper", website_url: "https://jasper.ai",
    confidence: "low", input: nil, output: nil, unit: nil,
    context: nil, api_free: "no", free_app: "no", retention: "yes", local: "no",
    price_low: 39, price_high: 59,
    privacy: "stores content on their platform", price: "paid only — from ~$39/mo",
    ease: "templates for marketing copy", quality: 7, easy: 8, value: 5,
    why: "Built for marketing teams: on-brand campaigns blog posts and ads with templates. Paid only, no free tier.",
    cats: "write-things"
  }
].freeze

CSV.open(File.expand_path("ai_tool_catalogue_text_models.csv", __dir__), "w") do |csv|
  csv << HEADERS
  ROWS.each do |r|
    csv << [
      r[:name], r[:provider], r[:website_url], "live", VERIFIED, r[:confidence],
      r[:input], r[:output], r[:unit], r[:price_low], r[:price_high],
      r[:context], r[:api_free], r[:free_app], r[:retention], r[:local],
      r[:privacy], r[:price], r[:ease], r[:why],
      r[:quality], r[:easy], r[:value], r[:cats]
    ]
  end
end

puts "Wrote #{ROWS.size} tools to db/seeds/ai_tool_catalogue_text_models.csv"
