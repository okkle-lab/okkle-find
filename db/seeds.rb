require "csv"
require "digest"

# ---------------------------------------------------------------------------
# Categories (browse grid). Seeded first so the CSV can reference them by slug
# and they carry nice display metadata + icons. Idempotent on :slug.
# ---------------------------------------------------------------------------
CATEGORIES = [
  { slug: "write-things",   display_name: "write things",    subtitle: "emails, posts, essays",  icon: "pencil",          position: 1 },
  { slug: "chat-assistant", display_name: "chat & ask",      subtitle: "answers to anything",    icon: "message-chatbot", position: 2 },
  { slug: "code",           display_name: "write code",      subtitle: "build & fix software",   icon: "code",            position: 3 },
  { slug: "summarize",      display_name: "summarise",       subtitle: "shrink long documents",  icon: "file-text",       position: 4 },
  { slug: "research",       display_name: "research",        subtitle: "find & cite sources",    icon: "search",          position: 5 },
  { slug: "audio-to-text",  display_name: "transcribe",      subtitle: "audio & interviews",     icon: "microphone",      position: 6 },
  { slug: "translate",      display_name: "translate",       subtitle: "across languages",       icon: "language",        position: 7 }
].freeze

CATEGORIES.each do |attrs|
  Category.find_or_initialize_by(slug: attrs[:slug]).update!(attrs)
end
puts "Categories: #{Category.count}"

# ---------------------------------------------------------------------------
# Tools, imported from the CSV. Idempotent on :name. Re-running updates in
# place and never duplicates tools or join rows.
# ---------------------------------------------------------------------------
def yes?(value)
  value.to_s.strip.downcase.start_with?("y")
end

def score_attributes_from(row, fields, model_class)
  columns = model_class.column_names
  fields.each_with_object({}) do |field, attrs|
    key = field.to_s
    next unless columns.include?(key)

    attrs[field] =
      if row.headers.include?(key) && row[key].present?
        row[key]
      elsif row.headers.include?(key)
        nil
      else
        placeholder_score(row, key)
      end
  end
end

def fact_attributes_from(row, fields, model_class)
  columns = model_class.column_names
  fields.each_with_object({}) do |(field, config), attrs|
    key = field.to_s
    next unless columns.include?(key)

    attrs[field] =
      if row.headers.include?(key) && row[key].present?
        row[key]
      else
        placeholder_fact(row, key, config)
      end
  end
end

def placeholder_score(row, field)
  4 + stable_number(row, field, 7) # 4..10 while we wait for real scoring
end

def placeholder_fact(row, field, config)
  case config[:format]
  when :boolean
    stable_number(row, field, 2).zero?
  when :string
    case field.to_s
    when "data_location" then %w[US EU Global Unknown][stable_number(row, field, 4)]
    when "trains_on_user_data", "retains_user_data" then %w[yes no unknown][stable_number(row, field, 3)]
    else "unknown"
    end
  end
end

def stable_number(row, field, modulo)
  seed = [row["tool_name"], row["name"], row["provider"], field].compact.join(":")
  Digest::SHA1.hexdigest(seed).to_i(16) % modulo
end

VALID_RETENTION = Tool.data_retentions.keys.freeze # %w[none optional yes unclear]
LEGACY_TOOL_SCORE_FIELDS = %i[
  ease_score
  privacy_score
  score_text_generation
  score_email_writing
  score_logic
  score_coding
  score_image_generation
  score_accuracy
  score_prompt_effort
  score_interface
  score_security_certifications
].freeze

csv_path = Rails.root.join("db/seeds/ai_tool_catalogue_text_models.csv")
abort "Catalogue CSV not found at #{csv_path}" unless File.exist?(csv_path)

