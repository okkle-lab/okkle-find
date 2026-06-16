#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Catalogue lint — runs on every PR that touches db/seeds (see
# .github/workflows/catalogue-lint.yml), and locally with:
#
#   ruby script/validate_catalogue.rb
#
# The seed CSVs and review markdown files are edited by hand (often via the
# GitHub web editor), so this catches the typos a human reviewer shouldn't
# have to: wrong headers, misspelled enum values, scores out of range, a
# variant or review pointing at a tool that isn't in the catalogue.
#
# Self-contained: stdlib only (csv, yaml, date, time). Exits non-zero with a list of
# problems; prints a summary when clean.

require "csv"
require "yaml"
require "date"
require "time" # Time.parse (validating review published_at) — missing this 400'd in CI

ROOT          = File.expand_path("..", __dir__)
CATALOGUE_CSV = File.join(ROOT, "db/seeds/ai_tool_catalogue_text_models.csv")
VARIANTS_CSV  = File.join(ROOT, "db/seeds/model_variants.csv")
REVIEWS_GLOB  = File.join(ROOT, "db/seeds/reviews/*.md")

CATALOGUE_HEADERS = %w[
  name provider website_url status last_verified data_pricing_confidence
  input_usd_per_m output_usd_per_m pricing_unit price_low_usd price_high_usd
  context_window api_free_tier consumer_free_app data_retention runs_locally
  privacy_label price_label ease_label why_this_one
  ease_score privacy_score
  score_text_generation score_email_writing score_logic score_coding
  score_image_generation score_accuracy categories
].freeze

VARIANT_HEADERS = %w[
  tool_name name model_id_string input_usd_per_m output_usd_per_m
  pricing_unit context_window best_for last_verified position
  score_text_generation score_email_writing score_logic score_coding
  score_image_generation score_accuracy
  score_write_edit score_summarization score_research_fact_check
  score_source_quality score_hallucination_resistance score_meetings_transcription
  score_coding_speed score_coding_efficiency
  score_translation_speed score_translation_accuracy score_consistency
  free_to_try
].freeze

# Per-variant legacy scores plus rubric sub-scores (all 1-10, nullable).
VARIANT_SCORES = %w[
  score_text_generation score_email_writing score_logic score_coding
  score_image_generation score_accuracy
  score_write_edit score_summarization score_research_fact_check
  score_source_quality score_hallucination_resistance score_meetings_transcription
  score_coding_speed score_coding_efficiency
  score_translation_speed score_translation_accuracy score_consistency
].freeze

STATUSES    = %w[live dead review].freeze
RETENTIONS  = %w[none optional yes unclear].freeze
CONFIDENCES = %w[low medium high].freeze
YES_NO      = %w[yes no].freeze
BOOLEAN     = %w[true false yes no].freeze

@errors = []

def error(message)
  @errors << message
end

def check_headers(path, actual, expected)
  return if actual == expected

  missing = expected - actual
  extra   = actual - expected
  error "#{File.basename(path)}: header mismatch" \
        "#{" — missing: #{missing.join(", ")}" if missing.any?}" \
        "#{" — unexpected: #{extra.join(", ")}" if extra.any?}" \
        "#{" — same columns, wrong order" if missing.empty? && extra.empty?}"
end

def check_number(file, row_label, field, value, range: nil, integer: false)
  return if value.nil? || value.strip.empty?

  number = Float(value, exception: false)
  return error "#{file} · #{row_label}: #{field} #{value.inspect} is not a number" if number.nil?

  error "#{file} · #{row_label}: #{field} should be a whole number" if integer && number % 1 != 0
  error "#{file} · #{row_label}: #{field} #{value} is outside #{range}" if range && !range.cover?(number)
end

def check_date(file, row_label, field, value)
  return if value.nil? || value.strip.empty?

  Date.iso8601(value)
rescue Date::Error
  error "#{file} · #{row_label}: #{field} #{value.inspect} is not an ISO date (YYYY-MM-DD)"
end

def check_enum(file, row_label, field, value, allowed, allow_blank: false)
  return if allow_blank && (value.nil? || value.strip.empty?)

  unless allowed.include?(value.to_s.strip)
    error "#{file} · #{row_label}: #{field} #{value.inspect} must be one of: #{allowed.join(", ")}"
  end
end

# --- catalogue ---------------------------------------------------------------
abort "Missing #{CATALOGUE_CSV}" unless File.exist?(CATALOGUE_CSV)

catalogue = CSV.read(CATALOGUE_CSV, headers: true, encoding: "bom|utf-8")
check_headers(CATALOGUE_CSV, catalogue.headers, CATALOGUE_HEADERS)

