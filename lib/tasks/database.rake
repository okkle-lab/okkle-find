require "bigdecimal"
require "csv"

module SeedDataVerification
  module_function

  def variant_metric_fields(headers, rubric_score_fields)
    imported_metric_fields = rubric_score_fields + %w[avg_latency_seconds avg_total_tokens]
    headers.select { |header| imported_metric_fields.include?(header.to_s) }
  end

  def seed_value_matches_record?(expected, record, field)
    actual = record.public_send(field)
    return false if actual.nil?

    case ModelVariant.type_for_attribute(field).type
    when :integer
      Integer(expected) == actual.to_i
    when :decimal, :float
      BigDecimal(expected) == BigDecimal(actual.to_s)
    else
      expected == actual.to_s
    end
  rescue ArgumentError
    false
  end
end

namespace :ai_finder do
  desc "Verify that CSV-backed catalogue and model metric data is present in the local database"
  task verify_seed_data: :environment do
    catalogue_path = Rails.root.join("db/seeds/ai_tool_catalogue_text_models.csv")
    variants_path = Rails.root.join("db/seeds/model_variants.csv")
    missing_seed_files = [catalogue_path, variants_path].reject { |path| File.exist?(path) }
    abort "Missing seed file(s): #{missing_seed_files.join(", ")}" if missing_seed_files.any?

    required_tables = %w[categories tools tool_categories model_variants]
    missing_tables = required_tables.reject { |table| ActiveRecord::Base.connection.table_exists?(table) }
    abort "Database is missing required table(s): #{missing_tables.join(", ")}" if missing_tables.any?

    catalogue_rows = CSV.read(catalogue_path, headers: true)
    expected_tool_names = catalogue_rows.filter_map { |row| row["name"].to_s.strip.presence }
    missing_tools = expected_tool_names.reject { |name| Tool.exists?(name:) }
    abort "Seeded tool record(s) missing: #{missing_tools.first(10).join(", ")}" if missing_tools.any?

    variant_rows = CSV.read(variants_path, headers: true)
    metric_fields = SeedDataVerification.variant_metric_fields(variant_rows.headers, Rubric::SCORE_FIELDS.map(&:to_s))
    missing_columns = metric_fields.reject { |field| ModelVariant.column_names.include?(field) }
    abort "Database is missing model metric column(s): #{missing_columns.join(", ")}" if missing_columns.any?

    checked_values = 0
    missing_variants = []
    mismatches = []

    variant_rows.each do |row|
      tool_name = row["tool_name"].to_s.strip
      variant_name = row["name"].to_s.strip
      next if tool_name.blank? || variant_name.blank?

      variant = Tool.find_by(name: tool_name)&.model_variants&.find_by(name: variant_name)
      unless variant
        missing_variants << "#{tool_name} / #{variant_name}"
        next
      end

      metric_fields.each do |field|
        expected = row[field].to_s.strip
        next if expected.blank?

        checked_values += 1
        next if SeedDataVerification.seed_value_matches_record?(expected, variant, field)

        mismatches << "#{tool_name} / #{variant_name} #{field}: expected #{expected.inspect}, got #{variant.public_send(field).inspect}"
      end
    end

    errors = []
    errors << "Seeded model variant record(s) missing: #{missing_variants.first(10).join(", ")}" if missing_variants.any?
    errors << "Seeded model metric value mismatch(es): #{mismatches.first(10).join("; ")}" if mismatches.any?
    abort errors.join("\n") if errors.any?
    abort "No seed-backed model metric values were found in #{variants_path}" if checked_values.zero?

    puts "Verified #{expected_tool_names.size} tools and #{checked_values} seed-backed model metric values."
  end
end
