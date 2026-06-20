class AddUsageMetricsToModelVariants < ActiveRecord::Migration[7.1]
  def change
    add_column :model_variants, :avg_latency_seconds, :decimal, precision: 8, scale: 3
    add_column :model_variants, :avg_total_tokens, :decimal, precision: 12, scale: 2
  end
end
