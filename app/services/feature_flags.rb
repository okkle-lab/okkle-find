class FeatureFlags
  def self.latest_in_ai?
    Rails.configuration.x.features.latest_in_ai == true
  end
end
