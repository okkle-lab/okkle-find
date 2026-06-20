require "csv"
require "json"
require "net/http"
require "uri"

OUTPUT_PATH = Rails.root.join("docs/pricing_enrichment_2026-06-20.csv")
OPENROUTER_MODELS_URL = "https://openrouter.ai/api/v1/models"

OPENROUTER_MODEL_IDS = {
  ["ChatGPT", "GPT-5.4 Nano"] => "openai/gpt-5.4-nano",
  ["Claude", "Claude Fable 5"] => "anthropic/claude-fable-5",
  ["Claude", "Claude Opus 4.8"] => "anthropic/claude-opus-4.8",
  ["Claude", "Claude Sonnet 4.6"] => "anthropic/claude-sonnet-4.6",
  ["Claude", "Claude Haiku 4.5"] => "anthropic/claude-haiku-4.5",
  ["DeepSeek", "DeepSeek V4 Pro"] => "deepseek/deepseek-v4-pro",
  ["DeepSeek", "DeepSeek V4 Flash"] => "deepseek/deepseek-v4-flash",
  ["Llama", "Llama 4 Maverick"] => "meta-llama/llama-4-maverick",
  ["Llama", "Llama 4 Scout"] => "meta-llama/llama-4-scout",
  ["Perplexity", "Sonar Deep Research"] => "perplexity/sonar-deep-research",
  ["Qwen", "Qwen3.7 Max"] => "qwen/qwen3.7-max",
  ["Qwen", "Qwen3 Coder Plus"] => "qwen/qwen3-coder-plus",
  ["Moonshot Kimi", "Kimi K2.7 Code"] => "moonshotai/kimi-k2.7-code",
  ["Z.ai GLM", "GLM 5.2"] => "z-ai/glm-5.2",
  ["MiniMax", "MiniMax M3"] => "minimax/minimax-m3",
  ["AI21 Jamba", "Jamba Large 1.7"] => "ai21/jamba-large-1.7"
}.freeze

OFFICIAL_API_PRICES = {
  ["ChatGPT", "GPT-5.5"] => {
    input: 5, output: 30, source: "https://openai.com/api/pricing/",
    confidence: "high", matched: "gpt-5.5"
  },
  ["ChatGPT", "GPT-5.4"] => {
    input: 2.5, output: 15, source: "https://openai.com/api/pricing/",
    confidence: "high", matched: "gpt-5.4"
  },
  ["Google Gemini", "Gemini 3.1 Pro (preview)"] => {
    input: 2, output: 12, source: "https://ai.google.dev/gemini-api/docs/pricing",
    confidence: "high", matched: "gemini-3.1-pro-preview",
    notes: "Standard tier for prompts up to 200k tokens."
  },
  ["Google Gemini", "Gemini 3.5 Flash"] => {
    input: 1.5, output: 9, source: "https://ai.google.dev/gemini-api/docs/pricing",
    confidence: "high", matched: "gemini-3.5-flash"
  },
  ["Google Gemini", "Gemini 3.1 Flash-Lite"] => {
    input: 0.25, output: 1.5, source: "https://ai.google.dev/gemini-api/docs/pricing",
    confidence: "high", matched: "gemini-3.1-flash-lite"
  },
  ["Mistral Le Chat", "Mistral Large 3"] => {
    input: 0.5, output: 1.5, source: "https://mistral.ai/pricing/",
    confidence: "high", matched: "mistral-large-3"
  },
  ["Mistral Le Chat", "Mistral Medium 3.5"] => {
    input: 1.5, output: 7.5, source: "https://mistral.ai/pricing/",
    confidence: "high", matched: "mistral-medium-3.5"
  },
  ["Perplexity", "Sonar Pro"] => {
    input: 3, output: 15, source: "https://docs.perplexity.ai/docs/getting-started/pricing",
    confidence: "high", matched: "sonar-pro",
    notes: "Token pricing only; search request fees can apply."
  },
  ["Cohere Command", "Command A"] => {
    input: 2.5, output: 10, source: "https://docs.cohere.com/docs/command-a",
    confidence: "high", matched: "command-a"
  },
  ["xAI Grok", "Grok 4.3"] => {
    input: 1.25, output: 2.5, source: "https://docs.x.ai/developers/models",
    confidence: "high", matched: "grok-4.3"
  },
  ["Amazon Nova", "Nova Premier"] => {
    input: 2.5, output: 12.5, source: "https://aws.amazon.com/nova/pricing/",
    confidence: "high", matched: "nova-premier-v1"
  },
  ["Amazon Nova", "Nova Pro"] => {
    input: 0.8, output: 3.2, source: "https://aws.amazon.com/nova/pricing/",
    confidence: "high", matched: "nova-pro-v1"
  }
}.freeze

