require "csv"

module PromptGradeImport
  module_function

  def import_csv(path)
    rows = CSV.read(path, headers: true)
    imported = 0
    skipped = 0

    rows.each do |row|
      if row["error"].present? || note_text_blank?(row)
        skipped += 1
        next
      end

      variant = model_variant_for(row)
      unless variant
        skipped += 1
        next
      end

      score_field = Rubric.score_field_for_test_id(row["test_id"])
      category = row["category"].presence || (score_field && Rubric.category_for_field(score_field))
      grader_key = row["grader_model_key"].presence || row["grader_model_name"].presence || "unknown"
      test_id = row["test_id"].to_s.strip.presence || "row-#{row['source_row']}"

      note = variant.evaluation_notes.find_or_initialize_by(
        test_id: test_id,
        grader_model_key: grader_key
      )
      note.update!(
        category: category,
        criterion: row["criterion"].presence,
        score_field: score_field&.to_s,
        grader_model_name: row["grader_model_name"].presence,
        score: row["score"].presence,
        reasoning: row["reasoning"].presence,
        strengths: row["strengths"].presence,
        issues: row["issues"].presence
      )
      imported += 1
    end

    [imported, skipped]
  end

  def model_variant_for(row)
    model_key = row["source_model_key"].to_s.strip
    if model_key.present?
      variant = ModelVariant.find_by(model_id_string: model_key)
      return variant if variant
    end

    model_name = normalized_name(row["source_model_name"])
    return nil if model_name.blank?

    matches = ModelVariant.includes(:tool).select do |variant|
      normalized_name(variant.name) == model_name
    end
    matches.one? ? matches.first : nil
  end

  def normalized_name(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, "")
  end

  def note_text_blank?(row)
    %w[reasoning strengths issues].all? { |field| row[field].to_s.strip.blank? }
  end
end

namespace :ai_finder do
  desc "Import PromptGradeApp grades.csv notes into model evaluation notes"
  task :import_prompt_grades, [:path] => :environment do |_task, args|
    path = args[:path].presence
    abort "Usage: bin/rails 'ai_finder:import_prompt_grades[path/to/grades.csv]'" unless path
    abort "Prompt grade CSV not found: #{path}" unless File.exist?(path)

    imported, skipped = PromptGradeImport.import_csv(path)
    puts "Imported #{imported} prompt grade note(s). Skipped #{skipped} unmatched row(s)."
  end
end
