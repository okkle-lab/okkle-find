require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  test "empty search shows overall best tools" do
    low = Tool.create!(name: "Empty Search Low", status: "live")
    low.model_variants.create!(name: "v1", coding_speed_score: 5, coding_accuracy_score: 5)

    high = Tool.create!(name: "Empty Search High", status: "live")
    high.model_variants.create!(name: "v1", coding_speed_score: 9, coding_accuracy_score: 9)

    get search_path, params: { q: "" }

    assert_response :success
    assert_select "h1.results-title", "Best AI overall"
    assert_operator response.body.index(high.name), :<, response.body.index(low.name)
  end

  test "empty overall search prefers broad performers over specialists" do
    specialist = Tool.create!(name: "Search Audio Specialist", status: "live")
    specialist.model_variants.create!(name: "v1", transcription_score: 10)
    generalist = create_broad_search_tool("Search Broad Generalist")

    get search_path, params: { q: "" }

    assert_response :success
    assert_select "h1.results-title", "Best AI overall"
    assert_operator response.body.index(generalist.name), :<, response.body.index(specialist.name)
  end

  private

  def create_broad_search_tool(name)
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
