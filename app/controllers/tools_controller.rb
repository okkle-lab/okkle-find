class ToolsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do
    redirect_to root_path, alert: "We couldn't find that tool."
  end

  # Per-tool review: the complete score overview + our written review (if any).
  def review
    @tool   = Tool.find(params[:id])
    @review = @tool.display_review
    Event.record(event_type: "specs_expand", clicked_tool_id: @tool.id)
  end

  def show
    @tool = Tool.find(params[:id])
    Event.record(event_type: "specs_expand", clicked_tool_id: @tool.id)

    # `dim` carries the intent dimension this tool was ranked on, so the
    # scorecard can explain *why* the search surfaced it. Validated against the
    # known set; ignored if absent or unrecognised (e.g. a direct visit).
    @priority_dimension = params[:dim].to_s.presence
    @priority_dimension = nil unless Tool::PRIORITY_DIMENSIONS.key?(@priority_dimension)

    # `from` carries the IDs of the search results the user just saw, so the
    # "Compare with…" picker can be scoped to those recommendations.
    @from     = params[:from].to_s
    from_ids  = @from.split(",").map(&:to_i).reject(&:zero?) - [@tool.id]

    if from_ids.any?
      by_id          = Tool.visible.where(id: from_ids).index_by(&:id)
      @result_tools  = from_ids.filter_map { |id| by_id[id] } # preserve result order
      @compare_scope = :results
    else
      # No search context: fall back to same-category tools first, then the rest.
      @similar_tools = Tool.visible
                           .joins(:categories)
                           .where(categories: { id: @tool.category_ids })
                           .where.not(id: @tool.id)
                           .distinct.order(:name)
      @other_tools   = Tool.visible
                           .where.not(id: [@tool.id, *@similar_tools.map(&:id)])
                           .order(:name)
      @compare_scope = :catalogue
    end
  end
end
