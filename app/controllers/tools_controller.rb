class ToolsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound do
    redirect_to root_path, alert: "We couldn't find that tool."
  end

  # Per-tool review: the complete score overview + our written review (if any).
  def review
    @tool   = Tool.find(params[:id])
    @review = @tool.display_review
    @search_context = SearchContext.from_params(params)
    @compare_candidates = CompareCandidates.for(@tool, search_context: @search_context)
    Event.record(event_type: "specs_expand", clicked_tool_id: @tool.id)
  end

  def show
    @tool = Tool.find(params[:id])
    Event.record(event_type: "specs_expand", clicked_tool_id: @tool.id)

    @search_context = SearchContext.from_params(params)

    # Search context carries why this tool was recommended and the result set
    # it came from. Direct visits have an empty context and show overall only.
    @priority_dimension = @search_context.priority_dimension
  end
end
