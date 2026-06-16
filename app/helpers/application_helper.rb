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

  # A visible 1-10 score coloured by the same red→green scale.
  def colored_score(value, css_class: nil)
    return score_or_dash(value) if value.nil?

    content_tag(:span, score_number(value), class: css_class, style: "color: #{score_color(value)}")
  end

  def yes_no_or_unknown(value)
    return "Unknown" if value.nil?

    value ? "Yes" : "No"
  end

  def fact_or_unknown(value)
    value.present? ? value.to_s.humanize : "Unknown"
  end

  # Colour a 1-10 score on a red→green scale: 1 is red, 10 is green.
  def score_color(value)
    return nil if value.nil?

    n = value.to_f.clamp(1.0, 10.0)
    hue = ((n - 1) / 9.0 * 120).round # 0 = red, 120 = green
    "hsl(#{hue}, 72%, 42%)"
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
end
