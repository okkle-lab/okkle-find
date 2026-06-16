require "test_helper"

# Unit tests for the intent-based ranking score (Tool#rank_score / #best_score).
# Records are built in memory — no DB or fixtures needed — so the focus stays
# on the scoring maths.
class ToolRankingTest < ActiveSupport::TestCase
  # A tool whose single variant scores 8 on coding and nothing else.
  # Its overall verdict therefore works out to 8.0.
  def coding_tool
    tool = Tool.new(name: "Coder")
    tool.model_variants.build(name: "v1", score_coding: 8)
    tool
  end

  test "overall verdict comes from the best variant" do
    assert_equal 8.0, coding_tool.overall_verdict
  end

  test "rank_score with no dimension is just the overall verdict" do
    assert_equal 8.0, coding_tool.rank_score(nil)
  end

  test "rank_score blends the priority dimension 50/50 with the overall verdict" do
    # (coding 8 + overall 8) / 2
    assert_equal 8.0, coding_tool.rank_score("coding")
  end

  test "rank_score falls back to the baseline for an unscored dimension" do
    # image is unscored -> baseline 5; (5 + overall 8) / 2 = 6.5
    assert_equal 6.5, coding_tool.rank_score("image_generation")
  end

  test "rank_score ignores an unknown dimension" do
    assert_equal coding_tool.overall_verdict, coding_tool.rank_score("not_a_real_dimension")
  end

  test "best_score reads tool-only columns like ease_of_use" do
    tool = Tool.new(name: "Easy", ease_score: 7)
    assert_equal 7, tool.best_score(:ease_score)
  end

  test "best_score takes the best across variants" do
    tool = Tool.new(name: "Multi")
    tool.model_variants.build(name: "a", score_coding: 6)
    tool.model_variants.build(name: "b", score_coding: 9)
    assert_equal 9, tool.best_score(:score_coding)
  end

  test "a specialist can outrank a generalist on its dimension" do
    generalist = Tool.new(name: "Generalist") # overall 9, no image score
    generalist.model_variants.build(name: "g", score_text_generation: 9,
      score_logic: 9, score_coding: 9, score_accuracy: 9)

    specialist = Tool.new(name: "Specialist") # lower overall, strong image
    specialist.model_variants.build(name: "s", score_text_generation: 4,
      score_image_generation: 9)

    # On overall the generalist wins; on image the specialist's blend wins.
    assert_operator generalist.rank_score(nil), :>, specialist.rank_score(nil)
    assert_operator specialist.rank_score("image_generation"), :>,
      generalist.rank_score("image_generation")
  end
end
