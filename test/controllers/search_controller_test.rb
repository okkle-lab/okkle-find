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
end
