class AddTruthfulPushbackScoreToModelVariants < ActiveRecord::Migration[7.1]
  def change
    add_column :model_variants, :truthful_pushback_score, :integer
  end
end