USAGE_PRICES = {
  ["DeepGram", "DeepGram"] => {
    price: 0.0048, unit: "per audio minute",
    source: "https://deepgram.com/pricing", confidence: "high",
    notes: "Nova-3 monolingual pay-as-you-go pre-recorded rate; streaming and multilingual rates differ."
  }
}.freeze

SUBSCRIPTION_PRICES = {
  "ChatGPT" => {
    plan: "ChatGPT Plus", monthly: 20, source: "https://chatgpt.com/pricing/",
    confidence: "medium", notes: "Consumer plan; model access has usage limits and can vary by account/region."
  },
  "Claude" => {
    plan: "Claude Pro", monthly: 20, annual: 200, source: "https://support.claude.com/en/articles/11049762-choose-a-claude-plan",
    confidence: "high", notes: "Max plans are also available at higher monthly prices."
  },
  "Google Gemini" => {
    plan: "Google AI Pro", monthly: 19.99, source: "https://gemini.google/subscriptions/",
    confidence: "high", notes: "Consumer Gemini subscription; API billing is separate."
  },
  "Microsoft Copilot" => {
    plan: "Microsoft 365 Premium", monthly: 19.99, annual: 199.99,
    source: "https://www.microsoft.com/en-us/microsoft-365-copilot/pricing/individuals",
    confidence: "high", notes: "Current consumer bundle replacing/overlapping older Copilot Pro positioning."
  },
  "Perplexity" => {
    plan: "Perplexity Pro", monthly: 20, annual: 200, source: "https://www.perplexity.ai/enterprise/pricing",
    confidence: "high", notes: "Consumer Pro; API billing is separate."
  },
  "Cursor" => {
    plan: "Cursor Pro", monthly: 20, source: "https://cursor.com/pricing",
    confidence: "high", notes: "Includes higher limits and usage pools; model-specific cost attribution is not exposed."
  },
  "GitHub Copilot" => {
    plan: "GitHub Copilot Pro", monthly: 10, source: "https://github.com/features/copilot/plans",
    confidence: "high", notes: "Higher tiers include more credits and premium model access."
  },
  "Mistral Le Chat" => {
    plan: "Mistral Pro", monthly: 14.99, source: "https://mistral.ai/news/all-new-le-chat/",
    confidence: "medium", notes: "Le Chat is now Vibe; pricing page says Pro has higher limits."
  },
  "DeepL" => {
    plan: "DeepL Pro Individual", annualized_monthly: 8.74, source: "https://www.deepl.com/en/pro",
    confidence: "medium", notes: "Official page is region-sensitive; amount is the US annualized price surfaced by search."
  },
  "Grammarly" => {
    plan: "Grammarly Pro", monthly: 30, annual: 144, source: "https://support.grammarly.com/hc/en-us/articles/115000090011-How-much-does-Grammarly-Pro-cost",
    confidence: "high"
  },
  "Jasper" => {
    plan: "Jasper Pro", monthly: 69, annualized_monthly: 59, source: "https://www.jasper.ai/pricing",
    confidence: "high"
  },
  "Otter.ai" => {
    plan: "Otter Pro", monthly: 16.99, annualized_monthly: 8.33, source: "https://otter.ai/pricing",
    confidence: "high"
  },
  "Poe" => {
    plan: "Poe 10k points/day", annual: 49.99, annualized_monthly: 4.17, source: "https://poe.com/subscription_plans",
    confidence: "medium", notes: "Point-based pricing; higher point tiers are often required for heavy frontier-model use."
  },
  "xAI Grok" => {
    plan: "SuperGrok", monthly: 30, source: "https://x.ai/pricing",
    confidence: "high"
  },
  "NotebookLM" => {
    plan: "Free; NotebookLM Pro via Google AI Pro", monthly: 0, source: "https://notebooklm.google/plans",
    confidence: "medium", notes: "Free tier exists; paid higher limits are bundled through Google AI plans."
  },
  "Ollama" => {
    plan: "Free/local", monthly: 0, source: "https://ollama.com",
    confidence: "high", notes: "Hardware/electricity costs excluded."
  },
  "LM Studio" => {
    plan: "Free for personal use", monthly: 0, source: "https://lmstudio.ai",
    confidence: "medium", notes: "Hardware/electricity costs excluded."
  },
  "Whisper" => {
    plan: "Open source/local", monthly: 0, source: "https://github.com/openai/whisper",
    confidence: "high", notes: "Hardware/electricity costs excluded."
  },
  "Llama" => {
    plan: "Open model/local", monthly: 0, source: "https://www.llama.com",
    confidence: "medium", notes: "Hosted API costs vary by provider; OpenRouter token prices are listed separately."
  },
  "DeepSeek" => {
    plan: "Free app; API pay-as-you-go", monthly: 0, source: "https://www.deepseek.com",
    confidence: "medium"
  },
  "Qwen" => {
    plan: "Free app; API via OpenRouter", monthly: 0, source: "https://chat.qwen.ai",
    confidence: "medium"
  },
  "Moonshot Kimi" => {
    plan: "Free app; API via OpenRouter", monthly: 0, source: "https://kimi.moonshot.cn",
    confidence: "medium"
  },
  "Z.ai GLM" => {
    plan: "Free app; API via OpenRouter", monthly: 0, source: "https://z.ai",
    confidence: "medium"
  },
  "MiniMax" => {
    plan: "Free app; API via OpenRouter", monthly: 0, source: "https://www.minimax.io",
    confidence: "medium"
  },
  "MacWhisper" => {
    plan: "Free tier; Pro lifetime license", one_time: 60, source: "https://macwhisper.helpscoutdocs.com/article/40-macwhisper-whisper-transcription-difference",
    confidence: "low", notes: "One-time price is approximate from existing catalogue label; current storefront is dynamic."
  }
}.freeze

