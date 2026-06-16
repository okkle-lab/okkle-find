# Shared score math for Tool (its "one model") and ModelVariant (a specific
# model). Rubric metadata lives in Rubric; this concern only applies it.
module Scoreable
  extend ActiveSupport::Concern

  # Average of whichever output sub-scores are filled (nil if none yet).
  def output_quality
    score_average(Rubric::OUTPUT_FIELDS)
  end

  def score_average(fields)
    vals = Array(fields).filter_map { |field| public_send(field) if respond_to?(field) }
    vals.any? ? vals.sum.to_f / vals.size : nil
  end

  def category_score(fields, extra_scores: {})
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
    Rubric::OVERALL_CATEGORIES.filter_map do |label, fields|
      score = category_score(fields, extra_scores:)
      [label, score] if score
    end.to_h
  end

  # Overall verdict: average subcategory scores within each rubric category,
  # then average those category scores. nil = not yet rated.
  def verdict_with(extra_scores: {})
    scores = category_scores(extra_scores:).values
    scores.any? ? scores.sum.to_f / scores.size : nil
  end
end
