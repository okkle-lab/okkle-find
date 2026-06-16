class AddUpdatedRubricScores < ActiveRecord::Migration[7.1]
  def change
    change_table :model_variants, bulk: true do |t|
      t.integer :score_write_edit
      t.integer :score_summarization
      t.integer :score_research_fact_check
      t.integer :score_meetings_transcription
      t.integer :score_coding_speed
      t.integer :score_coding_efficiency
      t.integer :score_hallucination_resistance
      t.integer :score_source_quality
      t.integer :score_consistency
      t.integer :score_translation_speed
      t.integer :score_translation_accuracy
      t.boolean :free_to_try
    end

    change_table :tools, bulk: true do |t|
      t.integer :score_prompt_effort
      t.integer :score_interface
      t.integer :score_security_certifications
      t.boolean :web_available
      t.boolean :mobile_available
      t.boolean :desktop_available
      t.string :data_location
      t.string :trains_on_user_data
      t.string :retains_user_data
    end
  end
end