FREE_OR_USAGE_BASED_TOOLS = [
  "AI21 Jamba",
  "Amazon Nova",
  "Cohere Command",
  "DeepGram"
].freeze

HEADERS = %w[
  tool_name
  model_name
  model_id_string
  performance_score
  avg_total_tokens
  db_api_input_usd_per_m
  db_api_output_usd_per_m
  pulled_api_input_usd_per_m
  pulled_api_output_usd_per_m
  api_pricing_unit
  api_matched_model_id
  api_source_url
  api_confidence
  api_notes
  usage_price_usd
  usage_unit
  usage_source_url
  usage_confidence
  usage_notes
  api_blended_usd_per_m
  estimated_avg_call_cost_usd_blended
  estimated_api_performance_per_dollar
  estimated_api_cost_per_score_point_usd
  subscription_plan_name
  subscription_effective_monthly_usd
  subscription_monthly_usd
  subscription_annualized_monthly_usd
  subscription_annual_usd
  subscription_one_time_usd
  subscription_source_url
  subscription_confidence
  subscription_notes
  subscription_performance_per_monthly_dollar
  subscription_cost_per_score_point_usd
  audit_notes
].freeze

def openrouter_models
  uri = URI(OPENROUTER_MODELS_URL)
  response = Net::HTTP.get_response(uri)
  return {} unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body).fetch("data", []).to_h { |model| [model.fetch("id"), model] }
rescue JSON::ParserError, KeyError, SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => error
  warn "Could not fetch OpenRouter model data: #{error.class}: #{error.message}"
  {}
end

def decimal(value, places: nil)
  return nil if value.blank?

  number = value.to_f
  return format("%.#{places}f", number) if places

  number % 1 == 0 ? number.to_i.to_s : number.round(6).to_s
end

def per_token_to_per_million(value)
  return nil if value.blank?

  (value.to_f * 1_000_000).round(6)
end

def annualized_monthly(plan)
  return plan[:annualized_monthly] if plan[:annualized_monthly]
  return nil unless plan[:annual]

  (plan[:annual].to_f / 12).round(4)
end

def effective_monthly(plan)
  return nil unless plan

  plan[:monthly] || annualized_monthly(plan)
end

def score_number(variant)
  variant.verdict&.round(2)
end

openrouter_by_id = openrouter_models

