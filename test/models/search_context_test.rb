require "test_helper"

class SearchContextTest < ActiveSupport::TestCase
  test "builds safe query params from result tools and need" do
    tools = [Tool.new(id: 3), Tool.new(id: 5)]
    need = ParsedNeed.new(priority_dimension: "coding")

    context = SearchContext.from_results(tools, need, sort: "score")

    assert_equal [3, 5], context.result_ids
    assert_equal "score", context.sort
    assert_equal({ from: "3,5", dim: "coding", sort: "score" }, context.query_params)
  end

  test "drops invalid dimensions and sorts" do
    context = SearchContext.from_params(from: "1,2", dim: "not-real", sort: "not-real")

    assert_equal [1, 2], context.result_ids
    assert_nil context.priority_dimension
    assert_equal "relevance", context.sort
    assert_equal({ from: "1,2" }, context.query_params)
  end

  test "omits default relevance sort from query params" do
    context = SearchContext.from_results([Tool.new(id: 1)], ParsedNeed.new(priority_dimension: "coding"))

    assert_equal "relevance", context.sort
    assert_equal({ from: "1", dim: "coding" }, context.query_params)
  end

  test "normalizes ids and removes blanks duplicates and zeros" do
    context = SearchContext.new(result_ids: "2,,0,3,2,nope")

    assert_equal [2, 3], context.result_ids
  end

  test "returns result ids excluding the current tool" do
    context = SearchContext.new(result_ids: "2,3,4")

    assert_equal [2, 4], context.result_ids_excluding(3)
  end
end
