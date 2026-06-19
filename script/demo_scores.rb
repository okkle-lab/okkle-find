# Demo score seeder — fills rubric scores with realistic, capability-aware
# values so the UI (cards, scorecards, leaderboards, guides) can be demoed
# before real eval data lands.
#
#   bin/rails runner script/demo_scores.rb        # fill demo scores
#   bin/rails runner script/demo_scores.rb clear  # wipe them back to nil
#
# Values are deterministic per record (seeded by id) so reloads are stable.
# Scores are gated by what a model can actually do — Whisper transcribes but
# doesn't code, text LLMs don't generate images — so leaderboards make sense.
# This is DEMO data only — clear it before trusting any real ranking.

CLEAR = ARGV.include?("clear")

# Model-level score columns, grouped by the capability they belong to.
IMAGE_FIELDS = %w[image_quality_score prompt_adherence_score text_rendering_score image_editing_score]
TRANSCRIBE_FIELDS = %w[transcription_score]
MEETING_FIELDS = %w[meeting_summary_score follow_up_score]
TEXT_FIELDS = %w[
  write_edit_score summarisation_score research_fact_checking_score source_quality_score
  hallucination_resistance_score deep_research_score coding_speed_score coding_accuracy_score
  debugging_score agentic_coding_score consistency_score reasoning_score truthful_pushback_score
  translation_accuracy_score translation_speed_score
]

tool_fields = (Tool.column_names & Rubric::SCORE_FIELDS.map(&:to_s))

def banded(rng, base)
  (base + rng.rand(-1.2..1.2)).clamp(4.5, 9.8).round(1)
end

# Which model-level fields a given variant should be scored on.
def fields_for(variant)
  present = ModelVariant.column_names
  whisper = variant.name.to_s.downcase.include?("whisper")
  fields = whisper ? TRANSCRIBE_FIELDS : (TEXT_FIELDS + MEETING_FIELDS)
  # No image models in this catalogue yet, so image stays unrated everywhere.
  fields & present
end

mv_score_cols = (ModelVariant.column_names & Rubric::SCORE_FIELDS.map(&:to_s))

ModelVariant.find_each do |variant|
  rng = Random.new(variant.id * 7 + 13)
  base = rng.rand(6.2..9.2) # one quality level per model so its criteria cluster
  scored = fields_for(variant)
  updates = mv_score_cols.to_h do |f|
    [f, (CLEAR || !scored.include?(f)) ? nil : banded(rng, base)]
  end
  variant.update_columns(updates)
end

Tool.find_each do |tool|
  rng = Random.new(tool.id * 11 + 5)
  base = rng.rand(6.0..9.0)
  tool.update_columns(tool_fields.to_h { |f| [f, CLEAR ? nil : banded(rng, base)] })
end

puts CLEAR ? "Cleared demo scores." : "Seeded capability-aware demo scores on #{ModelVariant.count} variants and #{Tool.count} tools."
