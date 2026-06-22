class Tool < ApplicationRecord
  include Scoreable
  BroadOverallResult = Struct.new(:tool, :model_variant, :score, keyword_init: true)

  # String-backed enums. Use prefixes so values like `none`/`yes` don't
  # clobber ActiveRecord methods (e.g. the built-in `Tool.none` scope).
  enum :status, { live: "live", dead: "dead", review: "review" }, default: "live"
  enum :data_retention,
       { none: "none", optional: "optional", yes: "yes", unclear: "unclear" },
       prefix: :retention
  enum :data_pricing_confidence,
       { low: "low", medium: "medium", high: "high" },
       prefix: :pricing_confidence

  has_many :tool_categories, dependent: :destroy
  has_many :categories, through: :tool_categories
  has_many :reviews, dependent: :destroy
  has_many :model_variants, dependent: :destroy, inverse_of: :tool

  validates :name, presence: true, uniqueness: true

  # --- hard-filter scopes (deterministic; never randomised) ---
  scope :visible,    -> { where(status: "live") }
  scope :free_app,   -> { where(consumer_free_app: true) }
  scope :local,      -> { where(runs_locally: true) }
  scope :private_ok, -> { where(data_retention: %w[none optional]) }

  # Neutral baseline so un-scored tools don't sink in ranking.
  RANK_BASELINE = 5.0
  BROAD_OVERALL_CATEGORIES = [
    "Writing",
    "Research",
    "Coding",
    "Accuracy & trustworthiness",
    "Ease of use",
    "Image generation",
    "Translation"
  ].freeze
  BROAD_OVERALL_MIN_CATEGORY_SCORE = 6.0

  # Intent dimension (chosen by the parser from the user's request) => the
  # score column it ranks on. Kept for callers, derived from the rubric map so
  # future score dimensions do not need separate ranking wiring.
  PRIORITY_DIMENSIONS = Rubric::PRIORITY_DIMENSIONS
  VERDICT_BEST_FOR_CATEGORIES = [
    "Writing",
    "Research",
    "Coding",
    "Accuracy & Trustworthiness",
    "Image Generation",
    "Transcription",
    "Meetings",
    "Translation"
  ].freeze
  VERDICT_NOT_IDEAL_LABELS = {
    "Writing" => "Long-form writing",
    "Research" => "Research-heavy work",
    "Coding" => "Coding",
    "Accuracy & Trustworthiness" => "High-stakes accuracy",
    "Ease of use" => "Beginners",
    "Image Generation" => "Image generation",
    "Transcription" => "Transcription",
    "Meetings" => "Meetings",
    "Privacy & Data Safety" => "Privacy-sensitive work",
    "Enterprise" => "Enterprise governance",
    "Translation" => "Translation"
  }.freeze
  VERDICT_MISSING_FACT_LABELS = {
    shows_citations: "Citation-heavy research",
    has_deep_research: "Deep research",
    no_training_on_user_data: "Privacy-sensitive work",
    configurable_data_retention: "Strict data-retention needs",
    has_coding_agent: "Agentic coding",
    has_meeting_bot: "Automated meeting capture",
    has_api: "API workflows"
  }.freeze

  # Headline verdict (1-10) for the scorecard + ranking: the best of this
  # tool's per-model verdicts. For a tool with no model lineup, score the
  # product directly from its own output quality + accuracy. nil = not yet rated.
  def overall_verdict
    verdicts = model_variants.map(&:verdict).compact
    return verdicts.max.round(1) if verdicts.any?

    self_verdict&.round(1)
  end

  def broad_overall_score
    broad_overall_result&.score
  end

  def broad_overall_result
    candidates = model_variants.filter_map do |variant|
      score = broad_overall_score_for(variant.category_scores(extra_scores: rubric_field_values))
      BroadOverallResult.new(tool: self, model_variant: variant, score:) if score
    end
    best = candidates.max_by(&:score)
    return best if best

    score = broad_overall_score_for(category_scores)
    BroadOverallResult.new(tool: self, model_variant: nil, score:) if score
  end

  def broad_overall_score_for(category_scores)
    scores = category_scores.slice(*BROAD_OVERALL_CATEGORIES)
    return nil unless scores.size == BROAD_OVERALL_CATEGORIES.size
    return nil if scores.values.any? { |score| score.to_f < BROAD_OVERALL_MIN_CATEGORY_SCORE }
    (scores.values.sum.to_f / scores.size).round(1)
  end

  def scored?
    overall_verdict.present?
  end

  def best_model_variant
    model_variants.select(&:scored?).max_by { |variant| variant.verdict || -Float::INFINITY }
  end

  def verdict_model_name
    name
  end

  def verdict_star_rating
    return nil unless overall_verdict

    (overall_verdict / 2.0).round.clamp(1, 5)
  end

  def verdict_category_scores
    if (variant = best_model_variant)
      variant.category_scores(extra_scores: rubric_field_values)
    else
      category_scores
    end
  end

  def verdict_best_for(limit: 3)
    return [] unless scored?

    scores = verdict_category_scores.slice(*VERDICT_BEST_FOR_CATEGORIES)
    scores.sort_by { |_category, score| -score.to_f }.first(limit).map(&:first)
  end

  def verdict_not_ideal_for(limit: 3)
    return [] unless scored?

    weak_categories = verdict_category_scores
      .select { |_category, score| score.to_f < 6.5 }
      .sort_by { |_category, score| score.to_f }
      .map { |category, _score| VERDICT_NOT_IDEAL_LABELS.fetch(category, category) }

    missing_facts = VERDICT_MISSING_FACT_LABELS.filter_map do |field, label|
      label if respond_to?(field) && public_send(field) != true
    end

    (weak_categories + missing_facts).uniq.first(limit)
  end

  def verdict_models_available
    model_variants.size
  end

  def verdict_free_tier?
    consumer_free_app? || has_free_plan? || model_variants.any?(&:free_to_try)
  end

  def comparison_category_score(fields)
    category = Rubric::OVERALL_CATEGORIES.key(fields) if Rubric::OVERALL_CATEGORIES.respond_to?(:key)
    model_fields = model_variant_fields(fields)

    if model_fields.any?
      return model_variants.filter_map { |variant|
        next unless variant_scored_for_fields?(variant, fields)

        variant.category_score(fields, extra_scores: rubric_field_values, category:)
      }.max
    end

    category_score(fields, category:)
  end

  # Verdict from the tool's own scores — used when there are no scored
  # variants (single-model products). Same gated formula as a model verdict.
  def self_verdict
    verdict_with
  end

  def product_overall_scores
    Rubric::PRODUCT_FIELDS.filter_map { |field| public_send(field) if respond_to?(field) }
  end

  def rubric_field_values
    Rubric::SCORE_FIELDS.each_with_object({}) do |field, values|
      values[field] = public_send(field) if respond_to?(field) && public_send(field).present?
    end
  end

  def dimension_score(priority_dimension)
    fields = Rubric.fields_for(priority_dimension)
    return nil if fields.empty?

    category = Rubric.category_for(priority_dimension)
    model_fields = model_variant_fields(fields)

    if model_fields.any?
      return model_variants.filter_map { |variant|
        next unless variant_scored_for_fields?(variant, fields)

        variant.category_score(fields, extra_scores: rubric_field_values, category:)
      }.max
    end

    category_score(fields, category:)
  end

  # Best value for a score column across this tool's variants, falling back to
  # the tool's own column. nil when nothing is scored on that dimension.
  def best_score(field)
    vals = model_variants.filter_map { |v| v.public_send(field) if v.respond_to?(field) }
    vals << public_send(field) if respond_to?(field)
    vals.compact.max
  end

  # True when this tool has been scored on the given priority dimension. The
  # matcher uses this to rank tools we've actually evaluated for the need above
  # tools we haven't, so a missing score never masquerades as an average one.
  def scored_on?(priority_dimension)
    !dimension_score(priority_dimension).nil?
  end

  def score_category_slugs
    Rubric::BROWSE_CATEGORY_DIMENSIONS.keys.select { |slug| qualifies_for_browse_category?(slug) }
  end

  def score_categories
    slugs = score_category_slugs
    return Category.none if slugs.empty?

    Category.ordered.where(slug: slugs)
  end

  def qualifies_for_browse_category?(slug)
    dimension = Rubric.dimension_for_browse_category(slug)
    return false unless dimension

    dimension_score(dimension).to_f >= Rubric::BROWSE_CATEGORY_MIN_SCORE
  end

  def sync_score_categories!
    self.categories = score_categories
  end

  def variant_scored_for_fields?(variant, fields)
    model_fields = model_variant_fields(fields)
    return true if model_fields.empty?

    model_fields.any? { |field| variant.respond_to?(field) && variant.public_send(field).present? }
  end

  def model_variant_fields(fields)
    Array(fields).select { |field| ModelVariant.column_names.include?(field.to_s) }
  end

  # Rank score (1-10). With a priority dimension AND a score on it, rank on
  # that dimension alone. Otherwise use the overall verdict. The matcher tiers
  # tools scored on the dimension above unscored tools, so a missing score never
  # masquerades as an average one.
  def rank_score(priority_dimension = nil)
    specific = dimension_score(priority_dimension)
    return specific if specific

    overall_verdict || RANK_BASELINE
  end

  def sortable_price
    return 0.0 if consumer_free_app?
    return price_low_usd.to_f if price_low_usd.present?

    token_prices = [input_usd_per_m, output_usd_per_m].compact
    return token_prices.min.to_f if token_prices.any?

    Float::INFINITY
  end

  # --- display helpers (graceful fallback for un-curated labels) ---
  def display_privacy_label
    privacy_label.presence || retention_blurb
  end

  def display_price_label
    price_label.presence || (consumer_free_app? ? "has a free option" : "paid")
  end

  def display_ease_label
    ease_label.presence || "setup varies"
  end

  # The review to surface, if any. Filters in Ruby so a preloaded :reviews
  # association doesn't trigger a query per card (avoids N+1 on results pages).
  def display_review
    reviews.to_a.select(&:published?).max_by(&:published_at)
  end

  # Human-readable price, token-based or flat, for the compare table.
  def price_summary
    if input_usd_per_m.present? || output_usd_per_m.present?
      parts = []
      parts << "$#{input_usd_per_m} in"  if input_usd_per_m.present?
      parts << "$#{output_usd_per_m} out" if output_usd_per_m.present?
      [parts.join(" / "), pricing_unit].compact_blank.join(" ")
    elsif price_low_usd.present?
      range = price_high_usd.present? ? "$#{price_low_usd}–$#{price_high_usd}" : "$#{price_low_usd}"
      [range, pricing_unit].compact_blank.join(" ")
    else
      "—"
    end
  end

  private

  def retention_blurb
    case data_retention
    when "none"     then "doesn't keep your data"
    when "optional" then "you can turn off data keeping"
    when "yes"      then "keeps your data"
    else "data handling unclear"
    end
  end
end
