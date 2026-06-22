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

  test "top rated overall only shows broad generalist performers" do
    specialist = Tool.create!(name: "Homepage Audio Specialist", status: "live")
    specialist.model_variants.create!(name: "v1", transcription_score: 10)
    generalist = create_broad_homepage_tool("Homepage Broad Generalist")

    get root_path

    assert_response :success
    assert_select "h2.panel-title", "Top rated overall"
    assert_select ".top-name", /#{Regexp.escape(generalist.name)}/
    assert_select ".top-name .top-model", "v1"
    assert_select ".top-name", { text: specialist.name, count: 0 }
  end

  private

  def create_broad_homepage_tool(name)
    tool = Tool.create!(
      name: name,
      status: "live",
      prompt_effort_score: 8,
      interface_score: 8,
      learning_curve_score: 8
    )
    tool.model_variants.create!(
      name: "v1",
      write_edit_score: 8,
      summarisation_score: 8,
      research_fact_checking_score: 8,
      source_quality_score: 8,
      hallucination_resistance_score: 8,
      deep_research_score: 8,
      coding_speed_score: 8,
      coding_accuracy_score: 8,
      debugging_score: 8,
      agentic_coding_score: 8,
      consistency_score: 8,
      reasoning_score: 8,
      truthful_pushback_score: 8,
      image_quality_score: 8,
      prompt_adherence_score: 8,
      text_rendering_score: 8,
      image_editing_score: 8,
      translation_accuracy_score: 8,
      translation_speed_score: 8
    )
    tool
  end
end
