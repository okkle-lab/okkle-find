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

  test "latest in ai flag defaults hidden" do
    refute latest_in_ai_enabled?
  end

  test "latest in ai flag can be enabled" do
    original = Rails.configuration.x.features.latest_in_ai
    Rails.configuration.x.features.latest_in_ai = true

    assert latest_in_ai_enabled?
  ensure
    Rails.configuration.x.features.latest_in_ai = original
  end

  test "model value metrics flag defaults hidden" do
    refute model_value_metrics_enabled?
  end

  test "model value metrics flag can be enabled" do
    original = Rails.configuration.x.features.model_value_metrics
    Rails.configuration.x.features.model_value_metrics = true

    assert model_value_metrics_enabled?
  ensure
    Rails.configuration.x.features.model_value_metrics = original
  end
end
