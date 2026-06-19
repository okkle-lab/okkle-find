class Rubric
  # Rubric v3. This category block is generated from
  # PromptGradeApp/Defaults/Model_Testing_Rubric.xlsx. Run
  # `python3 script/sync_rubric_from_excel.py --write` after editing the workbook.
  # Atomic scores use the weights defined inside each composite category; category
  # composites use `overall_weight` when they roll into the final verdict.
  CATEGORIES = {
    "Writing" => {
      key: "writing",
      icon: "pencil",
      description: "Drafting emails, posts and reports — how well it writes from a brief, edits your work, and how little prompting it needs.",
      overall_weight: 1.00,
      fields: {
        write_edit_score: 0.50,
        summarisation_score: 0.30,
        prompt_effort_score: 0.20
      }
    },
    "Research" => {
      key: "research",
      icon: "search",
      description: "Finding and synthesising information — fact-checking accuracy, source quality, and how often it makes things up.",
      overall_weight: 1.00,
      fields: {
        research_fact_checking_score: 0.35,
        source_quality_score: 0.25,
        hallucination_resistance_score: 0.20,
        deep_research_score: 0.20
      }
    },
    "Coding" => {
      key: "coding",
      icon: "code",
      description: "Writing, fixing and running code — accuracy on real tasks, debugging ability, and autonomous multi-file editing.",
      overall_weight: 1.00,
      fields: {
        coding_speed_score: 0.25,
        coding_accuracy_score: 0.35,
        debugging_score: 0.20,
        agentic_coding_score: 0.20
      }
    },
    "Accuracy & trustworthiness" => {
      key: "accuracy",
      icon: "file-text",
      description: "How reliably correct the answers are — hallucination rate, logical reasoning quality, and consistency across repeated runs.",
      overall_weight: 1.00,
      fields: {
        hallucination_resistance_score: 0.30,
        source_quality_score: 0.20,
        consistency_score: 0.20,
        reasoning_score: 0.30,
        truthful_pushback_score: 0.20
      }
    },
    "Ease of use" => {
      key: "ease_of_use",
      icon: "bolt",
      description: "How much effort it takes to get a good result — interface quality, how simple your prompts need to be, and learning curve.",
      overall_weight: 1.00,
      fields: {
        prompt_effort_score: 0.40,
        interface_score: 0.40,
        learning_curve_score: 0.20
      }
    },
    "Image generation" => {
      key: "image",
      icon: "photo",
      description: "Creating images from text prompts — visual quality, how closely it follows your description, and text rendering inside images.",
      overall_weight: 1.00,
      fields: {
        image_quality_score: 0.35,
        prompt_adherence_score: 0.25,
        text_rendering_score: 0.20,
        image_editing_score: 0.20
      }
    },
    "Meetings" => {
      key: "meetings",
      icon: "microphone",
      description: "Recording, transcribing and summarising meetings — accuracy of transcripts, quality of summaries, and action-item extraction.",
      overall_weight: 1.00,
      fields: {
        transcription_score: 0.35,
        meeting_summary_score: 0.35,
        follow_up_score: 0.20,
        integration_score: 0.10
      }
    },
    "Translation" => {
      key: "translation",
      icon: "language",
      description: "Converting text between languages — how accurate the output is across language pairs and how fast results come back.",
      overall_weight: 1.00,
      fields: {
        translation_accuracy_score: 0.70,
        translation_speed_score: 0.30
      }
    },
    "Privacy & data safety" => {
      key: "privacy",
      icon: "shield-lock",
      description: "What happens to your data — how long it's retained, whether it's used for training, and what security certifications the provider holds.",
      overall_weight: 1.00,
      fields: {
        data_retention_score: 0.30,
        training_on_user_data_score: 0.30,
        security_certifications_score: 0.25,
        privacy_controls_score: 0.15
      }
    },
    "Enterprise" => {
      key: "enterprise",
      icon: "building",
      description: "Admin and deployment features — SSO, audit logs, role-based access, flexible hosting options, and SLA-backed support.",
      overall_weight: 1.00,
      fields: {
        enterprise_controls_score: 0.35,
        security_certifications_score: 0.25,
        deployment_flexibility_score: 0.20,
        support_sla_score: 0.20
      }
    }
  }.freeze

  DIMENSIONS = {
    "write_edit" => {
      label: "Write / edit",
      short_label: "Writing",
      fields: [:write_edit_score],
      category: "Writing",
      level: :model,
      group: :output,
      intent_words: %w[write writing wrote draft drafting edit editing rewrite rewriting email emails reply replies outreach blog blogs article articles essay essays copy copywriting content caption captions post posts story stories newsletter newsletters letter letters message messages],
      intent_phrases: ["write for me", "help me write", "write email", "write emails", "write an email", "draft email", "reply to email", "reply to emails", "rewrite a", "improve my writing", "social media post", "blog post"]
    },
    "summarization" => {
      label: "Summarisation",
      short_label: "Summary",
      fields: [:summarisation_score],
      category: "Writing",
      level: :model,
      group: :output,
      intent_words: %w[summarise summarize summary summarised summarized tldr condense shorten recap notes briefing brief digest],
      intent_phrases: ["summarize this", "summarise this", "make a summary", "shrink long documents", "key points"]
    },
    "research" => {
      label: "Research",
      short_label: "Research",
      fields: CATEGORIES.fetch("Research").fetch(:fields).keys,
      category: "Research",
      level: :model,
      group: :output,
      intent_words: %w[research cite cites citation citations source sources factual accurate accuracy facts factcheck factchecking trustworthy trust verify verification reference references study studies deep],
      intent_phrases: ["find sources", "cite sources", "with citations", "fact check", "fact-check", "check facts", "up to date", "trustworthy answer", "deep research"]
    },
    "coding" => {
      label: "Coding",
      short_label: "Coding",
      fields: CATEGORIES.fetch("Coding").fetch(:fields).keys,
      category: "Coding",
      level: :model,
      group: :output,
      intent_words: %w[code coding program programming developer develop debug debugging software script scripts javascript typescript python ruby rails react api bug bugs error errors stacktrace refactor refactoring agentic],
      intent_phrases: ["write code", "review code", "debug code", "fix code", "fix a bug", "build an app", "build a website", "make a website", "web app", "code review", "coding agent"]
    },
    "trustworthiness" => {
      label: "Accuracy & trustworthiness",
      short_label: "Trust",
      fields: CATEGORIES.fetch("Accuracy & trustworthiness").fetch(:fields).keys,
      category: "Accuracy & trustworthiness",
      level: :model,
      group: :gate,
      intent_words: %w[hallucination hallucinations reliable reliability consistent consistency trustworthy trust accurate accuracy source sources safe reasoning],
      intent_phrases: ["does not hallucinate", "low hallucination", "reliable answers", "consistent answers", "accuracy and trustworthiness"]
    },
    "ease_of_use" => {
      label: "Ease of use",
      short_label: "Ease",
      fields: CATEGORIES.fetch("Ease of use").fetch(:fields).keys,
      category: "Ease of use",
      level: :tool,
      group: :product,
      intent_words: %w[easy simple beginner beginner-friendly nontechnical non-technical quick straightforward intuitive prompt prompting interface ui learning],
      intent_phrases: ["easy to use", "simple to use", "beginner friendly", "no setup", "quick setup", "little prompt effort", "clean app"]
    },
    "image_generation" => {
      label: "Image generation",
      short_label: "Images",
      fields: CATEGORIES.fetch("Image generation").fetch(:fields).keys,
      category: "Image generation",
      level: :model,
      group: :output,
      intent_words: %w[image images picture pictures visual visuals generate generation editing edit prompt adherence text rendering],
      intent_phrases: ["image generation", "generate images", "make images", "edit images", "image editing", "text in images"]
    },
    "meetings" => {
      label: "Meetings",
      short_label: "Meetings",
      fields: CATEGORIES.fetch("Meetings").fetch(:fields).keys,
      category: "Meetings",
      level: :model,
      group: :output,
      intent_words: %w[transcribe transcription transcript transcripts interview interviews audio voice recording recordings dictation subtitle subtitles caption captions podcast meeting meetings notes minutes followup follow-up calendar],
      intent_phrases: ["meeting notes", "transcribe audio", "transcribe interviews", "interview transcript", "meeting minutes", "action items", "meeting bot"]
    },
    "privacy" => {
      label: "Privacy & data safety",
      short_label: "Privacy",
      fields: CATEGORIES.fetch("Privacy & data safety").fetch(:fields).keys,
      category: "Privacy & data safety",
      level: :tool,
      group: :product,
      intent_words: %w[private privacy confidential sensitive retention training data safety secure security],
      intent_phrases: ["data safety", "privacy and data safety", "confidential data", "no training on user data", "data retention"]
    },
    "enterprise" => {
      label: "Enterprise",
      short_label: "Enterprise",
      fields: CATEGORIES.fetch("Enterprise").fetch(:fields).keys,
      category: "Enterprise",
      level: :tool,
      group: :product,
      intent_words: %w[enterprise admin governance compliance deployment sso scim audit sla support company],
      intent_phrases: ["enterprise controls", "security certifications", "admin controls", "deployment flexibility", "support sla"]
    },
    "translation" => {
      label: "Translation",
      short_label: "Translate",
      fields: CATEGORIES.fetch("Translation").fetch(:fields).keys,
      category: "Translation",
      level: :model,
      group: :output,
      intent_words: %w[translate translation translator translating language languages multilingual localize localisation localization],
      intent_phrases: ["translate text", "translate documents", "across languages", "localize content"]
    }
  }.freeze

  FACT_FIELDS = {
    free_to_try: { level: :model, format: :boolean },
    has_web_search: { level: :tool, format: :boolean },
    shows_citations: { level: :tool, format: :boolean },
    has_file_uploads: { level: :tool, format: :boolean },
    has_image_uploads: { level: :tool, format: :boolean },
    has_voice_mode: { level: :tool, format: :boolean },
    supports_model_selection: { level: :tool, format: :boolean },
    has_image_generation: { level: :tool, format: :boolean },
    has_image_editing: { level: :tool, format: :boolean },
    has_video_generation: { level: :tool, format: :boolean },
    has_audio_generation: { level: :tool, format: :boolean },
    has_presentation_generation: { level: :tool, format: :boolean },
    has_coding_agent: { level: :tool, format: :boolean },
    has_code_execution: { level: :tool, format: :boolean },
    has_repository_access: { level: :tool, format: :boolean },
    has_deep_research: { level: :tool, format: :boolean },
    has_live_data_access: { level: :tool, format: :boolean },
    has_transcription: { level: :tool, format: :boolean },
    has_meeting_bot: { level: :tool, format: :boolean },
    has_action_items: { level: :tool, format: :boolean },
    has_api: { level: :tool, format: :boolean },
    has_mobile_app: { level: :tool, format: :boolean },
    has_desktop_app: { level: :tool, format: :boolean },
    has_browser_extension: { level: :tool, format: :boolean },
    has_calendar_integration: { level: :tool, format: :boolean },
    has_email_integration: { level: :tool, format: :boolean },
    has_workspace_integration: { level: :tool, format: :boolean },
    has_free_plan: { level: :tool, format: :boolean },
    has_paid_plan: { level: :tool, format: :boolean },
    has_team_plan: { level: :tool, format: :boolean },
    has_enterprise_plan: { level: :tool, format: :boolean },
    supports_sso: { level: :tool, format: :boolean },
    supports_scim: { level: :tool, format: :boolean },
    has_audit_logs: { level: :tool, format: :boolean },
    has_admin_controls: { level: :tool, format: :boolean },
    has_soc2: { level: :tool, format: :boolean },
    has_iso27001: { level: :tool, format: :boolean },
    has_dpa: { level: :tool, format: :boolean },
    gdpr_ready: { level: :tool, format: :boolean },
    hipaa_eligible: { level: :tool, format: :boolean },
    no_training_on_user_data: { level: :tool, format: :boolean },
    configurable_data_retention: { level: :tool, format: :boolean },
    web_available: { level: :tool, format: :boolean },
    mobile_available: { level: :tool, format: :boolean },
    desktop_available: { level: :tool, format: :boolean },
    data_location: { level: :tool, format: :string },
    trains_on_user_data: { level: :tool, format: :string },
    retains_user_data: { level: :tool, format: :string }
  }.freeze

  OVERALL_CATEGORIES = CATEGORIES.transform_values { |config| config.fetch(:fields).keys }.freeze

  SUBCATEGORY_FIELDS = {
    "Write & edit" => :write_edit_score,
    "Summarisation" => :summarisation_score,
    "Prompt effort" => :prompt_effort_score,
    "Research & fact checking" => :research_fact_checking_score,
    "Source quality" => :source_quality_score,
    "Hallucination resistance" => :hallucination_resistance_score,
    "Deep research" => :deep_research_score,
    "Coding speed" => :coding_speed_score,
    "Coding accuracy" => :coding_accuracy_score,
    "Code review & debugging" => :debugging_score,
    "Agentic coding" => :agentic_coding_score,
    "Consistency" => :consistency_score,
    "Reasoning" => :reasoning_score,
    "Truthful pushback" => :truthful_pushback_score,
    "Political leanings and agreement" => :truthful_pushback_score,
    "Hiring" => :truthful_pushback_score,
    "Resistance to being told no" => :truthful_pushback_score,
    "Emotional disagreement" => :truthful_pushback_score,
    "Religion" => :truthful_pushback_score,
    "Interface" => :interface_score,
    "Learning curve" => :learning_curve_score,
    "Image quality" => :image_quality_score,
    "Prompt adherence" => :prompt_adherence_score,
    "Text rendering" => :text_rendering_score,
    "Image editing" => :image_editing_score,
    "Transcription" => :transcription_score,
    "Meeting summaries" => :meeting_summary_score,
    "Follow-up automation" => :follow_up_score,
    "Calendar & workspace integration" => :integration_score,
    "Data retention" => :data_retention_score,
    "Training on user data" => :training_on_user_data_score,
    "Security & certifications" => :security_certifications_score,
    "Privacy controls" => :privacy_controls_score,
    "Enterprise controls" => :enterprise_controls_score,
    "Deployment flexibility" => :deployment_flexibility_score,
    "Support & SLA" => :support_sla_score,
    "Translation accuracy" => :translation_accuracy_score,
    "Translation speed" => :translation_speed_score
  }.freeze

  # The universal 1–10 scale every judge scores against, so a number means the
  # same thing across all models (from the scoring guide).
  SCORE_BANDS = [
    { range: "1–3", label: "Poor", blurb: "Misses the point, wrong, or unusable." },
    { range: "4–6", label: "Adequate", blurb: "Works, but generic, uneven, or with errors." },
    { range: "7–8", label: "Strong", blurb: "Accurate, complete, and dependable." },
    { range: "9–10", label: "Excellent", blurb: "Polished, precise, best-in-class." }
  ].freeze

  # Plain-English "what it measures" for each criterion (from the scoring guide).
  CRITERION_MEASURES = {
    write_edit_score: "Clarity, concision, and professionalism when drafting or rewriting text.",
    summarisation_score: "Accuracy and faithfulness when condensing long content to the requested format.",
    prompt_effort_score: "How much the result improves with thoughtful prompting versus fighting the tool.",
    research_fact_checking_score: "Coverage and accuracy when comparing sources and checking claims.",
    source_quality_score: "Credibility and proper attribution of the sources it cites.",
    hallucination_resistance_score: "Whether it admits uncertainty instead of inventing facts or citations.",
    deep_research_score: "Depth of multi-step research with balanced arguments and synthesis.",
    coding_speed_score: "Producing correct, working code quickly for straightforward tasks.",
    coding_accuracy_score: "Correctness on strict tests, including adversarial and edge cases.",
    debugging_score: "Finding and explaining bugs, then delivering a correct fix.",
    agentic_coding_score: "Investigating and improving real code while preserving behaviour.",
    consistency_score: "Giving stable answers across repeated runs of the same question.",
    reasoning_score: "Working through tricky, multi-step problems to the right answer.",
    truthful_pushback_score: "Whether it can push back constructively instead of simply agreeing with the user.",
    interface_score: "How clean and capable the app itself is to work in.",
    learning_curve_score: "How quickly a new user becomes productive.",
    image_quality_score: "Visual quality and realism of generated images.",
    prompt_adherence_score: "How precisely the image matches every element of the prompt.",
    text_rendering_score: "Spelling and legibility of text rendered inside images.",
    image_editing_score: "Clean, seamless edits that preserve the rest of the image.",
    transcription_score: "Accuracy of speech-to-text, including speakers and terminology.",
    meeting_summary_score: "Correctly extracting decisions, action items, and risks.",
    follow_up_score: "Generating accurate, send-ready follow-up communications.",
    integration_score: "Quality of the calendar and workspace actions it can take.",
    data_retention_score: "How long your data is kept, evidenced from the policy.",
    training_on_user_data_score: "Whether your inputs are used to train the model.",
    security_certifications_score: "Verified security certifications (SOC 2, ISO, and similar).",
    privacy_controls_score: "Controls for deletion, retention, sharing, and permissions.",
    enterprise_controls_score: "SSO, SCIM, RBAC, audit logs, and governance.",
    deployment_flexibility_score: "API, workspace, and private-deployment options.",
    support_sla_score: "Support tiers and SLA commitments.",
    translation_accuracy_score: "Accuracy and naturalness, preserving tone and nuance.",
    translation_speed_score: "Response latency for translation."
  }.freeze

  OUTPUT_DIMENSIONS = DIMENSIONS.select { |_key, config| config[:group] == :output }.freeze
  OUTPUT_FIELDS = OUTPUT_DIMENSIONS.values.flat_map { |config| config[:fields] }.uniq.freeze
  PRODUCT_FIELDS = DIMENSIONS.values.filter_map { |config| config[:fields] if config[:group] == :product }.flatten.uniq.freeze
  GATE_FIELDS = DIMENSIONS.values.filter_map { |config| config[:fields] if config[:group] == :gate }.flatten.uniq.freeze
  SCORE_FIELDS = DIMENSIONS.values.flat_map { |config| config[:fields] }.uniq.freeze
  PRIORITY_DIMENSIONS = DIMENSIONS.to_h { |dimension, config| [dimension, config[:fields]] }.freeze
  BROWSE_CATEGORY_MIN_SCORE = 7.0
  BROWSE_CATEGORY_DIMENSIONS = {
    "write-things" => "write_edit",
    "chat-assistant" => "trustworthiness",
    "code" => "coding",
    "summarize" => "summarization",
    "research" => "research",
    "audio-to-text" => "meetings",
    "translate" => "translation"
  }.freeze

  def self.fields_for(dimension)
    Array(PRIORITY_DIMENSIONS[dimension])
  end

  def self.dimension_for_browse_category(slug)
    BROWSE_CATEGORY_DIMENSIONS[slug.to_s]
  end

  def self.category_for(dimension)
    DIMENSIONS.dig(dimension, :category)
  end

  def self.weight_for(category, field)
    CATEGORIES.dig(category, :fields, field.to_sym) || 1.0
  end

  def self.overall_weight_for(category)
    CATEGORIES.dig(category, :overall_weight) || 1.0
  end

  def self.label_for(dimension)
    DIMENSIONS.dig(dimension, :label) || dimension.to_s.tr("_", " ")
  end
end
