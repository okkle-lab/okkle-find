require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "search card score flag defaults hidden" do
    refute search_card_score_visible?
  end

  test "search card score flag can be enabled" do
    original = Rails.configuration.x.search.show_card_score
    Rails.configuration.x.search.show_card_score = true

    assert search_card_score_visible?
  ensure
    Rails.configuration.x.search.show_card_score = original
  end
end
