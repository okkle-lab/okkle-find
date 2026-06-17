# Structured representation of what the user wants. Produced either by:
#   - ParsedNeed.from_category(slug)  — a browse tile (bypasses the LLM)
#   - ParsedNeed.from_keywords(text)  — naive keyword parse (also the LLM fallback)
#   - NeedParser (step 5)             — the LLM, which builds one of these
#
# Keeping this a plain value object means ToolMatcher doesn't care how the
# filters were derived.
class ParsedNeed
  # category slug => trigger words found in free text
  CATEGORY_KEYWORDS = {
    "audio-to-text"  => %w[transcribe transcription transcript transcripts interview interviews audio voice recording recordings dictation subtitle subtitles caption captions podcast],
    "write-things"   => %w[write writing wrote email emails essay essays blog post posts copy copywriting letter letters message messages draft],
    "code"           => %w[code coding program programming developer develop debug debugging software script scripts app coder],
    "summarize"      => %w[summarise summarize summary summarize summarised summarized tldr condense shorten recap],
    "research"       => %w[research cite citation citations source sources fact facts study studies references],
    "translate"      => %w[translate translation translator translating language languages multilingual],
    "chat-assistant" => %w[chat ask question questions assistant chatbot talk conversation answer answers]
  }.freeze

  FREE_PHRASES    = ["free", "for free", "budget", "cheap", "cheapest", "without paying", "no cost", "don't want to pay", "do not want to pay", "afford", "affordable"].freeze
  PRIVATE_PHRASES = ["private", "privacy", "confidential", "sensitive", "secure", "don't keep", "doesn't keep", "does not keep", "do not keep", "not keep", "not kept", "without my data", "data being kept", "data isn't kept", "no data retention", "not store", "doesn't store", "does not store", "won't store"].freeze
  LOCAL_PHRASES   = ["local", "locally", "offline", "on my computer", "on my machine", "on my laptop", "my own machine", "on-device", "on device", "self-host", "self host", "self-hosted", "without internet"].freeze

  STOPWORDS = %w[the a an and or to of for my me i want need without with that this it is are be can my your our without app tool tools ai help].freeze

  # Fallback mapping for the keyword path: category slug => priority dimension.
  # The LLM picks the dimension directly; this just keeps degraded parses useful.
  CATEGORY_DIMENSION = {
    "code"         => "coding",
    "write-things" => "write_edit",
    "research"     => "research",
    "summarize"    => "summarization",
    "translate"    => "translation",
    "audio-to-text" => "meetings"
  }.freeze

  attr_reader :raw_query, :task, :must_be_free, :must_be_private, :must_run_locally,
              :budget_ceiling_usd_month, :categories, :keywords, :priority_dimension, :source

  def initialize(raw_query: nil, task: nil, must_be_free: false, must_be_private: false,
                 must_run_locally: false, budget_ceiling_usd_month: nil,
                 categories: [], keywords: [], priority_dimension: nil, source: "keyword")
    @raw_query                = raw_query
    @task                     = task
    @must_be_free             = !!must_be_free
    @must_be_private          = !!must_be_private
    @must_run_locally         = !!must_run_locally
    @budget_ceiling_usd_month = budget_ceiling_usd_month
    @categories               = Array(categories).compact_blank.uniq
    @keywords                 = Array(keywords).compact_blank.uniq
    @priority_dimension       = Tool::PRIORITY_DIMENSIONS.key?(priority_dimension.to_s) ? priority_dimension.to_s : nil
    @source                   = source
  end

  # A browse tile is already structured — no parsing needed. The tile's category
  # also implies the dimension to rank by (e.g. the "code" tile ranks on coding).
  def self.from_category(slug, raw_query: nil)
    new(raw_query: raw_query, categories: [slug],
        priority_dimension: CATEGORY_DIMENSION[slug], source: "category")
  end

  # Naive keyword parse. Doubles as the LLM fallback (spec section 1).
  def self.from_keywords(text)
    q = text.to_s.downcase

    # Category triggers match on WHOLE WORDS, not substrings — otherwise
    # "transcript" would match the code trigger "script", etc.
    words = q.scan(/[a-z][a-z'-]*/)
    cats = CATEGORY_KEYWORDS.select do |_slug, triggers|
      triggers.any? { |w| words.include?(w) }
    end.keys

    new(
      raw_query:          text,
      must_be_free:       FREE_PHRASES.any?    { |p| q.include?(p) },
      must_be_private:    PRIVATE_PHRASES.any? { |p| q.include?(p) },
      must_run_locally:   LOCAL_PHRASES.any?   { |p| q.include?(p) },
      categories:         cats,
      keywords:           tokenize(text),
      priority_dimension: infer_priority_dimension(q, categories: cats, words: words),
      source:             "keyword"
    )
  end

  def self.infer_priority_dimension(text, categories: [], words: nil)
    q = text.to_s.downcase
    words ||= q.scan(/[a-z][a-z'-]*/)
    scores = Hash.new(0)

    Rubric::DIMENSIONS.each do |dimension, config|
      Array(config[:intent_phrases]).each do |phrase|
        scores[dimension] += 3 if q.include?(phrase)
      end

      Array(config[:intent_words]).each do |word|
        scores[dimension] += 1 if words.include?(word)
      end
    end

    categories.each do |slug|
      dimension = CATEGORY_DIMENSION[slug]
      scores[dimension] += 1 if dimension
    end

    winner, score = scores.max_by { |_dimension, value| value }
    score.to_i.positive? ? winner : nil
  end

  def self.tokenize(text)
    text.to_s.downcase.scan(/[a-z0-9][a-z0-9'-]+/)
        .reject { |w| w.length < 3 || STOPWORDS.include?(w) }
        .uniq
  end

  def any_hard_flag?
    must_be_free || must_be_private || must_run_locally
  end

  # For events.parsed_filters logging (step 8) and the LLM schema (step 5).
  def to_h
    {
      task: task,
      must_be_free: must_be_free,
      must_be_private: must_be_private,
      must_run_locally: must_run_locally,
      budget_ceiling_usd_month: budget_ceiling_usd_month,
      categories: categories,
      keywords: keywords,
      priority_dimension: priority_dimension,
      source: source
    }
  end
end
