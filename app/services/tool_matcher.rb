# Stage 2 (hard filter) + Stage 3 (intent-based ranking) of the pipeline.
#
# The hard filter is strict and deterministic — it NEVER pads with tools that
# fail a stated must-have. The surviving pool is then ranked by a 50/50 blend
# of the need's priority dimension and each tool's overall verdict.
class ToolMatcher
  DEFAULT_COUNT = 5
  MIN_HEALTHY_POOL = 4

  Result = Struct.new(:tools, :pool_size, :need, :used_keyword_fallback, keyword_init: true) do
    # True when we couldn't honestly fill a full lineup.
    def insufficient?
      tools.size < MIN_HEALTHY_POOL
    end
  end

  def initialize(need, count: DEFAULT_COUNT)
    @need  = need
    @count = count
  end

  def self.call(...) = new(...).call

  def call
    pool = hard_filtered.to_a
    used_fallback = false

    # Last-resort keyword search — only when NO hard must-have was stated,
    # so we never surface a tool that violates a stated requirement.
    if pool.empty? && !@need.any_hard_flag? && @need.keywords.any?
      pool = keyword_search.to_a
      used_fallback = true
    end

    Result.new(
      tools: ranked(pool).first(@count),
      pool_size: pool.size,
      need: @need,
      used_keyword_fallback: used_fallback
    )
  end

  private

  def hard_filtered
    scope = Tool.visible.includes(:reviews, :model_variants)
    scope = scope.free_app   if @need.must_be_free
    scope = scope.private_ok if @need.must_be_private
    scope = scope.local      if @need.must_run_locally

    if @need.budget_ceiling_usd_month && !@need.must_be_free
      # Keep free apps and anything within budget; don't drop token-priced
      # tools just because they lack a monthly price.
      scope = scope.where(
        "consumer_free_app = TRUE OR price_low_usd IS NULL OR price_low_usd <= ?",
        @need.budget_ceiling_usd_month
      )
    end

    if @need.categories.any?
      scope = scope.joins(:categories).where(categories: { slug: @need.categories }).distinct
    end

    scope
  end

  def keyword_search
    conditions = @need.keywords.each_index.map do |i|
      "(tools.name ILIKE :w#{i} OR tools.provider ILIKE :w#{i} " \
        "OR tools.why_this_one ILIKE :w#{i} OR categories.display_name ILIKE :w#{i})"
    end.join(" OR ")
    binds = @need.keywords.each_with_index.to_h { |w, i| [:"w#{i}", "%#{w}%"] }

    Tool.visible.includes(:reviews, :model_variants).left_joins(:categories).where(conditions, binds).distinct
  end

  # Rank the pool for the need's intent. Tools we've actually scored on the
  # priority dimension come first (so a tool with no score on it never outranks
  # one that does), then by the 50/50 dimension+overall blend (see
  # Tool#rank_score). Ties break randomly so equally scored tools still rotate
  # between searches. With no priority dimension every tool is "unscored" and
  # this is simply an overall-verdict ranking.
  def ranked(tools)
    dimension = @need.priority_dimension
    tools.sort_by { |t| [t.scored_on?(dimension) ? 0 : 1, -t.rank_score(dimension), rand] }
  end
end
