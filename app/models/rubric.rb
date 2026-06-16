class Rubric
  # Single source of truth for score dimensions that participate in search
  # ranking and overall verdicts. A dimension can map to one score field or to
  # a composite of fields.
  DIMENSIONS = {
    "write_edit" => {
      label: "Write / edit",
      short_label: "Writing",
      fields: [:score_write_edit],
      level: :model,
      group: :output,
      intent_words: %w[write writing wrote draft drafting edit editing rewrite rewriting email emails reply replies outreach blog blogs article articles essay essays copy copywriting content caption captions post posts story stories newsletter newsletters letter letters message messages],
      intent_phrases: ["write for me", "help me write", "write email", "write emails", "write an email", "draft email", "reply to email", "reply to emails", "rewrite a", "improve my writing", "social media post", "blog post"]
    },
    "summarization" => {
      label: "Summarisation",
      short_label: "Summary",
      fields: [:score_summarization],
      level: :model,
      group: :output,
      intent_words: %w[summarise summarize summary summarised summarized tldr condense shorten recap notes briefing brief digest],
      intent_phrases: ["summarize this", "summarise this", "make a summary", "shrink long documents", "key points"]
    },
    "research" => {
      label: "Research",
      short_label: "Research",
      fields: [:score_research_fact_check, :score_source_quality, :score_hallucination_resistance],
      level: :model,
      group: :output,
      intent_words: %w[research cite cites citation citations source sources factual accurate accuracy facts factcheck factchecking trustworthy trust verify verification reference references study studies],
      intent_phrases: ["find sources", "cite sources", "with citations", "fact check", "fact-check", "check facts", "up to date", "trustworthy answer"]
    },
    "meetings_transcription" => {
      label: "Meetings & transcriptions",
      short_label: "Meetings",
      fields: [:score_meetings_transcription],
      level: :model,
      group: :output,
      intent_words: %w[transcribe transcription transcript transcripts interview interviews audio voice recording recordings dictation subtitle subtitles caption captions podcast meeting meetings notes minutes],
      intent_phrases: ["meeting notes", "transcribe audio", "transcribe interviews", "interview transcript", "meeting minutes", "action items"]
    },
    "coding" => {
      label: "Coding",
      short_label: "Coding",
      fields: [:score_coding_speed, :score_coding_efficiency],
      level: :model,
      group: :output,
      intent_words: %w[code coding program programming developer develop debug debugging software script scripts javascript typescript python ruby rails react api bug bugs error errors stacktrace refactor refactoring],
      intent_phrases: ["write code", "review code", "debug code", "fix code", "fix a bug", "build an app", "build a website", "make a website", "web app", "code review"]
    },
    "translation" => {
      label: "Translation",
      short_label: "Translate",
      fields: [:score_translation_speed, :score_translation_accuracy],
      level: :model,
      group: :output,
      intent_words: %w[translate translation translator translating language languages multilingual localize localisation localization],
      intent_phrases: ["translate text", "translate documents", "across languages", "localize content"]
    },
    "trustworthiness" => {
      label: "Accuracy & trustworthiness",
      short_label: "Trust",
      fields: [:score_hallucination_resistance, :score_source_quality, :score_consistency],
      level: :model,
      group: :gate,
      intent_words: %w[hallucination hallucinations reliable reliability consistent consistency trustworthy trust accurate accuracy source sources safe],
      intent_phrases: ["does not hallucinate", "low hallucination", "reliable answers", "consistent answers", "accuracy and trustworthiness"]
    },
    "prompt_effort" => {
      label: "Prompt effort",
      short_label: "Prompt",
      fields: [:score_prompt_effort],
      level: :tool,
      group: :product,
      intent_words: %w[easy simple beginner beginner-friendly nontechnical non-technical quick straightforward intuitive prompt prompting],
      intent_phrases: ["easy to use", "simple to use", "beginner friendly", "no setup", "quick setup", "little prompt effort"]
    },
    "interface" => {
      label: "Interface",
      short_label: "UI",
      fields: [:score_interface],
      level: :tool,
      group: :product,
      intent_words: %w[interface ui app design navigation workflow workflows polished clean],
      intent_phrases: ["nice interface", "good interface", "easy interface", "clean app"]
    },
    "security_certifications" => {
      label: "Security & certifications",
      short_label: "Security",
      fields: [:score_security_certifications],
      level: :tool,
      group: :product,
      intent_words: %w[security secure certification certifications compliance enterprise soc hipaa iso private privacy confidential sensitive],
      intent_phrases: ["data safety", "security certifications", "enterprise security", "privacy and data safety", "confidential data"]
    }
  }.freeze

  FACT_FIELDS = {
    free_to_try: { level: :model, format: :boolean },
    web_available: { level: :tool, format: :boolean },
    mobile_available: { level: :tool, format: :boolean },
    desktop_available: { level: :tool, format: :boolean },
    data_location: { level: :tool, format: :string },
    trains_on_user_data: { level: :tool, format: :string },
    retains_user_data: { level: :tool, format: :string }
  }.freeze

  OVERALL_CATEGORIES = {
    "Output quality" => [
      :score_write_edit,
      :score_summarization,
      :score_research_fact_check,
      :score_meetings_transcription
    ],
    "Coding" => [
      :score_coding_speed,
      :score_coding_efficiency
    ],
    "Accuracy & trustworthiness" => [
      :score_hallucination_resistance,
      :score_source_quality,
      :score_consistency
    ],
    "Ease of use" => [
      :score_prompt_effort,
      :score_interface
    ],
    "Privacy & data safety" => [
      :score_security_certifications
    ],
    "Translations" => [
      :score_translation_speed,
      :score_translation_accuracy
    ]
  }.freeze

  SUBCATEGORY_FIELDS = {
    "Write / edit" => :score_write_edit,
    "Summarisation quality" => :score_summarization,
    "Research & check facts" => :score_research_fact_check,
    "Meetings & transcriptions" => :score_meetings_transcription,
    "Coding speed" => :score_coding_speed,
    "Coding efficiency" => :score_coding_efficiency,
    "Hallucination resistance" => :score_hallucination_resistance,
    "Source quality" => :score_source_quality,
    "Consistency" => :score_consistency,
    "Prompt effort" => :score_prompt_effort,
    "Interface" => :score_interface,
    "Security & certifications" => :score_security_certifications,
    "Translation speed" => :score_translation_speed,
    "Translation accuracy" => :score_translation_accuracy
  }.freeze

  OUTPUT_DIMENSIONS = DIMENSIONS.select { |_key, config| config[:group] == :output }.freeze
  OUTPUT_FIELDS = OUTPUT_DIMENSIONS.values.flat_map { |config| config[:fields] }.uniq.freeze
  PRODUCT_FIELDS = DIMENSIONS.values.filter_map { |config| config[:fields] if config[:group] == :product }.flatten.uniq.freeze
  GATE_FIELDS = DIMENSIONS.values.filter_map { |config| config[:fields] if config[:group] == :gate }.flatten.uniq.freeze
  SCORE_FIELDS = DIMENSIONS.values.flat_map { |config| config[:fields] }.uniq.freeze
  PRIORITY_DIMENSIONS = DIMENSIONS.to_h { |dimension, config| [dimension, config[:fields]] }.freeze

  def self.fields_for(dimension)
    Array(PRIORITY_DIMENSIONS[dimension])
  end

  def self.label_for(dimension)
    DIMENSIONS.dig(dimension, :label) || dimension.to_s.tr("_", " ")
  end
end
