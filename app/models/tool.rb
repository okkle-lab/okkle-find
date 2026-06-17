class Tool < ApplicationRecord
  include Scoreable

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

  # Intent dimension (chosen by the parser from the user's request) => the
  # score column it ranks on. Kept for callers, derived from the rubric map so
  # future score dimensions do not need separate ranking wiring.
  PRIORITY_DIMENSIONS = Rubric::PRIORITY_DIMENSIONS

  # Headline verdict (1-10) for the scorecard + ranking: the best of this
  # tool's per-model verdicts. For a tool with no model lineup, score the
  # product directly from its own output quality + accuracy. nil = not yet rated.
  def overall_verdict
    verdicts = model_variants.map(&:verdict).compact
    return verdicts.max.round(1) if verdicts.any?

    self_verdict&.round(1)
  end

  def best_model_variant
    model_variants.max_by { |variant| variant.verdict || -Float::INFINITY }
  end

  def comparison_category_score(fields)
    category = Rubric::OVERALL_CATEGORIES.key(fields) if Rubric::OVERALL_CATEGORIES.respond_to?(:key)
    if (variant = best_model_variant)
      variant.category_score(fields, extra_scores: rubric_field_values, category:)
    else
      category_score(fields, category:)
    end
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
    vals = model_variants.filter_map { |variant| variant.category_score(fields, category:) }
    vals << category_score(fields, category:)
    vals.compact.max
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

  # Rank score (1-10). With a priority dimension AND a score on it, this is a
  # 50/50 blend of that dimension and the overall verdict. Otherwise it's just
  # the overall verdict — a tool with no score on the dimension is ranked on its
  # overall (and tiered below scored tools by the matcher), never given a
  # baseline that would inflate it past tools with a real, lower score.
  def rank_score(priority_dimension = nil)
    overall = overall_verdict || RANK_BASELINE
    specific = dimension_score(priority_dimension)
    return overall unless specific

    (specific + overall) / 2.0
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
