# Stage 2 (hard filter) + Stage 3 (intent-based ranking) of the pipeline.
#
# The hard filter is strict and deterministic — it NEVER pads with tools that
# fail a stated must-have. Relevance always selects the result set first; the
# requested sort then reorders that same set. This keeps score/price sorting as
# a view preference instead of a different retrieval algorithm.
class ToolMatcher
  DEFAULT_COUNT = 5
  MIN_HEALTHY_POOL = 4
  SORTS = {
    "relevance" => "Relevance",
    "score" => "Score",
    "price" => "Price"
  }.freeze
  DEFAULT_SORT = "relevance"

  Result = Struct.new(:tools, :pool_size, :need, :used_keyword_fallback, keyword_init: true) do
    # True when we couldn't honestly fill a full lineup.
    def insufficient?
      tools.size < MIN_HEALTHY_POOL
    end
  end

  def initialize(need, count: DEFAULT_COUNT, sort: DEFAULT_SORT)
    @need  = need
    @count = count
    @sort = self.class.normalize_sort(sort)
  end

  def self.call(...) = new(...).call

  def self.normalize_sort(sort)
    sort = sort.to_s
    SORTS.key?(sort) ? sort : DEFAULT_SORT
  end

  def call
    pool = hard_filtered.to_a
    used_fallback = false

    # Last-resort keyword search — only when NO hard must-have was stated,
    # so we never surface a tool that violates a stated requirement.
    if pool.empty? && !@need.any_hard_flag? && @need.keywords.any?
      pool = keyword_search.to_a
      used_fallback = true
    end

    selected = ranked_by_relevance(pool).first(@count)

    Result.new(
      tools: ranked(selected),
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

  # Reorder an already relevance-selected result set.
  def ranked(tools)
    case @sort
    when "score"
      ranked_by_score(tools)
    when "price"
      ranked_by_price(tools)
    else
      ranked_by_relevance(tools)
    end
  end

  # Tools we've actually scored on the priority dimension come first (so a tool
  # with no score on it never outranks one that does), then by the 50/50
  # dimension+overall blend (see Tool#rank_score). Ties break randomly so
  # equally scored tools still rotate between searches. With no priority
  # dimension every tool is "unscored" and this is simply an overall-verdict
  # ranking.
  def ranked_by_relevance(tools)
    dimension = @need.priority_dimension
    tools.sort_by { |t| [t.scored_on?(dimension) ? 0 : 1, -t.rank_score(dimension), rand] }
  end

  def ranked_by_score(tools)
    tools.sort_by { |t| [-(t.overall_verdict || Tool::RANK_BASELINE), rand] }
  end

  def ranked_by_price(tools)
    tools.sort_by { |t| [t.sortable_price.infinite? ? 1 : 0, t.sortable_price, -t.rank_score(@need.priority_dimension), rand] }
  end
end
