class ModelEvaluationNote < ApplicationRecord
  belongs_to :model_variant

  validates :model_variant, presence: true
end
