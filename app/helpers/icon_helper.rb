module IconHelper
  # Inline SVG icons (Tabler outline paths) — CSP-safe, no external font.
  # Keys match the names stored on Category#icon plus a few UI icons.
  ICON_PATHS = {
    "pencil" => '<path d="M4 20h4l10.5 -10.5a2.828 2.828 0 1 0 -4 -4l-10.5 10.5v4"/><path d="M13.5 6.5l4 4"/>',
    "message-chatbot" => '<path d="M4 21v-13a3 3 0 0 1 3 -3h10a3 3 0 0 1 3 3v6a3 3 0 0 1 -3 3h-9l-4 4"/><path d="M9.5 9h.01"/><path d="M14.5 9h.01"/><path d="M9.5 13a3.5 3.5 0 0 0 5 0"/>',
    "message" => '<path d="M8 9h8"/><path d="M8 13h6"/><path d="M18 4a3 3 0 0 1 3 3v8a3 3 0 0 1 -3 3h-5l-5 3v-3h-2a3 3 0 0 1 -3 -3v-8a3 3 0 0 1 3 -3h12z"/>',
    "code" => '<path d="M7 8l-4 4l4 4"/><path d="M17 8l4 4l-4 4"/><path d="M14 4l-4 16"/>',
    "file-text" => '<path d="M14 3v4a1 1 0 0 0 1 1h4"/><path d="M17 21h-10a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2h7l5 5v11a2 2 0 0 1 -2 2z"/><path d="M9 13l6 0"/><path d="M9 17l6 0"/>',
    "search" => '<path d="M10 10m-7 0a7 7 0 1 0 14 0a7 7 0 1 0 -14 0"/><path d="M21 21l-6 -6"/>',
    "microphone" => '<path d="M9 2m0 3a3 3 0 0 1 3 -3a3 3 0 0 1 3 3v5a3 3 0 0 1 -3 3a3 3 0 0 1 -3 -3z"/><path d="M5 10a7 7 0 0 0 14 0"/><path d="M8 21l8 0"/><path d="M12 17l0 4"/>',
    "language" => '<path d="M4 5h7"/><path d="M9 3v2c0 4.418 -2.239 8 -5 8"/><path d="M5 9c0 2.144 2.952 3.908 6.7 4"/><path d="M12 20l4 -9l4 9"/><path d="M19.1 18h-6.2"/>',
    "shield-lock" => '<path d="M12 3a12 12 0 0 0 8.5 3a12 12 0 0 1 -8.5 15a12 12 0 0 1 -8.5 -15a12 12 0 0 0 8.5 -3"/><path d="M12 11m-1 0a1 1 0 1 0 2 0a1 1 0 1 0 -2 0"/><path d="M12 12l0 2.5"/>',
    "building" => '<path d="M3 21l18 0"/><path d="M9 8l1 0"/><path d="M9 12l1 0"/><path d="M9 16l1 0"/><path d="M14 8l1 0"/><path d="M14 12l1 0"/><path d="M5 21v-16a2 2 0 0 1 2 -2h10a2 2 0 0 1 2 2v16"/>',
    "photo" => '<path d="M15 8h.01"/><path d="M3 6a3 3 0 0 1 3 -3h12a3 3 0 0 1 3 3v12a3 3 0 0 1 -3 3h-12a3 3 0 0 1 -3 -3v-12z"/><path d="M3 16l5 -5c.928 -.893 2.072 -.893 3 0l5 5"/><path d="M14 14l1 -1c.928 -.893 2.072 -.893 3 0l3 3"/>',
    "bolt" => '<path d="M13 3l0 7l6 0l-8 11l0 -7l-6 0l8 -11"/>',
    "currency-dollar" => '<path d="M16.7 8a3 3 0 0 0 -2.7 -2h-4a3 3 0 0 0 0 6h4a3 3 0 0 1 0 6h-4a3 3 0 0 1 -2.7 -2"/><path d="M12 3v3m0 12v3"/>',
    "device-laptop" => '<path d="M3 19l18 0"/><path d="M5 6m0 1a1 1 0 0 1 1 -1h12a1 1 0 0 1 1 1v8a1 1 0 0 1 -1 1h-12a1 1 0 0 1 -1 -1z"/>',
    "external-link" => '<path d="M12 6h-6a2 2 0 0 0 -2 2v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2 -2v-6"/><path d="M11 13l9 -9"/><path d="M15 4h5v5"/>',
    "trend-up" => '<path d="M3 17l6 -6l4 4l8 -8"/><path d="M14 7l7 0l0 7"/>',
    "sparkles" => '<path d="M12 3l1.5 5.5l5.5 1.5l-5.5 1.5l-1.5 5.5l-1.5 -5.5l-5.5 -1.5l5.5 -1.5z"/>'
  }.freeze

  def icon(name, size: 20, css_class: nil)
    path = ICON_PATHS[name.to_s] || ICON_PATHS["sparkles"]
    content_tag(:svg,
      path.html_safe,
      class: ["icon", css_class].compact.join(" "),
      width: size, height: size, viewBox: "0 0 24 24",
      fill: "none", stroke: "currentColor", "stroke-width": 1.8,
      "stroke-linecap": "round", "stroke-linejoin": "round",
      "aria-hidden": "true")
  end

  # A consistent brand colour + monogram for a tool that has no logo asset.
  def tool_monogram_color(name)
    palette = %w[#10a37f #4f8ef7 #7c4ef7 #e2574c #e8a020 #1a3a6e #d4537e #0f9d8f]
    palette[name.to_s.bytes.sum % palette.size]
  end

  # The tool's real favicon (the official brand mark), via Google's favicon
  # service. Returns nil when there's no website to derive it from.
  def tool_logo_url(tool, size: 128)
    return nil if tool.website_url.blank?

    host = URI.parse(tool.website_url).host rescue nil
    return nil if host.blank?

    "https://www.google.com/s2/favicons?domain=#{CGI.escape(host)}&sz=#{size}"
  end

  # A logo tile: the real favicon on top of a coloured monogram. If the favicon
  # fails to load it hides itself, revealing the monogram underneath.
  def tool_logo(tool, css_class: "tool-logo")
    letter = tool.name.to_s.strip.first.to_s.upcase
    content_tag(:span, class: css_class, style: "background: #{tool_monogram_color(tool.name)}") do
      monogram = content_tag(:span, letter, class: "tool-logo-mono")
      logo = if (url = tool_logo_url(tool))
        tag.img(src: url, alt: "#{tool.name} logo", loading: "lazy", class: "tool-logo-img",
                onerror: "this.style.display='none'")
      else
        "".html_safe
      end
      monogram + logo
    end
  end
end
