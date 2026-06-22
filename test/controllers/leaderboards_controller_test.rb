require "test_helper"

class LeaderboardsControllerTest < ActionDispatch::IntegrationTest
  test "index hides experimental score categories while feature flag is off" do
    get leaderboards_path

    assert_response :success
    assert_select ".lb-card-name", { text: "Ease of use", count: 0 }
    assert_select ".lb-card-name", { text: "Image generation", count: 0 }
    assert_select ".lb-card-name", { text: "Privacy & data safety", count: 0 }
    assert_select ".lb-card-name", { text: "Enterprise", count: 0 }
    assert_select ".lb-card-name", "Efficiency"
  end

  test "index includes an efficiency leaderboard card with a model leader" do
    create_efficiency_fixture_models

    get leaderboards_path

    assert_response :success
    assert_select "a.lb-card[href='#{leaderboard_path("efficiency")}']" do
      assert_select ".lb-card-name", "Efficiency"
      assert_select ".lb-card-leader-name", /Efficiency Balanced Tool.*Balanced Model/
      assert_select ".lb-card-metric", /2\.0s \/ 300/
    end
  end

  test "efficiency leaderboard ranks visible model variants by latency and token usage" do
    create_efficiency_fixture_models

    get leaderboard_path("efficiency")

    assert_response :success
    assert_select "h1.page-title", "Efficiency"
    assert_select ".lb-row-efficiency", count: 3
    assert_select ".lb-row-efficiency:first-child .lb-row-name", "Efficiency Balanced Tool"
    assert_select ".lb-row-efficiency:first-child .lb-row-model", "Balanced Model"
    assert_select ".lb-row-efficiency:first-child .lb-eff-metric", /2\.0s/
    assert_select ".lb-row-efficiency:first-child .lb-eff-metric", /300 tokens/
    assert_select ".lb-row-efficiency:first-child .lb-row-cap", "eff."
    refute_includes response.body, "Hidden Model"
    refute_includes response.body, "Missing Tokens Model"
  end

  private

  def create_efficiency_fixture_models
    balanced = Tool.create!(name: "Efficiency Balanced Tool", status: "live")
    balanced.model_variants.create!(name: "Balanced Model", avg_latency_seconds: 2.0, avg_total_tokens: 300)

    fast = Tool.create!(name: "Efficiency Fast Tool", status: "live")
    fast.model_variants.create!(name: "Fast Verbose Model", avg_latency_seconds: 1.0, avg_total_tokens: 900)

    lean = Tool.create!(name: "Efficiency Lean Tool", status: "live")
    lean.model_variants.create!(name: "Slow Lean Model", avg_latency_seconds: 8.0, avg_total_tokens: 200)

    hidden = Tool.create!(name: "Efficiency Hidden Tool", status: "dead")
    hidden.model_variants.create!(name: "Hidden Model", avg_latency_seconds: 0.5, avg_total_tokens: 100)

    missing = Tool.create!(name: "Efficiency Missing Metric Tool", status: "live")
    missing.model_variants.create!(name: "Missing Tokens Model", avg_latency_seconds: 0.5)
  end
end
