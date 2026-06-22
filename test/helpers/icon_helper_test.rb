require "test_helper"

class IconHelperTest < ActionView::TestCase
  include IconHelper

  test "whisper uses openai logo domain instead of github repository favicon" do
    tool = Tool.new(name: "Whisper", website_url: "https://github.com/openai/whisper")

    assert_includes tool_logo_url(tool), "domain=openai.com"
    refute_includes tool_logo_url(tool), "github.com"
  end

  test "tools without a logo override use their website domain" do
    tool = Tool.new(name: "Example", website_url: "https://example.com/products/demo")

    assert_includes tool_logo_url(tool), "domain=example.com"
  end
end
