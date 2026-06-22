class FeatureFlags
  def self.latest_in_ai?
    Rails.configuration.x.features.latest_in_ai == true
  end

  def self.model_value_metrics?
    Rails.configuration.x.features.model_value_metrics == true
  end

  def self.experimental_score_categories?
    Rails.configuration.x.features.experimental_score_categories == true
  end
end
