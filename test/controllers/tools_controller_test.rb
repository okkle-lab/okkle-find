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
    assert_select ".cat-bars[data-controller~='score-bars'][data-controller~='score-category-accordion']"
    assert_select ".cat-score-category"
    assert_select ".cat-score-category[open]", count: 0
    assert_select ".cat-score-category[data-score-category-accordion-target='item'][data-action='toggle->score-category-accordion#toggle']"
    assert_select "a.cat-bar-row[href='#{leaderboard_path("coding")}']", count: 0
    assert_select ".cat-bar-fill[data-score-bars-target='fill'][data-score-bars-key='coding'][data-score-bars-width='90']"
    assert_select ".cat-bar-name", "Coding"
    assert_select ".cat-bar-score", "9"
    assert_select ".cat-subcriterion[data-score-field='coding_speed_score'] .eval-crit-label", "Coding speed"
    assert_select ".cat-subcriterion[data-score-field='coding_accuracy_score'] .eval-crit-label", "Coding accuracy"
    assert_select ".cat-subcriterion[data-score-field='coding_speed_score'] .cat-subbar-fill[data-score-bars-key='coding-coding_speed_score'][data-score-bars-width='90']"
    assert_select ".cat-subcriterion[data-score-field='coding_accuracy_score'] .cat-subbar-fill[data-score-bars-key='coding-coding_accuracy_score'][data-score-bars-width='90']"
    assert_select ".cat-subcriterion .cat-subcriterion-notes", count: 0
    refute_includes response.body, "Producing correct, working code quickly for straightforward tasks."
    assert_select ".cat-bar-name", { text: "Ease of use", count: 0 }
    assert_select ".cat-bar-name", { text: "Image generation", count: 0 }
    assert_select ".cat-bar-name", { text: "Privacy", count: 0 }
    assert_select ".cat-bar-name", { text: "Enterprise", count: 0 }

    get tool_path(tool, model_variant: low.id)

    assert_response :success
    assert_select ".model-score-tab-active", "Low Model"
    assert_select ".cat-bar-name", "Coding"
    assert_select ".cat-bar-score", "5.2"
  end

  test "product page summarizes imported prompt grader notes for selected model category" do
    tool = Tool.create!(name: "Prompt Notes Tool", status: "live")
    selected = tool.model_variants.create!(
      name: "Selected Notes Model",
      position: 1,
      coding_speed_score: 8,
      coding_accuracy_score: 6
    )
    other = tool.model_variants.create!(
      name: "Other Notes Model",
      position: 2,
      coding_speed_score: 10,
      coding_accuracy_score: 10
    )
    selected.evaluation_notes.create!(
      test_id: "C1",
      category: "Coding",
      criterion: "Coding speed",
      score_field: "coding_speed_score",
      grader_model_key: "gpt-judge",
      grader_model_name: "GPT Judge",
      strengths: "Fast implementation with clear structure.",
      issues: "Missed one edge case."
    )
    selected.evaluation_notes.create!(
      test_id: "C2",
      category: "Coding",
      criterion: "Coding accuracy",
      score_field: "coding_accuracy_score",
      grader_model_key: "opus-judge",
      grader_model_name: "Claude Opus Judge",
      strengths: "Readable fix.",
      issues: "Needs stronger test coverage."
    )

    get tool_path(tool, model_variant: selected.id)

    assert_response :success
    assert_select ".cat-score-notes .eval-label", "Why it scored this way"
    assert_select ".cat-score-summary-copy", /We saw/
    assert_select ".cat-score-summary-copy", /strong coding speed/
    assert_select ".cat-score-summary-copy", /coding accuracy pulled the score down/
    assert_select ".cat-score-summary-copy", /edge-case reliability/
    assert_select ".cat-score-summary-copy", { text: /GPT and Opus notes/, count: 0 }
    assert_select ".cat-score-summary-copy", { text: /Other Notes Model/, count: 0 }
    assert_select ".cat-subcriterion .cat-subcriterion-notes", count: 0
    refute_includes response.body, "Fast implementation with clear structure"
    refute_includes response.body, "Needs stronger test coverage"
    refute_includes response.body, "Producing correct, working code quickly for straightforward tasks."
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

  test "product page separates transcription from meeting workflow scores" do
    tool = Tool.create!(name: "Split Meeting Tool", status: "live", integration_score: 10)
    tool.model_variants.create!(
      name: "Split Model",
      position: 1,
      transcription_score: 2,
      meeting_summary_score: 10,
      follow_up_score: 10
    )

    get tool_path(tool)

    assert_response :success
    assert_select ".cat-bar-name" do |elements|
      assert_equal ["Transcription", "Meetings"], elements.map { |element| element.text.strip }
    end
    scores_by_name = Nokogiri::HTML(response.body).css(".cat-bar-row").to_h do |row|
      [row.at_css(".cat-bar-name").text.strip, row.at_css(".cat-bar-score").text.strip]
    end
    assert_equal "2", scores_by_name.fetch("Transcription")
    assert_equal "10", scores_by_name.fetch("Meetings")
  end

  test "product page category summary follows visible mixed sub scores" do
    tool = Tool.create!(name: "Mixed Meeting Summary Tool", status: "live", integration_score: 4)
    variant = tool.model_variants.create!(
      name: "Mixed Meeting Model",
      position: 1,
      meeting_summary_score: 9,
      follow_up_score: 3
    )
    variant.evaluation_notes.create!(
      test_id: "M2",
      category: "Meetings",
      criterion: "Meeting summaries",
      score_field: "meeting_summary_score",
      grader_model_key: "meeting-judge",
      strengths: "Accurate and complete summary."
    )
    variant.evaluation_notes.create!(
      test_id: "M3",
      category: "Meetings",
      criterion: "Follow-up automation",
      score_field: "follow_up_score",
      grader_model_key: "meeting-judge",
      strengths: "Clear structure."
    )

    get tool_path(tool, model_variant: variant.id)

    assert_response :success
    assert_select ".cat-score-category" do |categories|
      meetings = categories.find { |node| node.at_css(".cat-bar-name")&.text&.strip == "Meetings" }
      assert meetings
      assert_includes meetings.at_css(".cat-score-summary-copy").text, "strong meeting summaries"
      assert_includes meetings.at_css(".cat-score-summary-copy").text, "follow-up automation and calendar & workspace integration pulled the score down"
      refute_includes meetings.at_css(".cat-score-summary-copy").text, "accurate, complete outputs"
    end
  end

  test "product page shows transcription as unable to test instead of a low placeholder score" do
    tool = Tool.create!(name: "Untested Transcription Tool", status: "live", integration_score: 10)
    tool.model_variants.create!(
      name: "Meeting Only Model",
      position: 1,
      transcription_score: nil,
      meeting_summary_score: 9,
      follow_up_score: 8
    )

    get tool_path(tool)

    assert_response :success
    assert_select ".cat-score-category-unavailable .cat-bar-name", "Transcription"
    assert_select ".cat-score-category-unavailable .cat-bar-score", "—"
    assert_select ".cat-score-category-unavailable .cat-score-summary-copy", "We were unable to test this functionality."
    assert_select ".cat-score-category-unavailable .cat-subcriterion[data-score-field='transcription_score'] .eval-crit-score", "—"
    assert_select ".cat-bar-name", "Meetings"
    assert_select ".cat-bar-score", { text: "1", count: 0 }
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
    assert_select ".cat-bar-name", count: Rubric.categories.size
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
    assert_select ".usage-bar-row[data-usage-metric-kind='time'][data-usage-metric-icon='stopwatch'][data-usage-metric-ratio='0.2']"
    assert_select ".usage-bar-row[data-usage-metric-kind='tokens'][data-usage-metric-icon='currency-dollar'][data-usage-metric-ratio='0.4']"
    assert_select ".usage-bar-fill[data-score-bars-target='fill'][data-score-bars-key='usage-time'][data-score-bars-width='20']"
    assert_select ".usage-bar-fill[data-score-bars-target='fill'][data-score-bars-key='usage-tokens'][data-score-bars-width='40']"
    assert_select ".usage-bar-ic svg.icon", count: 2
    assert_select ".usage-bar-name", "Avg time (in seconds)"
    assert_select ".usage-bar-name", "Avg tokens"
    assert_select ".usage-bar-row[data-usage-metric-kind='time'] .usage-bar-fill[style*='rgb(98, 179, 148)']"
    assert_select ".usage-bar-row[data-usage-metric-kind='tokens'] .usage-bar-fill[style*='rgb(237, 192, 102)']"
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
