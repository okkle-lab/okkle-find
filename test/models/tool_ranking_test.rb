require "test_helper"

# Unit tests for the intent-based ranking score (Tool#rank_score / #best_score).
# Records are built in memory — no DB or fixtures needed — so the focus stays
# on the scoring maths.
class ToolRankingTest < ActiveSupport::TestCase
  # A tool whose single variant scores 8 on coding and nothing else. Coding is
  # the only rated category, so its overall verdict works out to 8.0.
  def coding_tool
    tool = Tool.new(name: "Coder")
    tool.model_variants.build(name: "v1", coding_speed_score: 8, coding_accuracy_score: 8)
    tool
  end

  test "overall verdict comes from the best variant" do
    assert_equal 8.0, coding_tool.overall_verdict
  end

  test "rank_score with no dimension is just the overall verdict" do
    assert_equal 8.0, coding_tool.rank_score(nil)
  end

  test "rank_score with a scored dimension uses that dimension only" do
    tool = Tool.new(name: "Category First")
    tool.model_variants.build(name: "v1", write_edit_score: 2, coding_speed_score: 8, coding_accuracy_score: 8)

    assert_operator tool.overall_verdict, :<, 8.0
    assert_equal 8.0, tool.rank_score("coding")
  end

  test "rank_score uses the overall verdict (no baseline blend) for an unscored dimension" do
    # translation is unscored -> rank on overall only, NOT a faked baseline blend.
    assert_equal 8.0, coding_tool.rank_score("translation")
  end

  test "rank_score ignores an unknown dimension" do
    assert_equal coding_tool.overall_verdict, coding_tool.rank_score("not_a_real_dimension")
  end

  test "scored_on? reflects whether the dimension has a score" do
    assert coding_tool.scored_on?("coding")
    refute coding_tool.scored_on?("translation")
    refute coding_tool.scored_on?(nil)
  end

  test "score category slugs are derived from mapped score dimensions" do
    tool = Tool.new(name: "Dynamic Categories")
    tool.model_variants.build(name: "v1", research_fact_checking_score: 9, source_quality_score: 8)

    assert_includes tool.score_category_slugs, "research"
    refute_includes tool.score_category_slugs, "code"
  end

  test "score category slugs require a strong category score" do
    tool = Tool.new(name: "Measured But Weak")
    tool.model_variants.build(name: "v1", research_fact_checking_score: 6)

    refute_includes tool.score_category_slugs, "research"
  end

  test "priority dimensions are derived from the rubric metadata" do
    assert_equal Rubric::PRIORITY_DIMENSIONS, Tool::PRIORITY_DIMENSIONS
  end

  test "blank-score catalogue tools are treated as not yet tested" do
    tool = Tool.new(name: "Untested")

    refute tool.scored?
    assert_nil tool.overall_verdict
    assert_empty tool.verdict_best_for
    assert_empty tool.verdict_not_ideal_for
  end

  test "product overall scores are derived from product rubric fields" do
    tool = Tool.new(name: "Product Scores", prompt_effort_score: 7, interface_score: 8,
      security_certifications_score: 9)

    assert_equal [7, 8, 9], tool.product_overall_scores
  end

  test "overall verdict averages category scores rather than all raw scores" do
    tool = Tool.new(name: "Category Average",
      prompt_effort_score: 10,
      interface_score: 10,
      security_certifications_score: 4)
    tool.model_variants.build(name: "v1",
      write_edit_score: 8,
      summarisation_score: 6,
      coding_speed_score: 10,
      coding_accuracy_score: 6,
      hallucination_resistance_score: 5,
      source_quality_score: 7,
      consistency_score: 6,
      translation_speed_score: 9,
      translation_accuracy_score: 7)

    assert_in_delta 6.6, tool.overall_verdict, 0.05
  end

  test "best_score reads tool-only rubric columns" do
    tool = Tool.new(name: "Easy", prompt_effort_score: 7)
    assert_equal 7, tool.best_score(:prompt_effort_score)
  end

  test "best_score takes the best across variants" do
    tool = Tool.new(name: "Multi")
    tool.model_variants.build(name: "a", coding_speed_score: 6)
    tool.model_variants.build(name: "b", coding_speed_score: 9)
    assert_equal 9, tool.best_score(:coding_speed_score)
  end

  test "dimension_score averages composite rubric fields" do
    tool = Tool.new(name: "Composite")
    tool.model_variants.build(name: "a", coding_speed_score: 6, coding_accuracy_score: 8)

    assert_in_delta 7.2, tool.dimension_score("coding"), 0.05
  end

  test "mixed model and product dimensions require a model-level score" do
    tool = Tool.new(name: "Meeting Split", integration_score: 10)
    tool.model_variants.build(name: "empty")
    tool.model_variants.build(name: "summarizer", meeting_summary_score: 7, follow_up_score: 8)

    assert_in_delta 7.9, tool.dimension_score("meetings"), 0.05
  end

  test "trustworthiness includes truthful pushback" do
    assert_includes Rubric.fields_for("trustworthiness"), :truthful_pushback_score
    assert_equal 0.20, Rubric.weight_for("Accuracy & trustworthiness", :truthful_pushback_score)

    tool = Tool.new(name: "Pushback")
    tool.model_variants.build(name: "v1", hallucination_resistance_score: 10, truthful_pushback_score: 1)

    assert_in_delta 6.4, tool.dimension_score("trustworthiness"), 0.05
  end

  test "dimension_score uses the best model composite instead of mixing fields across models" do
    tool = Tool.new(name: "Composite Best")
    tool.model_variants.build(name: "fast", coding_speed_score: 10, coding_accuracy_score: 2)
    tool.model_variants.build(name: "efficient", coding_speed_score: 2, coding_accuracy_score: 10)

    assert_in_delta 6.7, tool.dimension_score("coding"), 0.05
  end

  test "a tool scored on the dimension outranks a higher-overall tool that isn't" do
    generalist = Tool.new(name: "Generalist") # overall 9, but NO translation score
    generalist.model_variants.build(name: "g", write_edit_score: 9,
      coding_speed_score: 9, coding_accuracy_score: 9, hallucination_resistance_score: 9)

    specialist = Tool.new(name: "Specialist") # lower overall, but scored on translation
    specialist.model_variants.build(name: "s", write_edit_score: 4,
      translation_speed_score: 9, translation_accuracy_score: 9)

    # Sanity: the generalist still wins on a plain overall ranking.
    assert_operator generalist.rank_score(nil), :>, specialist.rank_score(nil)

    # On a translation search the matcher tiers tools scored on translation first, so the
    # specialist outranks the generalist despite the generalist's higher overall.
    assert specialist.scored_on?("translation")
    refute generalist.scored_on?("translation")

    key = ->(t) { [t.scored_on?("translation") ? 0 : 1, -t.rank_score("translation")] }
    assert_equal [specialist, generalist], [generalist, specialist].sort_by(&key)
  end

  test "relevance ranking prefers the searched category score over overall score" do
    category_winner = Tool.new(name: "Category Winner")
    category_winner.model_variants.build(name: "cw", write_edit_score: 2,
      research_fact_checking_score: 9, source_quality_score: 9)
    overall_winner = Tool.new(name: "Overall Winner")
    overall_winner.model_variants.build(name: "ow", write_edit_score: 10,
      coding_speed_score: 10, coding_accuracy_score: 10, research_fact_checking_score: 7)

    assert_operator overall_winner.overall_verdict, :>, category_winner.overall_verdict
    assert_operator category_winner.rank_score("research"), :>, overall_winner.rank_score("research")

    matcher = ToolMatcher.new(ParsedNeed.new(priority_dimension: "research"))
    ranked = matcher.send(:ranked_by_relevance, [overall_winner, category_winner])

    assert_equal category_winner, ranked.first
  end

  test "tool matcher normalizes invalid sorts to relevance" do
    assert_equal "relevance", ToolMatcher.normalize_sort(nil)
    assert_equal "relevance", ToolMatcher.normalize_sort("not-real")
    assert_equal "score", ToolMatcher.normalize_sort("score")
  end

  test "score sort ranks by overall verdict" do
    low = Tool.new(name: "Low")
    low.model_variants.build(name: "v1", coding_speed_score: 5, coding_accuracy_score: 5)
    high = Tool.new(name: "High")
    high.model_variants.build(name: "v1", coding_speed_score: 8, coding_accuracy_score: 8)

    matcher = ToolMatcher.new(ParsedNeed.new(priority_dimension: "coding"), sort: "score")

    assert_equal [high, low], matcher.send(:ranked, [low, high])
  end

  test "price sort ranks free tools first and unknown prices last" do
    unknown = Tool.new(name: "Unknown")
    paid = Tool.new(name: "Paid", price_low_usd: 20)
    free = Tool.new(name: "Free", consumer_free_app: true)

    matcher = ToolMatcher.new(ParsedNeed.new(priority_dimension: "coding"), sort: "price")

    assert_equal [free, paid, unknown], matcher.send(:ranked, [unknown, paid, free])
  end

  test "non relevance sorts only reorder the relevance selected result set" do
    relevant_expensive = Tool.new(name: "Relevant Expensive", price_low_usd: 30)
    relevant_expensive.model_variants.build(name: "v1", coding_speed_score: 9, coding_accuracy_score: 9)
    relevant_cheap = Tool.new(name: "Relevant Cheap", price_low_usd: 5)
    relevant_cheap.model_variants.build(name: "v1", coding_speed_score: 8, coding_accuracy_score: 8)
    irrelevant_high_score = Tool.new(name: "Irrelevant High Score", price_low_usd: 1)
    irrelevant_high_score.model_variants.build(name: "v1", write_edit_score: 10)

    matcher = ToolMatcher.new(ParsedNeed.new(priority_dimension: "coding"), count: 2, sort: "price")
    matcher.define_singleton_method(:hard_filtered) do
      [irrelevant_high_score, relevant_cheap, relevant_expensive]
    end

    assert_equal [relevant_cheap, relevant_expensive], matcher.call.tools
  end
end
