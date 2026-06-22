class RemovePlaceholderScoreData < ActiveRecord::Migration[7.1]
  TOOL_PLACEHOLDER_SCORE_FIELDS = %i[
    prompt_effort_score
    interface_score
    learning_curve_score
    data_retention_score
    training_on_user_data_score
    security_certifications_score
    privacy_controls_score
    enterprise_controls_score
    deployment_flexibility_score
    support_sla_score
  ].freeze

  MODEL_PLACEHOLDER_IMAGE_FIELDS = %i[
    image_quality_score
    prompt_adherence_score
    text_rendering_score
    image_editing_score
  ].freeze

  def up
    Tool.update_all(TOOL_PLACEHOLDER_SCORE_FIELDS.index_with(nil))
    ModelVariant.update_all(MODEL_PLACEHOLDER_IMAGE_FIELDS.index_with(nil))
    ModelVariant.where(transcription_score: 1).update_all(transcription_score: nil)
  end

  def down
    # Placeholder scores were intentionally removed.
  end
end
