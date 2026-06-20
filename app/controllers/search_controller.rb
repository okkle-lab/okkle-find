class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @sort = ToolMatcher.normalize_sort(params[:sort])
    @category = Category.find_by(slug: params[:category]) if params[:category].present?

    @need =
      if params[:category].present?
        # Browse tile: already structured, skip the parser (and, later, the LLM).
        ParsedNeed.from_category(params[:category])
      elsif @query.present?
        # LLM parse (Claude Haiku); falls back to keyword parse on any failure.
        NeedParser.call(@query)
      else
        ParsedNeed.overall
      end

    return redirect_to(root_path) if @need.nil?

    @results_title = results_title
    @result = ToolMatcher.call(@need, sort: @sort)
    @tools  = @result.tools
    @search_context = SearchContext.from_results(@tools, @need, sort: @sort)

    Event.record(
      event_type:     "search",
      search_query:   @query.presence,
      parsed_filters: @need.to_h,
      shown_tool_ids: @tools.map(&:id)
    )
  end

  private

  def results_title
    return "Best AI overall" if @need.source == "default"

    if @query.present?
      "Tools for “#{@query}”"
    else
      "Tools to #{@category&.display_name || @need.categories.first&.tr("-", " ")}"
    end
  end
end
