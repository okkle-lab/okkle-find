class LeaderboardsController < ApplicationController
  EfficiencyResult = Struct.new(:tool, :model_variant, :score, :latency_seconds, :total_tokens, keyword_init: true)
  EFFICIENCY_LEADERBOARD = {
    name: "Efficiency",
    key: "efficiency",
    icon: "stopwatch",
    description: "Quick responses with lean token usage — the models that move fast without sprawling.",
    kind: :efficiency
  }.freeze

  # Index: every rubric category with the top tool in each.
  def index
    @categories = Rubric.categories.map do |name, config|
      ranked = ranked_tools(name, config[:fields].keys)
      { name:, key: config[:key], icon: config[:icon], description: config[:description], leader: ranked.first, kind: :score }
    end
    @categories << EFFICIENCY_LEADERBOARD.merge(leader: ranked_model_efficiency.first)
  end

  # Show: full ranking for one category.
  def show
    return show_efficiency_leaderboard if params[:category] == EFFICIENCY_LEADERBOARD[:key]

    entry = Rubric.categories.find { |_name, config| config[:key] == params[:category] }
    return redirect_to(leaderboards_path) if entry.nil?

    @category_name, config = entry
    @category_key  = config[:key]
    @category_icon = config[:icon]
    @category_desc = config[:description]
    @fields        = config[:fields].keys
    @ranked        = ranked_tools(@category_name, @fields)
    @leaderboard_kind = :score
  end

  private

  def show_efficiency_leaderboard
    @category_name = EFFICIENCY_LEADERBOARD[:name]
    @category_key = EFFICIENCY_LEADERBOARD[:key]
    @category_icon = EFFICIENCY_LEADERBOARD[:icon]
    @category_desc = EFFICIENCY_LEADERBOARD[:description]
    @leaderboard_kind = :efficiency
    @ranked = ranked_model_efficiency
  end

  # Tools that have a score for this category, best first. Each row carries its
  # category score so the view can render it without recomputing.
  def ranked_tools(category_name, fields)
    Tool.visible.includes(:model_variants).filter_map do |tool|
      score = tool.comparison_category_score(fields)
      next if score.nil?

      [tool, score.round(1)]
    end.sort_by { |_tool, score| -score }
  end

  def ranked_model_efficiency
    rows = ModelVariant.joins(:tool)
      .merge(Tool.visible)
      .includes(:tool)
      .where.not(avg_latency_seconds: nil)
      .where.not(avg_total_tokens: nil)
      .map do |variant|
        EfficiencyResult.new(
          tool: variant.tool,
          model_variant: variant,
          latency_seconds: variant.avg_latency_seconds.to_f,
          total_tokens: variant.avg_total_tokens.to_f
        )
      end
    return [] if rows.empty?

    latency_range = rows.map(&:latency_seconds).minmax
    token_range = rows.map(&:total_tokens).minmax
    rows.each do |row|
      row.score = efficiency_score(row.latency_seconds, latency_range, row.total_tokens, token_range)
    end

    rows.sort_by { |row| [-row.score, row.latency_seconds, row.total_tokens, row.tool.name, row.model_variant.name] }
  end

  def efficiency_score(latency_seconds, latency_range, total_tokens, token_range)
    latency_score = inverse_normalized_score(latency_seconds, latency_range)
    token_score = inverse_normalized_score(total_tokens, token_range)

    (((latency_score + token_score) / 2.0) * 10.0).round(1)
  end

  def inverse_normalized_score(value, range)
    min, max = range
    return 1.0 if min == max

    1.0 - ((value - min) / (max - min)).clamp(0.0, 1.0)
  end
end
