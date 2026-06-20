require "test_helper"

class ToolsControllerTest < ActionDispatch::IntegrationTest
  test "model score selector switches category scores" do
    tool = Tool.create!(name: "Selector Test Tool", status: "live")
    low = tool.model_variants.create!(
      name: "Low Model",
      position: 1,
      coding_speed_score: 4,
      coding_accuracy_score: 6
    )
    high = tool.model_variants.create!(
      name: "High Model",
      position: 2,
      coding_speed_score: 9,
      coding_accuracy_score: 9
    )

    get tool_path(tool)

    assert_response :success
    assert_select "turbo-frame#tool_scores"
    assert_select ".model-score-tab-active", "High Model"
    assert_select ".model-score-tabs[data-controller='model-score-tabs'][data-model-score-tabs-scope-value='#{tool.id}']"
    assert_select ".model-score-tab-indicator[data-model-score-tabs-target='indicator']"
    assert_select ".model-score-tab[data-model-score-tabs-target='tab']", count: 2
    assert_select ".model-score-tab", { text: "All models", count: 0 }
    assert_select ".model-score-tab", "Low Model"
    assert_select ".model-score-tab", "High Model"
    assert_select "a.model-score-tab[data-turbo-frame='tool_scores']", "Low Model"
    assert_select ".specs-title", { text: "How it scores", count: 0 }
    assert_select ".cat-breakdown-title", "How they perform"
    assert_select ".cat-breakdown-label-title", "Performance"
    assert_select ".cat-breakdown-label-sub", "Higher is better"
    assert_select ".take-hl-label", false
    assert_select ".cat-bars[data-controller='score-bars']"
    assert_select ".cat-bar-fill[data-score-bars-target='fill'][data-score-bars-key='coding'][data-score-bars-width='90']"
    assert_select ".cat-bar-name", "Coding"
    assert_select ".cat-bar-score", "9"

    get tool_path(tool, model_variant: low.id)

    assert_response :success
    assert_select ".model-score-tab-active", "Low Model"
    assert_select ".cat-bar-name", "Coding"
    assert_select ".cat-bar-score", "5.2"
  end

  test "product score categories keep rubric order instead of score rank" do
    tool = Tool.create!(name: "Stable Order Tool", status: "live")
    tool.model_variants.create!(
      name: "Mixed Model",
      position: 1,
      write_edit_score: 2,
      coding_speed_score: 9,
      coding_accuracy_score: 9
    )

    get tool_path(tool)

    assert_response :success
    assert_select ".cat-bar-name" do |elements|
      assert_equal ["Writing", "Coding"], elements.map { |element| element.text.strip }
    end
  end

  test "unscored selected model does not inherit product category scores" do
    tool = Tool.create!(
      name: "Unscored Variant Tool",
      status: "live",
      prompt_effort_score: 9,
      interface_score: 9,
      learning_curve_score: 9,
      data_retention_score: 8,
      training_on_user_data_score: 8,
      security_certifications_score: 8,
      privacy_controls_score: 8
    )
    unscored = tool.model_variants.create!(name: "Unavailable Model", position: 1)
    tool.model_variants.create!(
      name: "Scored Model",
      position: 2,
      write_edit_score: 8,
      avg_latency_seconds: 4.4,
      avg_total_tokens: 585
    )

    get tool_path(tool, model_variant: unscored.id)

    assert_response :success
    assert_select ".model-score-tab-active", "Unavailable Model"
    assert_select ".cat-breakdown-sub", false
    assert_select ".cat-bars-shell.cat-bars-shell-unavailable"
    assert_select ".cat-bars-shell-unavailable .cat-score-content[aria-hidden='true']"
    assert_select ".cat-bars-shell-unavailable .cat-breakdown-label-title", "Performance"
    assert_select ".cat-bars-shell-unavailable .usage-metrics-title", "Efficiency"
    assert_select ".cat-bars-overlay", "Scores currently unavailable"
    assert_select ".value-metrics", false
    assert_select ".usage-metrics-empty", false
    assert_select ".usage-metrics-list[data-controller='score-bars']"
    assert_select ".cat-bar-name"
    assert_select ".score-empty", false
  end

  test "unavailable model keeps full score backdrop when product has no scores" do
    tool = Tool.create!(name: "Fully Unscored Tool", status: "live")
    unscored = tool.model_variants.create!(name: "Unavailable Model", position: 1)

    get tool_path(tool, model_variant: unscored.id)

    assert_response :success
    assert_select ".cat-bars-shell.cat-bars-shell-unavailable"
    assert_select ".cat-bars-overlay", "Scores currently unavailable"
    assert_select ".cat-bar-name", count: Rubric::CATEGORIES.size
    assert_select ".score-empty", false
  end

  test "product page compares selected model usage averages under scores" do
    tool = Tool.create!(name: "Usage Metrics Tool", status: "live", price_low_usd: 20)
    fast = tool.model_variants.create!(
      name: "Fast Model",
      position: 1,
      coding_speed_score: 8,
      coding_accuracy_score: 8,
      input_usd_per_m: 1,
      output_usd_per_m: 3,
      avg_latency_seconds: 2.0,
      avg_total_tokens: 400
    )
    slow = tool.model_variants.create!(
      name: "Slow Model",
      position: 2,
      coding_speed_score: 9,
      coding_accuracy_score: 9,
      input_usd_per_m: 4,
      output_usd_per_m: 12,
      avg_latency_seconds: 8.0,
      avg_total_tokens: 800
    )

    get tool_path(tool, model_variant: fast.id)

    assert_response :success
    assert_operator response.body.index("cat-bars-shell"), :<, response.body.index('aria-label="Efficiency"')
    assert_operator response.body.index('aria-label="Efficiency"'), :<, response.body.index("cat-breakdown-foot")
    assert_select ".value-metrics", false
    assert_select ".usage-metrics"
    assert_select ".usage-metrics[aria-label='Efficiency']"
    assert_select ".usage-metrics-title", "Efficiency"
    assert_select ".usage-metrics-sub", "Lower is better"
    assert_select ".usage-metrics-list[data-controller='score-bars'][data-score-bars-scope-value='tool-usage-#{tool.id}'][data-usage-metric-model='#{fast.id}']"
    assert_select ".usage-metrics-list[data-usage-metric-model='#{slow.id}']", false
    assert_select ".usage-bar-row.cat-bar-row", count: 2
    assert_select ".usage-bar-row[data-usage-metric-kind='time'][data-usage-metric-icon='stopwatch'][data-usage-metric-ratio='0.1']"
    assert_select ".usage-bar-row[data-usage-metric-kind='tokens'][data-usage-metric-icon='currency-dollar'][data-usage-metric-ratio='0.8']"
    assert_select ".usage-bar-fill[data-score-bars-target='fill'][data-score-bars-key='usage-time'][data-score-bars-width='10']"
    assert_select ".usage-bar-fill[data-score-bars-target='fill'][data-score-bars-key='usage-tokens'][data-score-bars-width='80']"
    assert_select ".usage-bar-ic svg.icon", count: 2
    assert_select ".usage-bar-name", "Avg time (in seconds)"
    assert_select ".usage-bar-name", "Avg tokens"
    assert_select ".usage-bar-row[data-usage-metric-kind='time'] .usage-bar-fill[style*='rgb(153, 149, 159)']"
    assert_select ".usage-bar-row[data-usage-metric-kind='tokens'] .usage-bar-fill[style*='rgb(212, 137, 151)']"
    assert_select ".usage-bar-value", "2.0"
    assert_select ".usage-bar-value", "400"
    assert_select ".usage-bar-value", { text: "2.0s", count: 0 }
    assert_select ".usage-bar-value", { text: "400 tokens", count: 0 }
    assert_select ".usage-bar-value", { text: "8.0s", count: 0 }
    assert_select ".usage-bar-value", { text: "800 tokens", count: 0 }
  end

  test "product page shows value metrics when value flag is enabled" do
    original = Rails.configuration.x.features.model_value_metrics
    Rails.configuration.x.features.model_value_metrics = true

    tool = Tool.create!(name: "Value Metrics Tool", status: "live", price_low_usd: 20)
    fast = tool.model_variants.create!(
      name: "Fast Model",
      position: 1,
      coding_speed_score: 8,
      coding_accuracy_score: 8,
      input_usd_per_m: 1,
      output_usd_per_m: 3,
      avg_latency_seconds: 2.0,
      avg_total_tokens: 400
    )
    slow = tool.model_variants.create!(
      name: "Slow Model",
      position: 2,
      coding_speed_score: 9,
      coding_accuracy_score: 9,
      input_usd_per_m: 4,
      output_usd_per_m: 12,
      avg_latency_seconds: 8.0,
      avg_total_tokens: 800
    )

    get tool_path(tool, model_variant: fast.id)

    assert_response :success
    assert_operator response.body.index("cat-bars-shell"), :<, response.body.index("value-metrics")
    assert_operator response.body.index("value-metrics"), :<, response.body.index('aria-label="Efficiency"')
    assert_select ".value-metrics"
    assert_select ".value-metrics[aria-label='Value']"
    assert_select ".value-metrics-title", "Value"
    assert_select ".value-metrics-sub", "Higher is better"
    assert_select ".value-metrics-list[data-controller='score-bars'][data-score-bars-scope-value='tool-value-#{tool.id}'][data-value-metric-model='#{fast.id}']"
    assert_select ".value-metrics-list[data-value-metric-model='#{slow.id}']", false
    assert_select ".value-bar-row.cat-bar-row", count: 2
    assert_select ".value-bar-row[data-value-metric-kind='api'][data-value-metric-icon='currency-dollar'][data-value-metric-ratio='1.0']"
    assert_select ".value-bar-row[data-value-metric-kind='plan'][data-value-metric-icon='credit-card'][data-value-metric-ratio='0.889']"
    assert_select ".value-bar-fill[data-score-bars-target='fill'][data-score-bars-key='value-api'][data-score-bars-width='100']"
    assert_select ".value-bar-fill[data-score-bars-target='fill'][data-score-bars-key='value-plan'][data-score-bars-width='89']"
    assert_select ".value-bar-ic svg.icon", count: 2
    assert_select ".value-bar-name", "API performance per $"
    assert_select ".value-bar-name", "Plan performance per $"
    assert_select ".value-bar-value", "10k"
    assert_select ".value-bar-value", "0.40"
  ensure
    Rails.configuration.x.features.model_value_metrics = original
  end
end
