require "test_helper"

class CompareCandidatesTest < ActiveSupport::TestCase
  test "uses search results when context has other visible tools" do
    current = Tool.create!(name: "Current", status: "live")
    first = Tool.create!(name: "First", status: "live")
    second = Tool.create!(name: "Second", status: "live")
    hidden = Tool.create!(name: "Hidden", status: "dead")
    context = SearchContext.new(result_ids: [current.id, second.id, hidden.id, first.id])

    candidates = CompareCandidates.for(current, search_context: context)

    assert candidates.results?
    assert_equal [second, first], candidates.result_tools
    assert_equal [current.id, second.id, hidden.id, first.id].join(","), candidates.from_param
  end

  test "uses catalogue when context has no other visible result tools" do
    current = Tool.create!(name: "Current", status: "live")
    context = SearchContext.new

    candidates = CompareCandidates.for(current, search_context: context)

    assert candidates.catalogue?
  end

  test "catalogue suggestions use score-derived categories" do
    current = Tool.create!(name: "Current Research", status: "live")
    current.model_variants.create!(name: "v1", research_fact_checking_score: 9)
    similar = Tool.create!(name: "Similar Research", status: "live")
    similar.model_variants.create!(name: "v1", source_quality_score: 8)
    other = Tool.create!(name: "Other Coding", status: "live")
    other.model_variants.create!(name: "v1", coding_speed_score: 9)

    candidates = CompareCandidates.for(current, search_context: SearchContext.new)

    assert_equal [similar], candidates.similar_tools
    assert_includes candidates.other_tools, other
  end
end
