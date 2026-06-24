module ApplicationHelper
  # Single brand gradient: warm orange -> pink. Used for the brand wordmark
  # and buttons — no longer randomised.
  SESSION_GRADIENTS = [
    %w[#f5a623 #ec4565]
  ].freeze

  # Cool gradient (pink -> purple -> blue) used for the soft glow and hover
  # shadows, distinct from the warm brand gradient.
  GLOW_GRADIENT = %w[#ec4565 #8d6fd1 #53aaf6].freeze
  def session_gradient_palettes
    SESSION_GRADIENTS
  end

  # Format a 1-10 score/verdict: "8.4", "9", or nil.
  def score_number(value)
    return nil if value.nil?

    n = value.to_f.round(1)
    (n % 1).zero? ? n.to_i.to_s : n.to_s
  end

  # A score cell that falls back to an em dash when unrated.
  def score_or_dash(value)
    score_number(value) || content_tag(:span, "—", class: "score-none", title: "Not yet rated")
  end

  # A visible 1-10 score coloured by the same muted grey→teal scale.
  def colored_score(value, css_class: nil)
    return score_or_dash(value) if value.nil?

    content_tag(:span, score_number(value), class: css_class, style: "color: #{score_color(value)}")
  end

  def search_card_score_visible?
    Rails.configuration.x.search.show_card_score == true
  end

  def latest_in_ai_enabled?
    FeatureFlags.latest_in_ai?
  end

  def model_value_metrics_enabled?
    FeatureFlags.model_value_metrics?
  end

  def yes_no_or_unknown(value)
    return "Unknown" if value.nil?

    value ? "Yes" : "No"
  end

  def fact_or_unknown(value)
    value.present? ? value.to_s.humanize : "Unknown"
  end

  # --- context-aware scorecard helpers -------------------------------------
  # The criteria (label + 1-10 score) for the dimension a search matched, so a
  # result card can surface exactly the sub-scores that matter for the task.
  # Returns [[label, score_or_nil], ...]; score is nil when not yet rated.
  def dimension_criteria(tool, dimension, limit: 4)
    fields = Rubric.fields_for(dimension)
    return [] if fields.empty?

    fields.first(limit).map do |field|
      label = Rubric::SUBCATEGORY_FIELDS.key(field) || field.to_s.humanize
      [label, tool.best_score(field)]
    end
  end

  # The headline score a card/detail should lead with given the search intent:
  # the matched dimension's score when we have one, else the overall verdict.
  # Returns [value_or_nil, short_caption].
  def headline_score(tool, dimension)
    config = Rubric.dimensions[dimension]
    if config
      # Lead with the matched dimension; caption reflects the task even before
      # it's scored, so the pill reads "— / Coding" not "— / Overall".
      [tool.dimension_score(dimension) || tool.overall_verdict, config[:short_label]]
    else
      [tool.overall_verdict, "Overall"]
    end
  end

  # A horizontal score bar (1-10). Width + colour track the value; a nil value
  # renders an empty "not yet rated" track.
  def score_bar(label, value)
    pct = value.nil? ? 0 : (value.to_f.clamp(0, 10) * 10).round
    val = value.nil? ? content_tag(:span, "—", class: "score-none") : score_number(value)
    fill = value.nil? ? "" : tag.span(class: "bar-fill", style: "width: #{pct}%; background: #{score_fill_color(value)}")

    content_tag(:div, class: "bar-row") do
      content_tag(:div, class: "bar-top") do
        content_tag(:span, label, class: "bar-label") + content_tag(:span, val.html_safe, class: "bar-val")
      end + content_tag(:div, fill.presence&.html_safe || "", class: "bar-track")
    end
  end

  # Per-category scores for a tool. Sorted best-first by default for summaries
  # and commentary; callers can keep rubric order for comparison surfaces.
  # Only categories the tool is actually scored on are returned.
  def tool_category_breakdown(tool, model_variant: nil, sort_by_score: true)
    icons = Category.pluck(:slug, :icon).to_h
    breakdown = Rubric.categories.filter_map do |name, config|
      score = tool_category_score(tool, name, config, model_variant:)
      unavailable_message = category_unavailable_message(tool, name, model_variant:, score:)
      next if score.nil? && unavailable_message.nil?

      {
        name: name,
        display_name: score_category_display_name(name),
        key: config[:key],
        score: score&.round(1),
        icon: config[:icon].presence || icons[config[:key]].presence || "sparkles",
        fields: config[:fields].keys,
        unavailable_message: unavailable_message
      }
    end

    sort_by_score ? breakdown.sort_by { |c| [c[:score].nil? ? 1 : 0, -(c[:score] || 0)] } : breakdown
  end

  def tool_category_score(tool, category_name, config, model_variant: nil)
    fields = config[:fields].keys
    if model_variant
      return nil unless model_variant.scored?
      return nil unless tool.variant_scored_for_fields?(model_variant, fields)

      model_variant.category_score(fields, extra_scores: tool.rubric_field_values, category: category_name)
    else
      tool.comparison_category_score(fields)
    end
  end

  def unavailable_score_category_backdrop
    Rubric.categories.map do |name, config|
      {
        name: name,
        display_name: score_category_display_name(name),
        key: config[:key],
        score: 5.0,
        icon: config[:icon].presence || "sparkles",
        fields: config[:fields].keys
      }
    end
  end

  def model_usage_metric_row(tool, selected_model_variant: nil)
    variants = tool.model_variants.ordered
    variants_with_metrics = variants.select { |variant| model_usage_metrics_present?(variant) }
    selected_variant = selected_model_variant || tool.best_model_variant || variants_with_metrics.first
    return nil unless selected_variant
    latency_max = usage_metric_scale_max(:avg_latency_seconds, :time)
    token_max = usage_metric_scale_max(:avg_total_tokens, :tokens)

    metrics = [
      usage_metric_payload(
        kind: "time",
        label: "Avg time (in seconds)",
        icon: "stopwatch",
        value: usage_metric_number(selected_variant.avg_latency_seconds),
        max: latency_max,
        formatted_value: format_latency_metric(selected_variant.avg_latency_seconds)
      ),
      usage_metric_payload(
        kind: "tokens",
        label: "Avg tokens",
        icon: "currency-dollar",
        value: usage_metric_number(selected_variant.avg_total_tokens),
        max: token_max,
        formatted_value: format_token_metric(selected_variant.avg_total_tokens)
      )
    ].compact

    {
      variant: selected_variant,
      fallback: selected_model_variant.nil?,
      unavailable: metrics.empty?,
      metrics: metrics
    }
  end

  def model_value_metric_row(tool, selected_model_variant: nil)
    variants = tool.model_variants.ordered
    variants_with_metrics = variants.select { |variant| model_value_metrics_present?(tool, variant) }
    selected_variant = selected_model_variant || tool.best_model_variant || variants_with_metrics.first
    return nil unless selected_variant

    token_values = variants.index_with { |variant| variant.performance_per_1k_tokens }.compact
    api_values = variants.index_with { |variant| variant.api_performance_per_dollar }.compact
    overall_values = variants.index_with { |variant| variant.value_overall_score }.compact

    metrics = [
      value_metric_payload(
        kind: "overall",
        label: "Overall value score",
        icon: "sparkles",
        value: overall_values[selected_variant],
        max: 10.0,
        score: true
      ),
      value_metric_payload(
        kind: "tokens",
        label: "Performance per 1k tokens",
        icon: "trend-up",
        value: token_values[selected_variant],
        max: token_values.values.max
      ),
      value_metric_payload(
        kind: "api",
        label: "Performance per $",
        icon: "currency-dollar",
        value: api_values[selected_variant],
        max: api_values.values.max
      )
    ].compact

    {
      variant: selected_variant,
      fallback: selected_model_variant.nil?,
      unavailable: metrics.empty?,
      metrics: metrics
    }
  end

  # Per-selected-variant API pricing, in the same tile shape as the usage row.
  # Prices are shown as plain numbers (no band chip): a higher price usually
  # means a premium model, not a worse one, so a red/green verdict would mislead.
  def model_pricing_metric_row(tool, selected_model_variant: nil)
    variants = tool.model_variants.ordered
    variants_with_pricing = variants.select { |variant| model_pricing_present?(variant) }
    selected_variant = selected_model_variant || tool.best_model_variant || variants_with_pricing.first
    return nil unless selected_variant

    unit = selected_variant.pricing_unit.presence || "per 1M tokens"
    metrics = [
      pricing_metric_payload(kind: "input", label: "Input", icon: "currency-dollar", value: selected_variant.input_usd_per_m),
      pricing_metric_payload(kind: "output", label: "Output", icon: "credit-card", value: selected_variant.output_usd_per_m)
    ].compact

    {
      variant: selected_variant,
      unit: unit,
      fallback: selected_model_variant.nil?,
      unavailable: metrics.empty?,
      metrics: metrics
    }
  end

  def score_category_display_name(name)
    name.to_s.casecmp("Accuracy & trustworthiness").zero? ? "Trustworthiness" : name
  end

  def category_unavailable_message(tool, name, model_variant:, score:)
    return nil unless score.nil?
    return nil unless name.to_s == "Transcription"
    return nil unless model_variant&.scored?
    return nil if model_variant.transcription_score.present?

    has_related_meeting_signal =
      model_variant.meeting_summary_score.present? ||
      model_variant.follow_up_score.present? ||
      tool.has_transcription?
    return nil unless has_related_meeting_signal

    "We were unable to test this functionality."
  end

  def format_efficiency_latency(value)
    formatted = format_latency_metric(value)
    formatted ? "#{formatted}s" : "—"
  end

  def format_efficiency_tokens(value, unit: true)
    formatted = format_token_metric(value)
    return "—" unless formatted

    unit ? "#{formatted} tokens" : formatted
  end

  # The sub-criteria inside one category: [label, score, what-it-measures, score-field].
  def category_criteria(tool, fields, model_variant: nil, category: nil)
    fields.map do |field|
      label = Rubric::SUBCATEGORY_FIELDS.key(field) || field.to_s.humanize
      score = category_criterion_score(tool, field, model_variant:, category:)
      [label, score&.round(1), Rubric::CRITERION_MEASURES[field], field]
    end
  end

  def category_reasoning_summary(tool, cat, model_variant: nil)
    notes = category_evaluation_notes(cat, model_variant)
    if notes.any?
      criteria = category_criteria(tool, cat[:fields], model_variant:, category: cat[:name])
      return prompt_grade_note_summary(notes, criteria:)
    end

    nil
  end

  def category_evaluation_notes(cat, model_variant)
    return [] unless model_variant

    fields = Array(cat[:fields]).map(&:to_s)
    category_names = [cat[:name], cat[:display_name]].map(&:to_s).map(&:downcase)
    model_variant.evaluation_notes.to_a.select do |note|
      fields.include?(note.score_field.to_s) || category_names.include?(note.category.to_s.downcase)
    end
  end

  PROMPT_GRADE_STRENGTH_THEMES = [
    ["fast, efficient execution", /\b(?:fast|quick|speed|efficient|concise|direct|rapid|responsive)\b/i],
    ["clear, readable structure", /\b(?:clear|structured|structure|readable|organized|coherent|well[- ]?organized)\b/i],
    ["accurate, complete outputs", /\b(?:correct|accurate|complete|thorough|comprehensive|valid|matches|covers)\b/i],
    ["useful reasoning", /\b(?:reasoning|explain|explanation|justification|analysis|rationale)\b/i],
    ["practical polish", /\b(?:useful|usable|helpful|actionable|practical|polished|refined)\b/i]
  ].freeze

  PROMPT_GRADE_ISSUE_THEMES = [
    ["edge-case reliability", /\b(?:edge case|edge-case|edgecase|error|bug|missed|missing|fails?|failure)\b/i],
    ["validation gaps", /\b(?:test|tests|testing|coverage|validate|validation|verified|verification)\b/i],
    ["completeness gaps", /\b(?:incomplete|missing|omits?|lacks?|gap|underdeveloped|not enough)\b/i],
    ["clarity issues", /\b(?:unclear|confusing|disorganized|hard to follow|readability|structure)\b/i],
    ["accuracy risks", /\b(?:incorrect|inaccurate|wrong|hallucinat|unsupported|misleading)\b/i],
    ["consistency issues", /\b(?:inconsistent|inconsistency|uneven|variable|varies)\b/i],
    ["format issues", /\b(?:format|instruction|constraint|requirement)\b/i]
  ].freeze

  def prompt_grade_note_summary(notes, criteria: [])
    strengths = prompt_grade_themes(
      notes.flat_map { |note| [note.strengths, note.reasoning] },
      PROMPT_GRADE_STRENGTH_THEMES,
      limit: 2
    )
    issues = prompt_grade_themes(
      notes.map(&:issues),
      PROMPT_GRADE_ISSUE_THEMES,
      limit: 2
    )
    scored = Array(criteria).select { |_label, score, _measure, _field| score.present? }
    strong = scored
      .select { |_label, score, _measure, _field| score.to_f >= 7.5 }
      .sort_by { |_label, score, _measure, _field| -score.to_f }
      .first(2)
    weak = scored
      .select { |_label, score, _measure, _field| score.to_f < 6.5 }
      .sort_by { |_label, score, _measure, _field| score.to_f }
      .first(2)

    if strong.any? && weak.any?
      return [
        "We saw strong #{criterion_summary_labels(strong).to_sentence}, but #{criterion_summary_labels(weak).to_sentence} pulled the score down.",
        prompt_grade_watch_sentence(issues)
      ].compact.join(" ")
    elsif weak.any?
      return [
        "The score is held back by #{criterion_summary_labels(weak).to_sentence}.",
        prompt_grade_watch_sentence(issues)
      ].compact.join(" ")
    elsif strong.any?
      return [
        "We saw strong #{criterion_summary_labels(strong).to_sentence}.",
        strengths.any? ? "The notes point to #{strengths.to_sentence}." : nil,
        prompt_grade_watch_sentence(issues)
      ].compact.first(2).join(" ")
    elsif scored.any?
      return [
        "The sub-scores are fairly even, so the result reflects steady category-level performance.",
        prompt_grade_watch_sentence(issues)
      ].compact.join(" ")
    end

    if strengths.any? && issues.any?
      "We saw #{strengths.to_sentence}. We'd watch for #{issues.to_sentence}."
    elsif strengths.any?
      "We saw #{strengths.to_sentence}."
    elsif issues.any?
      "We'd watch for #{issues.to_sentence}."
    else
      "We imported notes for this category, but they did not include written reasoning."
    end
  end

  def criterion_summary_labels(criteria)
    criteria.map { |label, _score, _measure, _field| label.to_s.downcase }
  end

  def prompt_grade_watch_sentence(issues)
    "We'd watch for #{issues.to_sentence}." if issues.any?
  end

  def score_based_category_summary(tool, cat, model_variant: nil)
    criteria = category_criteria(tool, cat[:fields], model_variant:, category: cat[:name])
    scored = criteria.select { |_label, score, _measure, _field| score.present? }
    subject = model_variant&.name || tool.name
    return "We have a category score for #{subject}, but no subcategory notes have been imported yet." if scored.empty?

    strongest = scored.select { |_label, score, _measure, _field| score.to_f >= 7.5 }.sort_by { |_label, score, _measure, _field| -score.to_f }.first(2)
    weakest = scored.select { |_label, score, _measure, _field| score.to_f < 6.5 }.sort_by { |_label, score, _measure, _field| score.to_f }.first(2)

    parts = []
    if strongest.any?
      parts << "#{subject} is strongest on #{strongest.map(&:first).to_sentence}"
    end
    if weakest.any?
      parts << "it loses ground on #{weakest.map(&:first).to_sentence}"
    elsif strongest.size < scored.size
      steady = (scored.map(&:first) - strongest.map(&:first)).first(2)
      parts << "the remaining criteria are steadier rather than standout" if steady.any?
    end
    parts << "the score reflects the available rubric signals" if parts.empty?

    summary = parts.join("; ")
    summary.sub(/\A\w/) { |char| char.upcase } + "."
  end

  def category_criterion_score(tool, field, model_variant: nil, category: nil)
    if model_variant
      return nil unless model_variant.scored?

      model_variant.category_score([field], extra_scores: tool.rubric_field_values, category:)
    else
      tool.comparison_category_score([field])
    end
  end

  def prompt_grade_themes(values, theme_map, limit:)
    text = Array(values).flatten.compact.map(&:to_s).reject(&:blank?).join("\n")
    return [] if text.blank?

    themes = theme_map.filter_map do |label, pattern|
      count = text.scan(pattern).size
      [label, count] if count.positive?
    end

    themes
      .sort_by { |_label, count| -count }
      .map(&:first)
      .first(limit)
  end

  # A short product-page take generated from verdict data. Keep this concise:
  # the page already shows the score and detailed breakdown nearby.
  def tool_verdict_commentary(tool)
    v = tool.overall_verdict
    return ["We haven't finished testing #{tool.name} yet, so our take is still on the way."] if v.nil?

    breakdown = tool_category_breakdown(tool)
    bottom = breakdown.size > 1 ? breakdown.last : nil

    tier =
      if v >= 8.5 then "one of the strongest tools we've tested"
      elsif v >= 7.5 then "a confident, well-rounded choice"
      elsif v >= 6.5 then "a capable option with clear trade-offs"
      else "a niche pick that only fits specific needs"
      end

    best = tool.verdict_best_for.map(&:downcase)
    weak = tool.verdict_not_ideal_for.map(&:downcase)

    tradeoffs = weak.presence || (bottom && bottom[:score] < 7 ? [bottom[:name].downcase] : [])
    sentence = +"#{tool.name} is #{tier}"
    sentence << " for #{best.to_sentence}" if best.any?
    sentence << ", with #{tradeoffs.to_sentence} as the main #{'trade-off'.pluralize(tradeoffs.size)}" if tradeoffs.any?

    ["#{sentence}."]
  end

  # Weighted category score for a single ModelVariant (mirrors Tool#comparison_category_score
  # but operates directly on the variant's own score columns).
  def variant_category_score(variant, fields)
    all_weights = Rubric.categories.values.flat_map { |c| c[:fields].to_a }.to_h
    pairs = fields.filter_map do |field|
      raw = variant.send(field) rescue nil
      next if raw.blank?
      [raw.to_f, all_weights[field] || 1.0]
    end
    return nil if pairs.empty?
    total_w = pairs.sum(&:last)
    return nil if total_w.zero?
    (pairs.sum { |s, w| s * w } / total_w).round(1)
  end

  # Scores fall into three pastel bands so quality reads at a glance: weak
  # (< 5) red, medium (5–7.5) amber, strong (7.5+) teal-green. Each band pairs a
  # soft fill (for bars/dots) with a darker shade (for numbers, legible on white)
  # — red/amber/green mean worse/middling/better everywhere, including the
  # efficiency and value metrics.
  SCORE_BANDS = {
    weak: { fill: [232, 154, 147], text: [163, 61, 45] },
    medium: { fill: [237, 192, 102], text: [133, 91, 11] },
    strong: { fill: [98, 179, 148], text: [31, 110, 86] }
  }.freeze
  USAGE_METRIC_SCALE_STEPS = {
    time: 10.0,
    tokens: 500.0
  }.freeze
  USAGE_METRIC_SCALE_FALLBACKS = {
    time: 60.0,
    tokens: 3_500.0
  }.freeze
  # One-word verdicts per efficiency metric, keyed by goodness band. The chip
  # carries the colour signal so the raw number stays high-contrast in both
  # themes — a bar length would imply a meaningful max these metrics don't have.
  USAGE_METRIC_QUALIFIERS = {
    time: { strong: "Fast", medium: "Average", weak: "Slow" },
    tokens: { strong: "Lean", medium: "Average", weak: "Heavy" }
  }.freeze

  def score_band(value)
    n = value.to_f
    return :weak if n < 5.0
    return :medium if n < 7.5

    :strong
  end

  # Maps a 0..1 goodness ratio (higher = better) onto the same bands, so metrics
  # share the score thresholds: 7.5/10 and 5/10.
  def goodness_band(ratio)
    return :strong if ratio >= 0.75
    return :medium if ratio >= 0.5

    :weak
  end

  # Darker shade — for score numbers and other text on white.
  def score_color(value)
    return nil if value.nil?

    "rgb(#{SCORE_BANDS[score_band(value)][:text].join(", ")})"
  end

  # Soft pastel — for bar fills and dots.
  def score_fill_color(value)
    return nil if value.nil?

    "rgb(#{SCORE_BANDS[score_band(value)][:fill].join(", ")})"
  end

  # The one-word verdict for an efficiency metric ("Fast"/"Lean"/…), or nil when
  # the metric has no band (missing value).
  def usage_metric_qualifier(kind, band)
    return nil unless band

    USAGE_METRIC_QUALIFIERS.dig(kind.to_sym, band)
  end

  # Value is higher-is-better, so the raw ratio maps straight onto the bands.
  def value_metric_color(value, max)
    band = value_metric_band(value, max)
    band && "rgb(#{SCORE_BANDS[band][:text].join(", ")})"
  end

  def value_metric_fill_color(value, max)
    band = value_metric_band(value, max)
    band && "rgb(#{SCORE_BANDS[band][:fill].join(", ")})"
  end

  # Efficiency is lower-is-better, so invert the ratio: a low value (fast/cheap)
  # lands in the strong band.
  def usage_metric_band(value, max)
    ratio = usage_metric_ratio(value, max)
    ratio && goodness_band(1.0 - ratio)
  end

  def value_metric_band(value, max)
    ratio = usage_metric_ratio(value, max)
    ratio && goodness_band(ratio)
  end

  # Gradient custom properties: the warm brand gradient for the wordmark and
  # buttons, plus the cool glow gradient for the search glow and hover shadows.
  # The page background itself stays plain white.
  def page_gradient_style(gradient = nil)
    [
      "--session-gradient: #{gradient_value(gradient, alpha: 1.0)}",
      "--button-gradient: #{button_gradient_value(gradient)}",
      "--glow-gradient: #{glow_gradient_value}",
      "--hover-shadow-a: #{glow_shadow_stop(0, alpha: 0.04)}",
      "--hover-shadow-b: #{glow_shadow_stop(1, alpha: 0.036)}",
      "--hover-shadow-c: #{glow_shadow_stop(2, alpha: 0.032)}"
    ].join("; ") + ";"
  end

  private

  def model_usage_metrics_present?(variant)
    usage_metric_number(variant.avg_latency_seconds).present? || usage_metric_number(variant.avg_total_tokens).present?
  end

  def model_value_metrics_present?(_tool, variant)
    variant.value_overall_score.present? ||
      variant.performance_per_1k_tokens.present? ||
      variant.api_performance_per_dollar.present?
  end

  def model_pricing_present?(variant)
    usage_metric_number(variant.input_usd_per_m).present? ||
      usage_metric_number(variant.output_usd_per_m).present?
  end

  def pricing_metric_payload(kind:, label:, icon:, value:)
    number = usage_metric_number(value)
    return nil if number.nil?

    formatted = (number % 1).zero? ? number.to_i.to_s : number.to_s
    {
      kind: kind,
      label: label,
      icon: icon,
      value: "$#{formatted}"
    }
  end

  def value_metric_payload(kind:, label:, icon:, value:, max:, score: false)
    return nil if value.nil? || max.nil? || max <= 0

    ratio = usage_metric_ratio(value, max) || 0
    width = ratio.zero? ? 0 : [(ratio * 100).round, 4].max

    {
      kind: kind,
      label: label,
      icon: icon,
      value: score ? score_number(value) : format_value_metric(value),
      ratio: ratio.round(3),
      width: width,
      color: value_metric_color(value, max),
      fill_color: value_metric_fill_color(value, max)
    }
  end

  def usage_metric_payload(kind:, label:, icon:, value:, max:, formatted_value:)
    return nil if value.nil? || formatted_value.nil?

    band = usage_metric_band(value, max)
    {
      kind: kind,
      label: label,
      icon: icon,
      value: formatted_value,
      band: band,
      qualifier: usage_metric_qualifier(kind, band),
      color: band && "rgb(#{SCORE_BANDS[band][:text].join(", ")})"
    }
  end

  def usage_metric_number(value)
    return nil if value.blank?

    Float(value)
  rescue ArgumentError, TypeError
    nil
  end

  def usage_metric_ratio(value, max)
    value = usage_metric_number(value)
    max = usage_metric_number(max)
    return nil if value.nil? || max.nil? || max <= 0

    (value / max).clamp(0.0, 1.0)
  end

  def usage_metric_scale_max(column, kind)
    @usage_metric_scale_max ||= {}
    @usage_metric_scale_max[[column, kind]] ||= begin
      observed_max = usage_metric_number(ModelVariant.maximum(column))
      fallback = USAGE_METRIC_SCALE_FALLBACKS.fetch(kind)
      if observed_max.nil? || observed_max <= 0
        fallback
      else
        step = USAGE_METRIC_SCALE_STEPS.fetch(kind)
        (observed_max / step).ceil * step
      end
    end
  end

  def format_latency_metric(value)
    number = usage_metric_number(value)
    return nil if number.nil?

    format("%.1f", number)
  end

  def format_token_metric(value)
    number = usage_metric_number(value)
    return nil if number.nil?

    number_with_delimiter(number.round)
  end

  def format_value_metric(value)
    number = usage_metric_number(value)
    return nil if number.nil?

    if number >= 1_000
      formatted = format("%.1f", number / 1_000.0)
      "#{formatted.delete_suffix(".0")}k"
    elsif number >= 100
      number_with_delimiter(number.round)
    elsif number >= 10
      format("%.1f", number)
    else
      format("%.2f", number)
    end
  end

  def gradient_value(gradient = nil, alpha:)
    gradient ||= {}
    angle = gradient["angle"] || 120
    colors = Array(gradient["colors"]).presence || SESSION_GRADIENTS.first
    stops = colors.map { |hex| rgba(hex, alpha) }

    "linear-gradient(#{angle}deg, #{stops.join(", ")})"
  end

  def button_gradient_value(gradient = nil)
    gradient ||= {}
    angle = gradient["angle"] || 120
    colors = Array(gradient["colors"]).presence || SESSION_GRADIENTS.first
    stops = colors.map { |hex| saturate(hex, 1.55) }

    "linear-gradient(#{angle}deg, #{stops.join(", ")})"
  end

  # The cool glow gradient as a CSS linear-gradient (full alpha; the glow
  # element softens it via opacity/blur).
  def glow_gradient_value
    stops = GLOW_GRADIENT.map { |hex| rgba(hex, 1.0) }
    "linear-gradient(135deg, #{stops.join(", ")})"
  end

  # One stop of the glow gradient at a low alpha, for the hover shadow.
  def glow_shadow_stop(index, alpha:)
    rgba(GLOW_GRADIENT.fetch(index, GLOW_GRADIENT.last), alpha)
  end

  def rgba(hex, alpha)
    rgb = hex.delete_prefix("#").scan(/../).map { |pair| pair.to_i(16) }
    "rgba(#{rgb.join(", ")}, #{alpha})"
  end

  def saturate(hex, factor)
    r, g, b = hex.delete_prefix("#").scan(/../).map { |pair| pair.to_i(16) / 255.0 }
    h, s, l = rgb_to_hsl(r, g, b)
    hsl_to_rgb(h, [s * factor, 1.0].min, l)
  end

  def rgb_to_hsl(r, g, b)
    max = [r, g, b].max
    min = [r, g, b].min
    lightness = (max + min) / 2.0
    return [0, 0, lightness] if max == min

    delta = max - min
    saturation = lightness > 0.5 ? delta / (2.0 - max - min) : delta / (max + min)
    hue =
      case max
      when r then ((g - b) / delta + (g < b ? 6 : 0)) / 6.0
      when g then ((b - r) / delta + 2) / 6.0
      else ((r - g) / delta + 4) / 6.0
      end

    [hue, saturation, lightness]
  end

  def hsl_to_rgb(hue, saturation, lightness)
    if saturation.zero?
      channel = (lightness * 255).round
      return "rgb(#{channel}, #{channel}, #{channel})"
    end

    q = lightness < 0.5 ? lightness * (1 + saturation) : lightness + saturation - lightness * saturation
    p = 2 * lightness - q
    rgb = [hue + 1.0 / 3, hue, hue - 1.0 / 3].map do |t|
      t += 1 if t < 0
      t -= 1 if t > 1

      channel =
        if t < 1.0 / 6
          p + (q - p) * 6 * t
        elsif t < 1.0 / 2
          q
        elsif t < 2.0 / 3
          p + (q - p) * (2.0 / 3 - t) * 6
        else
          p
        end

      (channel * 255).round.clamp(0, 255)
    end

    "rgb(#{rgb.join(", ")})"
  end

  def source_favicon_url(source_url)
    return nil if source_url.blank?
    host = URI.parse(source_url).host
    return nil unless host
    "https://www.google.com/s2/favicons?domain=#{host}&sz=32"
  rescue URI::InvalidURIError
    nil
  end

  POST_TYPE_COLORS = {
    "practical_update" => "#1d4ed8",
    "hype_check"       => "#92400e",
    "score_update"     => "#6d28d9",
    "roundup"          => "#065f46",
    "general"          => "#4b5563"
  }.freeze

  def post_type_color(post_type)
    POST_TYPE_COLORS.fetch(post_type.to_s, "#4b5563")
  end
end
