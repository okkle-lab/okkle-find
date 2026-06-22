class SearchContext
  attr_reader :result_ids, :priority_dimension, :sort

  def self.from_results(tools, need, sort: ToolMatcher::DEFAULT_SORT)
    new(
      result_ids: Array(tools).map(&:id),
      priority_dimension: need&.priority_dimension,
      sort: sort
    )
  end

  def self.from_params(params)
    new(
      result_ids: param_value(params, :from),
      priority_dimension: param_value(params, :dim),
      sort: param_value(params, :sort)
    )
  end

  def initialize(result_ids: [], priority_dimension: nil, sort: ToolMatcher::DEFAULT_SORT)
    @result_ids = normalize_ids(result_ids)
    @priority_dimension = valid_priority_dimension(priority_dimension)
    @sort = ToolMatcher.normalize_sort(sort)
  end

  def ids_param
    result_ids.join(",")
  end

  def query_params
    {
      from: ids_param.presence,
      dim: priority_dimension,
      sort: sort == ToolMatcher::DEFAULT_SORT ? nil : sort
    }.compact
  end

  def result_ids_excluding(id)
    result_ids - [id.to_i]
  end

  def from_search?
    result_ids.any?
  end

  def self.param_value(params, key)
    return params[key] if params.respond_to?(:key?) && params.key?(key)
    return params[key.to_s] if params.respond_to?(:key?) && params.key?(key.to_s)

    nil
  end
  private_class_method :param_value

  private

  def normalize_ids(value)
    values =
      case value
      when String
        value.split(",")
      else
        Array(value)
      end

    values.map(&:to_i).reject(&:zero?).uniq
  end

  def valid_priority_dimension(value)
    dimension = value.to_s.presence
    Rubric.priority_dimensions.key?(dimension) ? dimension : nil
  end
end
