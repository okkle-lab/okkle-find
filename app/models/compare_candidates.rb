class CompareCandidates
  attr_reader :tool, :search_context

  def self.for(tool, search_context:)
    new(tool, search_context:)
  end

  def initialize(tool, search_context:)
    @tool = tool
    @search_context = search_context || SearchContext.new
  end

  def scope
    result_tools.any? ? :results : :catalogue
  end

  def results?
    scope == :results
  end

  def catalogue?
    scope == :catalogue
  end

  def from_param
    search_context.ids_param
  end

  def result_tools
    @result_tools ||= begin
      ids = search_context.result_ids_excluding(tool.id)
      by_id = Tool.visible.where(id: ids).index_by(&:id)
      ids.filter_map { |id| by_id[id] }
    end
  end

  def similar_tools
    @similar_tools ||= begin
      slugs = tool.score_category_slugs
      if slugs.empty?
        []
      else
        Tool.visible.includes(:model_variants).where.not(id: tool.id).select do |candidate|
          (candidate.score_category_slugs & slugs).any?
        end.sort_by(&:name)
      end
    end
  end

  def other_tools
    @other_tools ||= Tool.visible
                         .where.not(id: [tool.id, *similar_tools.map(&:id)])
                         .order(:name)
                         .to_a
  end

  def catalogue_options?
    similar_tools.any? || other_tools.any?
  end
end
