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
    assert_select ".model-score-tab-active", "All models"
    assert_select ".model-score-tab", "Low Model"
    assert_select ".model-score-tab", "High Model"
    assert_select "a.model-score-tab[data-turbo-frame='tool_scores']", "Low Model"
    assert_select ".take-hl-label", false
    assert_select ".cat-bar-name", "Coding"
    assert_select ".cat-bar-score", "9"

    get tool_path(tool, model_variant: low.id)

    assert_response :success
    assert_select ".model-score-tab-active", "Low Model"
    assert_select ".cat-bar-name", "Coding"
    assert_select ".cat-bar-score", "5.2"
  end
end
