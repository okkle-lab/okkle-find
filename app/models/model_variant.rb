# An individual model offered by a tool (e.g. Claude → Sonnet / Opus / Fable).
# Variants are evidence on the product, not search results in their own right:
# the hard filter and weighted pick operate on tools only, and variants are
# surfaced on result cards, the detail page, and (later) compare.
class ModelVariant < ApplicationRecord
  include Scoreable

  belongs_to :tool, inverse_of: :model_variants
  has_many :evaluation_notes,
    class_name: "ModelEvaluationNote",
    dependent: :destroy,
    inverse_of: :model_variant

  validates :name, presence: true, uniqueness: { scope: :tool_id }

  scope :ordered, -> { order(:position, :id) }

  def scored?
    output_quality.present?
  end

  # This model's verdict, using parent tool scores for tool-level categories.
  def verdict
    return nil unless scored?

    verdict_with(extra_scores: tool.rubric_field_values)
  end

  # "$3 in / $15 out per 1M tokens" — mirrors Tool#price_summary.
  def price_summary
    return nil if input_usd_per_m.blank? && output_usd_per_m.blank?

    parts = []
    parts << "$#{format_price(input_usd_per_m)} in"   if input_usd_per_m.present?
    parts << "$#{format_price(output_usd_per_m)} out" if output_usd_per_m.present?
    [parts.join(" / "), pricing_unit].compact_blank.join(" ")
  end

  # Tooltip text for the compact chip on result cards.
  def chip_title
    [price_summary, best_for].compact_blank.join(" — ")
  end

  private

  # Trim trailing zeros so a decimal(12,4) column reads "$3", not "$3.0000".
  def format_price(value)
    value.to_f % 1 == 0 ? value.to_i.to_s : value.to_f.to_s
  end
end
