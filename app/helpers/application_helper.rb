module ApplicationHelper
  # Single brand gradient: warm orange -> pink. Used for the brand wordmark
  # and buttons — no longer randomised.
  SESSION_GRADIENTS = [
    %w[#f5a623 #ec4565]
  ].freeze

  # Cool gradient (pink -> purple -> blue) used for the soft glow and hover
  # shadows, distinct from the warm brand gradient.
  GLOW_GRADIENT = %w[#ec4565 #8d6fd1 #53aaf6].freeze
  PRODUCT_SUBSCRIPTION_MONTHLY_USD = {
    "ChatGPT" => 20.0,
    "Claude" => 20.0,
    "Google Gemini" => 19.99,
    "Microsoft Copilot" => 19.99,
    "Perplexity" => 20.0,
    "GitHub Copilot" => 10.0,
    "Cursor" => 20.0,
    "Mistral Le Chat" => 14.99,
    "DeepL" => 8.74,
    "Grammarly" => 30.0,
    "Jasper" => 69.0,
    "Otter.ai" => 16.99,
    "Poe" => 4.17,
    "xAI Grok" => 30.0
  }.freeze

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
    config = Rubric::DIMENSIONS[dimension]
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
    fill = value.nil? ? "" : tag.span(class: "bar-fill", style: "width: #{pct}%; background: #{score_color(value)}")

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
    breakdown = Rubric::CATEGORIES.filter_map do |name, config|
      score = tool_category_score(tool, name, config, model_variant:)
      next if score.nil?

      {
        name: name,
        display_name: score_category_display_name(name),
        key: config[:key],
        score: score.round(1),
        icon: config[:icon].presence || icons[config[:key]].presence || "sparkles",
        fields: config[:fields].keys
      }
    end

    sort_by_score ? breakdown.sort_by { |c| -c[:score] } : breakdown
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
    Rubric::CATEGORIES.map do |name, config|
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

    metrics = [
      usage_metric_payload(
        kind: "time",
        label: "Avg time (in seconds)",
        icon: "stopwatch",
        value: usage_metric_number(selected_variant.avg_latency_seconds),
        max: 20.0,
        formatted_value: format_latency_metric(selected_variant.avg_latency_seconds)
      ),
      usage_metric_payload(
        kind: "tokens",
        label: "Avg tokens",
        icon: "currency-dollar",
        value: usage_metric_number(selected_variant.avg_total_tokens),
        max: 700.0,
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

    api_values = variants.index_with { |variant| api_performance_per_dollar(variant) }.compact
    plan_values = variants.index_with { |variant| plan_performance_per_dollar(tool, variant) }.compact

    metrics = [
      value_metric_payload(
        kind: "api",
        label: "API performance per $",
        icon: "currency-dollar",
        value: api_values[selected_variant],
        max: api_values.values.max
      ),
      value_metric_payload(
        kind: "plan",
        label: "Plan performance per $",
        icon: "credit-card",
        value: plan_values[selected_variant],
        max: plan_values.values.max
      )
    ].compact

    {
      variant: selected_variant,
      fallback: selected_model_variant.nil?,
      unavailable: metrics.empty?,
      metrics: metrics
    }
  end

  def score_category_display_name(name)
    name.to_s.casecmp("Accuracy & trustworthiness").zero? ? "Trustworthiness" : name
  end

  # The sub-criteria inside one category: [label, score, what-it-measures].
  def category_criteria(tool, fields)
    fields.map do |field|
      label = Rubric::SUBCATEGORY_FIELDS.key(field) || field.to_s.humanize
      score = tool.comparison_category_score([field])
      [label, score&.round(1), Rubric::CRITERION_MEASURES[field]]
    end
  end

  # A drafted editorial "Our take" — a richer multi-paragraph commentary
  # generated from the tool's verdict data. Sample copy — replace with
  # hand-written commentary per tool later.
  def tool_verdict_commentary(tool)
    v = tool.overall_verdict
    return ["We haven't finished testing #{tool.name} yet — scores and our full take are on the way."] if v.nil?

    breakdown = tool_category_breakdown(tool)
    top = breakdown.first
    bottom = breakdown.size > 1 ? breakdown.last : nil

    tier =
      if v >= 8.5 then "one of the strongest tools we've tested"
      elsif v >= 7.5 then "a confident, well-rounded choice"
      elsif v >= 6.5 then "a capable option with clear trade-offs"
      else "a niche pick that only fits specific needs"
      end

    best = tool.verdict_best_for.map(&:downcase)
    weak = tool.verdict_not_ideal_for.map(&:downcase)

    # Paragraph 1 — the headline judgement.
    p1 = ["At #{score_number(v)}/10 overall, #{tool.name} is #{tier}."]
    if top
      p1 << "Its standout is #{top[:name].downcase} (#{score_number(top[:score])}/10), and it earns its place on #{best.to_sentence}, where our cross-judged tests rate it well." if best.any?
    end

    # Paragraph 2 — the honest trade-offs and who it suits.
    p2 = []
    if bottom && bottom[:score] < 7
      p2 << "Where it slips is #{bottom[:name].downcase} (#{score_number(bottom[:score])}/10)."
    end
    p2 << "The trade-off is #{weak.to_sentence} — go in expecting that." if weak.any?
    p2 << (tool.verdict_free_tier? ? "A usable free tier lowers the risk of trying it for yourself." : "There's no real free tier, so you're committing budget to find out if it fits.")
    p2 << "It's the kind of tool we'd reach for when #{best.first} matters more than breadth." if best.any?

    [p1.join(" "), p2.join(" ")].reject(&:blank?)
  end

  # Weighted category score for a single ModelVariant (mirrors Tool#comparison_category_score
  # but operates directly on the variant's own score columns).
  def variant_category_score(variant, fields)
    all_weights = Rubric::CATEGORIES.values.flat_map { |c| c[:fields].to_a }.to_h
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

  # Colour scores on a calm grey→pastel-teal scale, calibrated to the real
  # distribution: 5 is neutral, 7 is the midpoint, and 9+ earns full teal.
  def score_color(value)
    return nil if value.nil?

    n = value.to_f.clamp(1.0, 10.0)
    ratio = ((n - 5.0) / 4.0).clamp(0.0, 1.0)
    low = [145, 151, 160]
    high = [82, 166, 156]
    rgb = low.zip(high).map { |start, finish| (start + (finish - start) * ratio).round }

    "rgb(#{rgb.join(", ")})"
  end

  def usage_metric_color(value, max)
    ratio = usage_metric_ratio(value, max)
    return "rgb(145, 151, 160)" if ratio.nil?

    low = [145, 151, 160]
    high = [229, 134, 149]
    rgb = low.zip(high).map { |start, finish| (start + (finish - start) * ratio).round }

    "rgb(#{rgb.join(", ")})"
  end

  def value_metric_color(value, max)
    ratio = usage_metric_ratio(value, max)
    return "rgb(145, 151, 160)" if ratio.nil?

    low = [145, 151, 160]
    high = [82, 166, 156]
    rgb = low.zip(high).map { |start, finish| (start + (finish - start) * ratio).round }

    "rgb(#{rgb.join(", ")})"
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

  def model_value_metrics_present?(tool, variant)
    api_performance_per_dollar(variant).present? || plan_performance_per_dollar(tool, variant).present?
  end

  def api_performance_per_dollar(variant)
    score = usage_metric_number(variant.verdict)
    avg_tokens = usage_metric_number(variant.avg_total_tokens)
    blended_price = api_blended_price_per_million(variant)
    return nil if score.nil? || avg_tokens.nil? || blended_price.nil? || blended_price <= 0

    estimated_call_cost = avg_tokens / 1_000_000.0 * blended_price
    return nil unless estimated_call_cost.positive?

    score / estimated_call_cost
  end

  def plan_performance_per_dollar(tool, variant)
    score = usage_metric_number(variant.verdict)
    monthly_cost = subscription_monthly_cost(tool)
    return nil if score.nil? || monthly_cost.nil? || monthly_cost <= 0

    score / monthly_cost
  end

  def api_blended_price_per_million(variant)
    prices = [variant.input_usd_per_m, variant.output_usd_per_m].filter_map { |price| usage_metric_number(price) }
    return nil if prices.empty?

    prices.sum / prices.size
  end

  def subscription_monthly_cost(tool)
    configured = PRODUCT_SUBSCRIPTION_MONTHLY_USD[tool.name]
    return configured if configured.present?
    return nil unless tool.price_low_usd.present?
    return nil unless monthly_pricing_unit?(tool.pricing_unit)

    usage_metric_number(tool.price_low_usd)
  end

  def monthly_pricing_unit?(unit)
    unit.blank? || unit.to_s.match?(/mo|month/i)
  end

  def value_metric_payload(kind:, label:, icon:, value:, max:)
    return nil if value.nil? || max.nil? || max <= 0

    ratio = usage_metric_ratio(value, max) || 0
    width = ratio.zero? ? 0 : [(ratio * 100).round, 4].max

    {
      kind: kind,
      label: label,
      icon: icon,
      value: format_value_metric(value),
      ratio: ratio.round(3),
      width: width,
      color: value_metric_color(value, max)
    }
  end

  def usage_metric_payload(kind:, label:, icon:, value:, max:, formatted_value:)
    return nil if value.nil? || formatted_value.nil?

    ratio = usage_metric_ratio(value, max) || 0
    width = ratio.zero? ? 0 : [(ratio * 100).round, 4].max

    {
      kind: kind,
      label: label,
      icon: icon,
      value: formatted_value,
      ratio: ratio.round(3),
      width: width,
      color: usage_metric_color(value, max)
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
