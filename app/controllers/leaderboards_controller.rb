class LeaderboardsController < ApplicationController
  # Index: every rubric category with the top tool in each.
  def index
    @categories = Rubric::CATEGORIES.map do |name, config|
      ranked = ranked_tools(name, config[:fields].keys)
      { name:, key: config[:key], leader: ranked.first }
    end
  end

  # Show: full ranking for one category.
  def show
    entry = Rubric::CATEGORIES.find { |_name, config| config[:key] == params[:category] }
    return redirect_to(leaderboards_path) if entry.nil?

    @category_name, config = entry
    @category_key = config[:key]
    @fields = config[:fields].keys
    @ranked = ranked_tools(@category_name, @fields)
  end

  private

  # Tools that have a score for this category, best first. Each row carries its
  # category score so the view can render it without recomputing.
  def ranked_tools(category_name, fields)
    Tool.visible.includes(:model_variants).filter_map do |tool|
      score = tool.comparison_category_score(fields)
      next if score.nil?

      [tool, score.round(1)]
    end.sort_by { |_tool, score| -score }
  end
end
