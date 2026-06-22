# Stage 1 of the pipeline: turn free text into a structured ParsedNeed using
# the Claude API (a small, fast Haiku-class model — this is a trivial
# extraction task, per spec section 6).
#
# Reliability rules (spec section 1):
#   - Forced tool-use guarantees structurally valid JSON (no prose/fences).
#   - ~5s timeout, no long retries.
#   - ANY failure (no key, timeout, bad output, network) falls back to the
#     deterministic keyword parser. A bad parse must never 500 the page.
require "timeout"

class NeedParser
  MODEL     = "claude-haiku-4-5"
  TIMEOUT_S = 5
  MAX_TOKENS = 512
  TOOL_NAME = "record_need"

  def self.call(query)
    new(query).call
  end

  def initialize(query)
    @query = query.to_s.strip
  end

  def call
    return ParsedNeed.from_keywords(@query) if @query.blank? || api_key.blank?

    data = cached_or_parse
    data ? build_need(data) : ParsedNeed.from_keywords(@query)
  rescue => e
    Rails.logger.warn("[NeedParser] #{e.class}: #{e.message} — falling back to keyword parse")
    ParsedNeed.from_keywords(@query)
  end

  private

  def api_key
    ENV["ANTHROPIC_API_KEY"].presence
  end

  def valid_slugs
    @valid_slugs ||= Category.pluck(:slug)
  end

  # Cache the parsed *filters* (not the picked tools — those stay random).
  # In dev the cache is usually a null store, so this just no-ops.
  def cached_or_parse
    key = "need_parser/v3/#{Digest::SHA1.hexdigest(@query.downcase)}"
    Rails.cache.fetch(key, expires_in: 1.day) { parse_with_llm }
  end

  def parse_with_llm
    message = Timeout.timeout(TIMEOUT_S) do
      client.messages.create(
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system_: system_prompt,
        tools: [tool_schema],
        tool_choice: { type: "tool", name: TOOL_NAME },
        messages: [{ role: "user", content: @query }]
      )
    end

    block = message.content.find { |b| b.type == :tool_use }
    return nil unless block

    input = block.input
    input = input.to_h if input.respond_to?(:to_h)
    input.deep_symbolize_keys
  end

  def client
    @client ||= Anthropic::Client.new(api_key: api_key)
  end

  def build_need(data)
    ParsedNeed.new(
      raw_query:                @query,
      task:                     data[:task].presence,
      must_be_free:             data[:must_be_free],
      must_be_private:          data[:must_be_private],
      must_run_locally:         data[:must_run_locally],
      budget_ceiling_usd_month: positive_number(data[:budget_ceiling_usd_month]),
      categories:               Array(data[:categories]) & valid_slugs,
      keywords:                 ParsedNeed.tokenize(@query),
      priority_dimension:       data[:priority_dimension].presence,
      source:                   "llm"
    )
  end

  def positive_number(value)
    n = Float(value) rescue nil
    n if n && n > 0
  end

  def system_prompt
    <<~PROMPT
      You translate a person's plain-English description of what they want from
      an AI tool into structured filters, by calling the #{TOOL_NAME} tool.

      Map fuzzy language to flags:
        - "free" / "on a budget" / "without paying" -> must_be_free: true
        - "private" / "don't keep my data" / "confidential" / "sensitive" -> must_be_private: true
        - "on my computer" / "offline" / "locally" / "on my machine" -> must_run_locally: true
      If a phrase doesn't clearly imply a flag, set that flag to false.

      Pick zero or more categories ONLY from the allowed list. If none clearly
      fit, return an empty array. Never invent a category.

      Allowed categories: #{valid_slugs.join(", ")}.

      Also pick the SINGLE quality that matters most for this request, as
      priority_dimension — this decides which score we rank results by:
      #{priority_dimension_prompt}
      Omit priority_dimension if nothing clearly dominates.
    PROMPT
  end

  def priority_dimension_prompt
    Rubric.dimensions.map do |dimension, config|
      examples = Array(config[:intent_phrases]).first(3).join(" / ")
      "  - #{config[:label]} (#{examples}) -> #{dimension}"
    end.join("\n")
  end

  def tool_schema
    {
      name: TOOL_NAME,
      description: "Record the structured filters extracted from the user's request.",
      input_schema: {
        type: "object",
        properties: {
          task: {
            type: "string",
            description: "Short label for the task, e.g. 'transcription', 'writing emails'."
          },
          must_be_free:     { type: "boolean", description: "True if they need a free option." },
          must_be_private:  { type: "boolean", description: "True if they don't want their data kept." },
          must_run_locally: { type: "boolean", description: "True if it must run on their own computer/offline." },
          budget_ceiling_usd_month: {
            type: "number",
            description: "Monthly budget ceiling in USD, if they named one. Omit if not mentioned."
          },
          categories: {
            type: "array",
            description: "Zero or more matching categories from the allowed list.",
            items: { type: "string", enum: valid_slugs }
          },
          priority_dimension: {
            type: "string",
            description: "The single most important quality to rank results by. Omit if none clearly dominates.",
            enum: Rubric.priority_dimensions.keys
          }
        },
        required: %w[must_be_free must_be_private must_run_locally categories]
      }
    }
  end
end
