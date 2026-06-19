require "test_helper"

class ToolMatcherTest < ActiveSupport::TestCase
  test "name-only searches narrow results to matching products" do
    match = Tool.create!(name: "NameNeedleGPT", status: "live")
    Tool.create!(name: "Unrelated Name Search Tool", status: "live")

    result = ToolMatcher.call(ParsedNeed.from_keywords("NameNeedleGPT"), count: 5)

    assert_equal [match], result.tools
    assert_equal 1, result.pool_size
  end

  test "model variant names return the parent product" do
    match = Tool.create!(name: "Variant Host Search", status: "live")
    match.model_variants.create!(name: "Claude Sonnet Needle", model_id_string: "claude-sonnet-needle")
    Tool.create!(name: "Unrelated Variant Search Tool", status: "live")

    result = ToolMatcher.call(ParsedNeed.from_keywords("Sonnet Needle"), count: 5)

    assert_equal [match], result.tools
  end

  test "multi-word name searches prefer records matching all terms" do
    github = Tool.create!(name: "SearchSpec GitHub Copilot", provider: "GitHub", status: "live")
    Tool.create!(name: "SearchSpec Microsoft Copilot", provider: "Microsoft", status: "live")

    result = ToolMatcher.call(ParsedNeed.from_keywords("SearchSpec GitHub Copilot"), count: 5)

    assert_equal [github], result.tools
  end

  test "model id strings are searchable including short ids with digits" do
    match = Tool.create!(name: "Short Model Id Host", status: "live")
    match.model_variants.create!(name: "Reasoning Mini", model_id_string: "o1-name-search")

    result = ToolMatcher.call(ParsedNeed.from_keywords("o1"), count: 5)

    assert_equal [match], result.tools
  end

  test "product name search can override inferred categories" do
    match = Tool.create!(name: "CategoryBypassNeedle", status: "live")
    Category.create!(slug: "research", display_name: "Research")

    result = ToolMatcher.call(ParsedNeed.from_keywords("CategoryBypassNeedle research"), count: 5)

    assert_equal [match], result.tools
  end

  test "category searches use score-derived membership" do
    research_match = Tool.create!(name: "Research Score No Static Tag", status: "live")
    research_match.model_variants.create!(name: "v1", research_fact_checking_score: 9)
    not_research = Tool.create!(name: "Coding Only", status: "live")
    not_research.model_variants.create!(name: "v1", coding_speed_score: 10, coding_accuracy_score: 10)

    result = ToolMatcher.call(ParsedNeed.from_category("research"), count: 5)

    assert_includes result.tools, research_match
    refute_includes result.tools, not_research
    assert_equal 1, result.pool_size
  end

  test "hard filters still constrain product name searches" do
    cloud = Tool.create!(name: "LocalFlagNeedle", status: "live", runs_locally: false)
    Tool.create!(name: "Local Alternative Name Search", status: "live", runs_locally: true)

    result = ToolMatcher.call(ParsedNeed.from_keywords("local LocalFlagNeedle"), count: 5)

    refute_includes result.tools, cloud
    assert result.tools.all?(&:runs_locally?)
  end
end
