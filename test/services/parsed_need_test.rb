require "test_helper"

class ParsedNeedTest < ActiveSupport::TestCase
  test "overall need represents an empty search" do
    need = ParsedNeed.overall

    assert_equal "overall best AI", need.task
    assert_equal "default", need.source
    assert_empty need.categories
    assert_empty need.keywords
    assert_nil need.priority_dimension
  end

  test "infers coding intent from plain language development queries" do
    need = ParsedNeed.from_keywords("I need help fixing a Python bug")

    assert_equal "coding", need.priority_dimension
  end

  test "coding phrases beat generic writing words" do
    need = ParsedNeed.from_keywords("Can it write code and review JavaScript?")

    assert_equal "coding", need.priority_dimension
  end

  test "infers email intent instead of generic writing" do
    need = ParsedNeed.from_keywords("Please write email replies for customers")

    assert_equal "write_edit", need.priority_dimension
  end

  test "infers accuracy intent from research and citation queries" do
    need = ParsedNeed.from_keywords("Find trustworthy sources with citations")

    assert_equal "research", need.priority_dimension
  end

  test "infers transcription intent separately from meeting workflows" do
    need = ParsedNeed.from_keywords("transcribe meetings")

    assert_includes need.categories, "audio-to-text"
    assert_equal "transcription", need.priority_dimension
  end

  test "infers meeting workflow intent separately from transcription" do
    need = ParsedNeed.from_keywords("summarize meeting action items")

    assert_equal "meetings", need.priority_dimension
  end

  test "infers research intent from researching wording" do
    need = ParsedNeed.from_keywords("best researching models")

    assert_includes need.categories, "research"
    assert_equal "research", need.priority_dimension
  end

  test "infers privacy intent from data safety queries" do
    need = ParsedNeed.from_keywords("I need something private that does not keep my data")

    assert_equal "privacy", need.priority_dimension
  end

  test "keeps unknown intent nil so ranking falls back to overall score" do
    need = ParsedNeed.from_keywords("something nice for my team")

    assert_nil need.priority_dimension
  end

  test "keeps short model ids with digits as searchable keywords" do
    need = ParsedNeed.from_keywords("o1")

    assert_equal ["o1"], need.keywords
  end
end
