require "rss"
require "open-uri"
require "timeout"

class NewsAggregator
  MODEL      = "claude-haiku-4-5"
  TOOL_NAME  = "evaluate_story"
  FETCH_TIMEOUT = 12

  # RSS/Atom feeds covering practical AI tool news
  RSS_FEEDS = [
    { url: "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml", source: "The Verge" },
    { url: "https://techcrunch.com/category/artificial-intelligence/feed/",      source: "TechCrunch" },
    { url: "https://simonwillison.net/atom/everything/",                          source: "Simon Willison" },
    { url: "https://venturebeat.com/category/ai/feed/",                           source: "VentureBeat" },
    { url: "https://www.technologyreview.com/feed/",                              source: "MIT Technology Review" },
    { url: "https://feeds.arstechnica.com/arstechnica/index",                    source: "Ars Technica" },
    { url: "https://openai.com/news/rss.xml",                                    source: "OpenAI" },
    { url: "https://www.anthropic.com/rss.xml",                                  source: "Anthropic" },
  ].freeze

  def self.call
    new.call
  end

  def call
    return 0 if api_key.blank?

    tool_names = Tool.pluck(:name)
    saved = 0

    RSS_FEEDS.each do |feed_config|
      items = fetch_feed(feed_config[:url], feed_config[:source])
      Rails.logger.info("[NewsAggregator] #{feed_config[:source]}: #{items.size} item(s)")

      items.each do |item|
        next if Post.exists?(source_url: item[:source_url])
        result = evaluate(item, tool_names)
        next unless result[:publish]
        create_post(item, result)
        saved += 1
        sleep 0.3
      end
    rescue => e
      Rails.logger.warn("[NewsAggregator] Feed #{feed_config[:source]} error: #{e.message}")
    end

    Rails.logger.info("[NewsAggregator] Done — #{saved} new post(s)")
    saved
  rescue => e
    Rails.logger.error("[NewsAggregator] #{e.class}: #{e.message}")
    0
  end

  private

  def api_key
    ENV["ANTHROPIC_API_KEY"].presence
  end

  def fetch_feed(url, source_name)
    raw = Timeout.timeout(FETCH_TIMEOUT) do
      URI.open(url, "User-Agent" => "Mozilla/5.0 (compatible; AI-Finder/1.0)", read_timeout: 10).read
    end
    feed = RSS::Parser.parse(raw, false)
    return [] unless feed

    items = feed.respond_to?(:entries) ? feed.entries : feed.items
    items.first(10).filter_map { |item| parse_item(item, source_name) }
  rescue => e
    Rails.logger.warn("[NewsAggregator] Could not fetch #{url}: #{e.message}")
    []
  end

  def parse_item(item, source_name)
    title = extract_title(item)
    return nil if title.blank?

    link = extract_link(item)
    return nil if link.blank?

    {
      title:       title.strip,
      excerpt:     extract_description(item),
      source_url:  link,
      source_name: source_name,
      published_at: extract_date(item)
    }
  end

  def extract_title(item)
    t = item.respond_to?(:title) ? item.title : nil
    return t.content if t.respond_to?(:content)
    t.to_s.strip
  end

  def extract_link(item)
    return nil unless item.respond_to?(:link)
    l = item.link
    return l.href if l.respond_to?(:href)
    l.to_s.strip
  end

  def extract_description(item)
    raw =
      if item.respond_to?(:summary) && item.summary
        item.summary.respond_to?(:content) ? item.summary.content : item.summary.to_s
      elsif item.respond_to?(:description) && item.description
        item.description.to_s
      elsif item.respond_to?(:content) && item.content
        item.content.respond_to?(:content) ? item.content.content : item.content.to_s
      else
        ""
      end
    raw.gsub(/<[^>]+>/, " ").gsub(/\s+/, " ").strip.first(600)
  end

  def extract_date(item)
    candidates = %i[pubDate published updated date]
    candidates.each do |m|
      next unless item.respond_to?(m)
      val = item.send(m)
      next if val.nil?
      return val.respond_to?(:content) ? val.content.to_time : val.to_time rescue next
    end
    nil
  end

  def evaluate(item, tool_names)
    message = Timeout.timeout(15) do
      client.messages.create(
        model: MODEL,
        max_tokens: 512,
        system_: system_prompt(tool_names),
        tools: [tool_schema],
        tool_choice: { type: "tool", name: TOOL_NAME },
        messages: [{
          role: "user",
          content: "Title: #{item[:title]}\n\nSummary: #{item[:excerpt]}\n\nSource: #{item[:source_name]}"
        }]
      )
    end

    block = message.content.find { |b| b.type == :tool_use }
    return { publish: false } unless block

    input = block.input
    input = input.to_h if input.respond_to?(:to_h)
    input.deep_symbolize_keys
  rescue => e
    Rails.logger.warn("[NewsAggregator] Claude eval failed for '#{item[:title]}': #{e.message}")
    { publish: false }
  end

  def create_post(item, result)
    tool = resolve_tool(result[:matched_tools])
    og   = UrlFetcher.call(item[:source_url]) rescue {}

    slug = unique_slug(item[:title].parameterize.first(80))

    Post.create!(
      title:        item[:title],
      slug:         slug,
      excerpt:      item[:excerpt].presence,
      post_type:    Post.post_types.key?(result[:post_type].to_s) ? result[:post_type].to_s : "general",
      verdict:      result[:post_type].to_s == "hype_check" ? result[:verdict].presence : nil,
      source_name:  item[:source_name],
      source_url:   item[:source_url],
      image_url:    og[:image_url].presence,
      published_at: item[:published_at] || Time.current,
      tool:         tool
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[NewsAggregator] Could not save '#{item[:title]}': #{e.message}")
  end

  def resolve_tool(matched_names)
    Array(matched_names).each do |name|
      t = Tool.where("lower(name) = ?", name.to_s.downcase).first
      return t if t
    end
    nil
  end

  def unique_slug(base)
    slug = base
    n = 2
    while Post.exists?(slug: slug)
      slug = "#{base}-#{n}"
      n += 1
    end
    slug
  end

  def client
    @client ||= Anthropic::Client.new(api_key: api_key)
  end

  def system_prompt(tool_names)
    <<~PROMPT
      You evaluate AI news stories for AI Finder — a curated site that helps people pick the right AI tools for real tasks.

      PUBLISH if the story does any of these:
      • Changes which tool a user should pick or pay for
      • Reveals a meaningful quality/feature/pricing change to an existing tool
      • Exposes hype or exaggerated claims about an AI product
      • Compares tools for a specific job (roundup/benchmark)
      • Shows a real, practical new capability users can act on today

      SKIP if the story is primarily about:
      • AGI timelines or existential risk speculation
      • Pure funding rounds with no product news
      • Executive appointments, industry politics, or corporate drama
      • Academic research with no near-term user impact
      • Speculation, rumours, or unconfirmed leaks

      POST TYPE rules:
      • practical_update — real change to a tool's functionality, pricing, or limits
      • hype_check — a claim that appears exaggerated; your verdict should cut through it
      • score_update — a benchmark or eval result that would change how we rank a tool
      • roundup — comparing multiple tools for a job
      • general — genuinely user-relevant AI news that doesn't fit above

      For hype_check, write a single punchy verdict line (e.g. "Impressive demo, not production-ready" or "Genuinely useful for most coders").

      Our tools database (match by name, case-insensitive): #{tool_names.join(", ")}
    PROMPT
  end

  def tool_schema
    {
      name: TOOL_NAME,
      description: "Decide whether to publish this AI news story on AI Finder.",
      input_schema: {
        type: "object",
        properties: {
          publish: {
            type: "boolean",
            description: "True to publish, false to skip"
          },
          post_type: {
            type: "string",
            enum: %w[practical_update hype_check score_update roundup general],
            description: "Editorial category"
          },
          verdict: {
            type: "string",
            description: "One-line verdict for hype_check stories only. Omit for other types."
          },
          matched_tools: {
            type: "array",
            items: { type: "string" },
            description: "Names from our tools database mentioned in this story. Empty array if none."
          }
        },
        required: %w[publish post_type matched_tools]
      }
    }
  end
end
