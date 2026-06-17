class AddRubricV3ScoresAndCapabilities < ActiveRecord::Migration[7.1]
  def change
    change_table :model_variants, bulk: true do |t|
      t.integer :write_edit_score
      t.integer :summarisation_score
      t.integer :research_fact_checking_score
      t.integer :source_quality_score
      t.integer :hallucination_resistance_score
      t.integer :deep_research_score
      t.integer :coding_speed_score
      t.integer :coding_accuracy_score
      t.integer :debugging_score
      t.integer :agentic_coding_score
      t.integer :consistency_score
      t.integer :reasoning_score
      t.integer :image_quality_score
      t.integer :prompt_adherence_score
      t.integer :text_rendering_score
      t.integer :image_editing_score
      t.integer :transcription_score
      t.integer :meeting_summary_score
      t.integer :follow_up_score
      t.integer :translation_accuracy_score
      t.integer :translation_speed_score
    end

    change_table :tools, bulk: true do |t|
      t.integer :prompt_effort_score
      t.integer :interface_score
      t.integer :learning_curve_score
      t.integer :integration_score
      t.integer :data_retention_score
      t.integer :training_on_user_data_score
      t.integer :security_certifications_score
      t.integer :privacy_controls_score
      t.integer :enterprise_controls_score
      t.integer :deployment_flexibility_score
      t.integer :support_sla_score

      t.boolean :has_web_search
      t.boolean :shows_citations
      t.boolean :has_file_uploads
      t.boolean :has_image_uploads
      t.boolean :has_voice_mode
      t.boolean :supports_model_selection
      t.boolean :has_image_generation
      t.boolean :has_image_editing
      t.boolean :has_video_generation
      t.boolean :has_audio_generation
      t.boolean :has_presentation_generation
      t.boolean :has_coding_agent
      t.boolean :has_code_execution
      t.boolean :has_repository_access
      t.boolean :has_deep_research
      t.boolean :has_live_data_access
      t.boolean :has_transcription
      t.boolean :has_meeting_bot
      t.boolean :has_action_items
      t.boolean :has_api
      t.boolean :has_mobile_app
      t.boolean :has_desktop_app
      t.boolean :has_browser_extension
      t.boolean :has_calendar_integration
      t.boolean :has_email_integration
      t.boolean :has_workspace_integration
      t.boolean :has_free_plan
      t.boolean :has_paid_plan
      t.boolean :has_team_plan
      t.boolean :has_enterprise_plan
      t.boolean :supports_sso
      t.boolean :supports_scim
      t.boolean :has_audit_logs
      t.boolean :has_admin_controls
      t.boolean :has_soc2
      t.boolean :has_iso27001
      t.boolean :has_dpa
      t.boolean :gdpr_ready
      t.boolean :hipaa_eligible
      t.boolean :no_training_on_user_data
      t.boolean :configurable_data_retention
    end
  end
end