rows = Tool.includes(:model_variants).order(:name).flat_map do |tool|
  tool.model_variants.ordered.map do |variant|
    key = [tool.name, variant.name]
    official_api = OFFICIAL_API_PRICES[key]
    openrouter_id = OPENROUTER_MODEL_IDS[key]
    openrouter_model = openrouter_by_id[openrouter_id]

    api_data =
      if official_api
        official_api
      elsif openrouter_model
        {
          input: per_token_to_per_million(openrouter_model.dig("pricing", "prompt")),
          output: per_token_to_per_million(openrouter_model.dig("pricing", "completion")),
          source: OPENROUTER_MODELS_URL,
          confidence: "medium",
          matched: openrouter_model.fetch("id"),
          notes: "Pulled from OpenRouter model catalogue; provider-specific direct pricing should be preferred before import."
        }
      end

    usage_data = USAGE_PRICES[key]
    subscription = SUBSCRIPTION_PRICES[tool.name]
    if subscription.nil? && FREE_OR_USAGE_BASED_TOOLS.include?(tool.name)
      subscription = {
        plan: "Usage-based API",
        source: tool.website_url,
        confidence: "medium",
        notes: "No fixed consumer subscription identified."
      }
    end

    score = score_number(variant)
    avg_tokens = variant.avg_total_tokens&.to_f
    input_price = api_data&.[](:input)&.to_f
    output_price = api_data&.[](:output)&.to_f
    blended = input_price && output_price ? ((input_price + output_price) / 2.0) : nil
    avg_call_cost = blended && avg_tokens ? (avg_tokens / 1_000_000.0 * blended) : nil
    api_performance_per_dollar = avg_call_cost&.positive? && score ? (score / avg_call_cost) : nil
    api_cost_per_point = avg_call_cost && score&.positive? ? (avg_call_cost / score) : nil
    subscription_effective_monthly = effective_monthly(subscription)
    subscription_performance_per_dollar =
      if subscription_effective_monthly&.positive? && score
        score / subscription_effective_monthly.to_f
      end
    subscription_cost_per_point =
      if subscription_effective_monthly && score&.positive?
        subscription_effective_monthly.to_f / score
      end

    audit_notes = []
    audit_notes << "Unscored/unavailable locally; price present but performance value cannot be calculated." unless score
    audit_notes << "Average token total only; API cost uses blended input/output price until prompt/completion token splits are stored." if avg_call_cost
    audit_notes << "No average token usage, so API price-per-performance is blank." if api_data && avg_tokens.nil?
    audit_notes << "Free subscription/app value is not finite, so subscription performance per dollar is blank." if subscription_effective_monthly&.zero? && score
    audit_notes << "No API token pricing match found." unless api_data || usage_data
    audit_notes << "No subscription/source match found." unless subscription

    {
      "tool_name" => tool.name,
      "model_name" => variant.name,
      "model_id_string" => variant.model_id_string,
      "performance_score" => decimal(score),
      "avg_total_tokens" => decimal(avg_tokens),
      "db_api_input_usd_per_m" => decimal(variant.input_usd_per_m),
      "db_api_output_usd_per_m" => decimal(variant.output_usd_per_m),
      "pulled_api_input_usd_per_m" => decimal(api_data&.[](:input)),
      "pulled_api_output_usd_per_m" => decimal(api_data&.[](:output)),
      "api_pricing_unit" => api_data ? "per 1M tokens" : nil,
      "api_matched_model_id" => api_data&.[](:matched),
      "api_source_url" => api_data&.[](:source),
      "api_confidence" => api_data&.[](:confidence),
      "api_notes" => api_data&.[](:notes),
      "usage_price_usd" => decimal(usage_data&.[](:price), places: 4),
      "usage_unit" => usage_data&.[](:unit),
      "usage_source_url" => usage_data&.[](:source),
      "usage_confidence" => usage_data&.[](:confidence),
      "usage_notes" => usage_data&.[](:notes),
      "api_blended_usd_per_m" => decimal(blended),
      "estimated_avg_call_cost_usd_blended" => decimal(avg_call_cost, places: 8),
      "estimated_api_performance_per_dollar" => decimal(api_performance_per_dollar, places: 2),
      "estimated_api_cost_per_score_point_usd" => decimal(api_cost_per_point, places: 8),
      "subscription_plan_name" => subscription&.[](:plan),
      "subscription_effective_monthly_usd" => decimal(subscription_effective_monthly),
      "subscription_monthly_usd" => decimal(subscription&.[](:monthly)),
      "subscription_annualized_monthly_usd" => decimal(annualized_monthly(subscription || {})),
      "subscription_annual_usd" => decimal(subscription&.[](:annual)),
      "subscription_one_time_usd" => decimal(subscription&.[](:one_time)),
      "subscription_source_url" => subscription&.[](:source),
      "subscription_confidence" => subscription&.[](:confidence),
      "subscription_notes" => subscription&.[](:notes),
      "subscription_performance_per_monthly_dollar" => decimal(subscription_performance_per_dollar, places: 4),
      "subscription_cost_per_score_point_usd" => decimal(subscription_cost_per_point, places: 4),
      "audit_notes" => audit_notes.join(" ")
    }
  end
end

CSV.open(OUTPUT_PATH, "w", write_headers: true, headers: HEADERS) do |csv|
  rows.each { |row| csv << HEADERS.map { |header| row[header] } }
end

puts "Wrote #{rows.size} rows to #{OUTPUT_PATH}"
