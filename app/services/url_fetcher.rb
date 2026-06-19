require "open-uri"
require "nokogiri"

class UrlFetcher
  def self.call(url)
    uri = URI.parse(url)
    html = URI.open(url, "User-Agent" => "Mozilla/5.0 (compatible; AI-Finder)", read_timeout: 8).read
    doc  = Nokogiri::HTML(html)

    title = doc.at('meta[property="og:title"]')&.attr("content")&.strip ||
            doc.at("title")&.text&.strip

    description = doc.at('meta[property="og:description"]')&.attr("content")&.strip ||
                  doc.at('meta[name="description"]')&.attr("content")&.strip

    site_name = doc.at('meta[property="og:site_name"]')&.attr("content")&.strip ||
                uri.host.sub(/\Awww\./, "").split(".").first.capitalize

    image_url = doc.at('meta[property="og:image"]')&.attr("content")&.strip

    { title: title, description: description, site_name: site_name, image_url: image_url, url: url }
  rescue => e
    { error: e.message }
  end
end
