# Shared score math for Tool (its "one model") and ModelVariant (a specific
# model). Rubric metadata lives in Rubric; this concern only applies it.
module Scoreable
  extend ActiveSupport::Concern

  # Average of whichever output sub-scores are filled (nil if none yet).
  def output_quality
    score_average(Rubric.output_fields)
  end

  def score_average(fields)
    vals = Array(fields).filter_map { |field| public_send(field) if respond_to?(field) }
    vals.any? ? vals.sum.to_f / vals.size : nil
  end

  def category_score(fields, extra_scores: {}, category: nil)
    vals = Array(fields).filter_map do |field|
      value =
        if respond_to?(field)
          public_send(field)
        else
          extra_scores[field]
        end
      next if value.nil?

      [value, Rubric.weight_for(category, field)]
    end
    return nil if vals.empty?

    weighted_sum = vals.sum { |value, weight| value.to_f * weight.to_f }
    weight_sum = vals.sum { |_value, weight| weight.to_f }
    weighted_sum / weight_sum
  end

  def category_score_unweighted(fields, extra_scores: {})
    vals = Array(fields).filter_map do |field|
      if respond_to?(field)
        public_send(field)
      else
        extra_scores[field]
      end
    end
    vals.any? ? vals.sum.to_f / vals.size : nil
  end

  def category_scores(extra_scores: {})
    Rubric.overall_categories.filter_map do |label, fields|
      score = category_score(fields, extra_scores:, category: label)
      [label, score] if score
    end.to_h
  end

  # Overall verdict: average subcategory scores within each rubric category,
  # then combine those category scores with the rubric's category weights.
  # nil = not yet rated.
  def verdict_with(extra_scores: {})
    scores = category_scores(extra_scores:)
    return nil if scores.empty?

    weighted_sum = scores.sum { |category, score| score.to_f * Rubric.overall_weight_for(category) }
    weight_sum = scores.sum { |category, _score| Rubric.overall_weight_for(category) }
    weighted_sum / weight_sum
  end
end