imported = 0
CSV.foreach(csv_path, headers: true) do |row|
  tool = Tool.find_or_initialize_by(name: row["name"].to_s.strip)

  retention = row["data_retention"].to_s.strip.downcase
  retention = "unclear" unless VALID_RETENTION.include?(retention)

  tool.assign_attributes(
    provider:                 row["provider"].presence,
    website_url:              row["website_url"].presence,
    status:                   (row["status"].presence || "live"),
    last_verified:            row["last_verified"].presence,
    data_pricing_confidence:  row["data_pricing_confidence"].presence,
    input_usd_per_m:          row["input_usd_per_m"].presence,
    output_usd_per_m:         row["output_usd_per_m"].presence,
    pricing_unit:             row["pricing_unit"].presence,
    price_low_usd:            row["price_low_usd"].presence,
    price_high_usd:           row["price_high_usd"].presence,
    context_window:           row["context_window"].presence,
    api_free_tier:            yes?(row["api_free_tier"]),
    consumer_free_app:        yes?(row["consumer_free_app"]),
    data_retention:           retention,
    runs_locally:             yes?(row["runs_locally"]),
    privacy_label:            row["privacy_label"].presence,
    price_label:              row["price_label"].presence,
    ease_label:               row["ease_label"].presence,
    why_this_one:             row["why_this_one"].presence,
    **LEGACY_TOOL_SCORE_FIELDS.index_with { nil },
    **score_attributes_from(row, Rubric::SCORE_FIELDS, Tool),
    **fact_attributes_from(row, Rubric::FACT_FIELDS, Tool)
  )
  tool.save!

  imported += 1
end

puts "Tools: #{Tool.count} (imported/updated #{imported})"

# ---------------------------------------------------------------------------
# Model variants (individual models under a product, e.g. Claude → Sonnet /
# Opus / Fable). Idempotent on [tool, name]. Only lineups we've actually
# verified belong in this CSV — a wrong price is worse than no variant, and
# cards simply omit the row for tools without variants.
# ---------------------------------------------------------------------------
variants_path = Rails.root.join("db/seeds/model_variants.csv")
if File.exist?(variants_path)
  variant_count = 0
  variant_rows = CSV.read(variants_path, headers: true)
  variant_names_by_tool = Hash.new { |hash, key| hash[key] = [] }

  variant_rows.each do |row|
    tool_name = row["tool_name"].to_s.strip
    variant_name = row["name"].to_s.strip
    next if tool_name.blank? || variant_name.blank?

    variant_names_by_tool[tool_name] << variant_name
  end

  variant_rows.each do |row|
    tool = Tool.find_by(name: row["tool_name"].to_s.strip)
    next unless tool

    tool.model_variants.find_or_initialize_by(name: row["name"].to_s.strip).update!(
      model_id_string:  row["model_id_string"].presence,
      input_usd_per_m:  row["input_usd_per_m"].presence,
      output_usd_per_m: row["output_usd_per_m"].presence,
      pricing_unit:     row["pricing_unit"].presence,
      context_window:   row["context_window"].presence,
      best_for:         row["best_for"].presence,
      last_verified:    row["last_verified"].presence,
      position:         row["position"].presence || 0,
      **score_attributes_from(row, Rubric::SCORE_FIELDS, ModelVariant),
      **fact_attributes_from(row, Rubric::FACT_FIELDS, ModelVariant)
    )
    variant_count += 1
  end

  variant_names_by_tool.each do |tool_name, variant_names|
    tool = Tool.find_by(name: tool_name)
    next unless tool

    tool.model_variants.where.not(name: variant_names).destroy_all
  end

  puts "Model variants: #{ModelVariant.count} (imported/updated #{variant_count})"
end

# Keep browse/search categories derived from the current score data. Static CSV
# category hints can drift; this makes a newly high-scoring model appear in the
# matching category as soon as seeds are reapplied.
Tool.includes(:model_variants).find_each(&:sync_score_categories!)
puts "Tool-category links: #{ToolCategory.count} (score-derived)"