tool_names = []
catalogue.each.with_index(2) do |row, line|
  file  = "catalogue CSV"
  name  = row["name"].to_s.strip
  label = name.empty? ? "line #{line}" : name

  error "#{file} · line #{line}: name is blank" if name.empty?
  error "#{file} · #{label}: duplicate tool name" if tool_names.include?(name)
  tool_names << name

  check_enum(file, label, "status", row["status"], STATUSES)
  check_enum(file, label, "data_retention", row["data_retention"], RETENTIONS)
  check_enum(file, label, "data_pricing_confidence", row["data_pricing_confidence"], CONFIDENCES, allow_blank: true)
  check_enum(file, label, "api_free_tier", row["api_free_tier"], YES_NO)
  check_enum(file, label, "consumer_free_app", row["consumer_free_app"], YES_NO)
  check_enum(file, label, "runs_locally", row["runs_locally"], YES_NO)
  check_date(file, label, "last_verified", row["last_verified"])

  %w[input_usd_per_m output_usd_per_m price_low_usd price_high_usd].each do |field|
    check_number(file, label, field, row[field], range: 0..Float::INFINITY)
  end
  check_number(file, label, "context_window", row["context_window"], range: 1..Float::INFINITY, integer: true)
  (%w[ease_score privacy_score] + VARIANT_SCORES).each do |field|
    check_number(file, label, field, row[field], range: 1..10, integer: true)
  end

  if row["website_url"].to_s.strip.then { |u| !u.empty? && !u.start_with?("http://", "https://") }
    error "#{file} · #{label}: website_url should start with http(s)://"
  end
  row["categories"].to_s.split(",").map(&:strip).each do |slug|
    unless slug.match?(/\A[a-z0-9]+(-[a-z0-9]+)*\z/)
      error "#{file} · #{label}: category #{slug.inspect} should be a lowercase-hyphen slug"
    end
  end
end

# --- model variants ----------------------------------------------------------
abort "Missing #{VARIANTS_CSV}" unless File.exist?(VARIANTS_CSV)

variants = CSV.read(VARIANTS_CSV, headers: true, encoding: "bom|utf-8")
check_headers(VARIANTS_CSV, variants.headers, VARIANT_HEADERS)

variant_keys = []
variants.each.with_index(2) do |row, line|
  file  = "variants CSV"
  name  = row["name"].to_s.strip
  tool  = row["tool_name"].to_s.strip
  label = name.empty? ? "line #{line}" : name

  error "#{file} · line #{line}: name is blank" if name.empty?
  unless tool_names.include?(tool)
    error "#{file} · #{label}: tool_name #{tool.inspect} is not a tool in the catalogue CSV"
  end

  key = [tool, name]
  error "#{file} · #{label}: duplicate variant for #{tool}" if variant_keys.include?(key)
  variant_keys << key

  %w[input_usd_per_m output_usd_per_m].each do |field|
    check_number(file, label, field, row[field], range: 0..Float::INFINITY)
  end
  check_number(file, label, "context_window", row["context_window"], range: 1..Float::INFINITY, integer: true)
  check_number(file, label, "position", row["position"], range: 0..Float::INFINITY, integer: true)
  VARIANT_SCORES.each do |field|
    check_number(file, label, field, row[field], range: 1..10, integer: true)
  end
  check_enum(file, label, "free_to_try", row["free_to_try"], BOOLEAN, allow_blank: true)
  check_date(file, label, "last_verified", row["last_verified"])
end

# --- reviews -----------------------------------------------------------------
review_slugs = []
Dir.glob(REVIEWS_GLOB).sort.each do |path|
  file = "reviews/#{File.basename(path)}"
  raw  = File.read(path, encoding: "bom|utf-8")

  unless raw =~ /\A---\n(.+?)\n---\n(.*)\z/m
    error "#{file}: missing front matter — the file must start with a --- ... --- block"
    next
  end

  begin
    meta = YAML.safe_load(Regexp.last_match(1), permitted_classes: [Date, Time])
  rescue Psych::Exception => e
    error "#{file}: front matter is not valid YAML (#{e.message.lines.first&.strip})"
    next
  end
  body = Regexp.last_match(2).strip

  %w[slug tool title].each do |field|
    error "#{file}: front matter is missing #{field.inspect}" if meta[field].to_s.strip.empty?
  end
  error "#{file}: body is empty" if body.empty?

  slug = meta["slug"].to_s
  error "#{file}: duplicate slug #{slug.inspect}" if review_slugs.include?(slug)
  review_slugs << slug
  unless slug.match?(/\A[a-z0-9]+(-[a-z0-9]+)*\z/)
    error "#{file}: slug #{slug.inspect} should be a lowercase-hyphen slug"
  end

  unless tool_names.include?(meta["tool"].to_s.strip)
    error "#{file}: tool #{meta["tool"].inspect} is not a tool in the catalogue CSV"
  end

  if meta["rating"] && !(meta["rating"].is_a?(Integer) && (1..5).cover?(meta["rating"]))
    error "#{file}: rating #{meta["rating"].inspect} must be a whole number from 1 to 5"
  end

  if meta["published_at"]
    begin
      Time.parse(meta["published_at"].to_s)
    rescue ArgumentError
      error "#{file}: published_at #{meta["published_at"].inspect} is not a valid date/time"
    end
  end
end

# --- result ------------------------------------------------------------------
if @errors.any?
  warn "Catalogue lint found #{@errors.size} problem#{"s" if @errors.size != 1}:\n\n"
  @errors.each { |e| warn "  ✗ #{e}" }
  exit 1
end

puts "Catalogue lint: OK (#{tool_names.size} tools, #{variant_keys.size} variants, #{review_slugs.size} reviews)"
