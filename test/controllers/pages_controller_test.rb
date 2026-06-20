require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home header search starts hidden while hero search is observable" do
    get root_path

    assert_response :success
    assert_select ".search-form[data-header-search-sentinel]"
    assert_select ".header-search:not(.header-search--available)"
    assert_select ".header-search-button[aria-label='Search AI tools']"
  end

  test "non-home pages show the header search" do
    get learn_path

    assert_response :success
    assert_select ".header-search.header-search--available"
    assert_select ".header-search-input[placeholder='Search AI tools']"
    assert_select ".header-search-button[aria-label='Search AI tools']"
  end

  test "home hides latest in ai nav and section when flag is disabled" do
    original = Rails.configuration.x.features.latest_in_ai
    Rails.configuration.x.features.latest_in_ai = false
    Post.create!(title: "Hidden News Item", slug: "hidden-news-item", published_at: Time.current)

    get root_path

    assert_response :success
    assert_select "a.site-nav-link", text: "News", count: 0
    assert_select "h2.panel-title", text: "Latest in AI", count: 0
    refute_includes response.body, "Hidden News Item"
  ensure
    Rails.configuration.x.features.latest_in_ai = original
  end
end