# ---------------------------------------------------------------------------
# Blog posts (the "Latest in AI" section). Idempotent on :slug.
# ---------------------------------------------------------------------------
POSTS = [
  {
    slug: "spring-2026-chat-assistants",
    title: "Spring 2026: the big chat assistants all leveled up",
    published_at: Time.zone.parse("2026-06-02 09:00"),
    excerpt: "ChatGPT, Claude and Gemini each shipped updates in recent weeks. Here's what actually matters for everyday use — and what's just noise.",
    body: <<~BODY
      It's been a busy few weeks. The three assistants most people reach for all pushed updates, and the marketing is, as ever, louder than the real-world difference.

      For everyday writing, chatting and quick answers, the gap between them is now small — pick the one that fits where you already work. The bigger differences show up at the edges: very long documents, careful step-by-step reasoning, and how each one handles your data.

      Our take: don't chase the leaderboard. Decide what you actually need (free? private? good at long writing?), then let those requirements narrow the field. That's exactly what the search box at the top of this page is for.
    BODY
  },
  {
    slug: "local-ai-good-enough",
    title: "Local AI is finally good enough for real work",
    published_at: Time.zone.parse("2026-05-26 09:00"),
    excerpt: "Tools like Ollama and LM Studio let you run capable models on your own laptop — private, free, and offline. Here's where they shine and where they don't.",
    body: <<~BODY
      A year ago, running a model on your own machine was a fun experiment. Today it's genuinely useful for a lot of everyday tasks — drafting, summarising, brainstorming — without anything leaving your computer.

      The trade-off is setup and horsepower. You'll need a reasonably modern machine, and the very best quality still lives in the big cloud models. But if privacy or cost matters more than squeezing out the last 10% of quality, local is a real option now.

      If that's you, search for something like "a chatbot I can run offline on my own machine" and we'll show only the tools that actually qualify.
    BODY
  },
  {
    slug: "what-free-really-means",
    title: "What 'free' really means across AI tools",
    published_at: Time.zone.parse("2026-05-19 09:00"),
    excerpt: "A free tier can mean anything from 'genuinely generous' to 'bait'. Here's the honest version for the kinds of tools in our catalogue.",
    body: <<~BODY
      "Free" is doing a lot of work in AI marketing. Sometimes it means a generous everyday allowance. Sometimes it means a trial that runs out in an afternoon. Sometimes it means free for you, because you (and your data) are the product.

      We split the difference two ways: is there a genuinely free app for individuals, and separately, is there a free API tier for builders? They're not the same thing, and most people only care about the first.

      When you ask for something "free" in the search box, we filter to the free consumer app — not the API — so the results match what you actually meant.
    BODY
  },
  {
    slug: "private-transcription-options",
    title: "Transcription without sending your audio to the cloud",
    published_at: Time.zone.parse("2026-05-12 09:00"),
    excerpt: "If you're transcribing interviews or sensitive recordings, where your audio goes matters. The privacy-first options, explained.",
    body: <<~BODY
      Transcription is one of the clearest cases where privacy really matters — interviews, medical notes, legal recordings. Many popular services upload your audio to their servers and keep it.

      The good news: open-source transcription you run locally has become both accurate and approachable. If you're comfortable with a little setup, you can transcribe entirely on your own machine.

      Try "transcribe my interviews without my data being kept" — we'll drop anything that keeps your recordings and show only what genuinely fits.
    BODY
  }
].freeze

POSTS.each do |attrs|
  Post.find_or_initialize_by(slug: attrs[:slug]).update!(attrs)
end
puts "Posts: #{Post.count}"

# ---------------------------------------------------------------------------
# Human reviews: one markdown file per review in db/seeds/reviews/, with YAML
# front matter (slug, tool, title, byline, rating, published_at) and the
# review prose as the body. Written/edited via the GitHub web editor.
# Idempotent on :slug. Leave published_at out to keep a review as a draft.
# ---------------------------------------------------------------------------
Dir.glob(Rails.root.join("db/seeds/reviews/*.md")).sort.each do |path|
  raw = File.read(path)
  unless raw =~ /\A---\n(.+?)\n---\n(.*)\z/m
    abort "Review #{path} is missing its front matter (--- ... ---) block"
  end

  meta = YAML.safe_load(Regexp.last_match(1), permitted_classes: [Date, Time])
  body = Regexp.last_match(2).strip

  tool = Tool.find_by(name: meta["tool"])
  unless tool
    abort "Review #{path}: tool #{meta["tool"].inspect} is not in the catalogue"
  end

  Review.find_or_initialize_by(slug: meta.fetch("slug")).update!(
    tool:         tool,
    title:        meta.fetch("title"),
    byline:       meta["byline"],
    rating:       meta["rating"],
    published_at: meta["published_at"].presence && Time.zone.parse(meta["published_at"].to_s),
    body:         body
  )
end
puts "Reviews: #{Review.count}"
