# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_06_17_010000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "categories", force: :cascade do |t|
    t.string "slug", null: false
    t.string "display_name", null: false
    t.string "subtitle"
    t.string "icon"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_categories_on_position"
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.string "event_type", null: false
    t.text "search_query"
    t.jsonb "parsed_filters", default: {}, null: false
    t.jsonb "shown_tool_ids", default: [], null: false
    t.bigint "clicked_tool_id"
    t.datetime "created_at", null: false
    t.index ["clicked_tool_id"], name: "index_events_on_clicked_tool_id"
    t.index ["created_at"], name: "index_events_on_created_at"
    t.index ["event_type"], name: "index_events_on_event_type"
  end

  create_table "model_variants", force: :cascade do |t|
    t.bigint "tool_id", null: false
    t.string "name", null: false
    t.string "model_id_string"
    t.decimal "input_usd_per_m", precision: 12, scale: 4
    t.decimal "output_usd_per_m", precision: 12, scale: 4
    t.string "pricing_unit"
    t.integer "context_window"
    t.string "best_for"
    t.date "last_verified"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "score_text_generation"
    t.integer "score_email_writing"
    t.integer "score_logic"
    t.integer "score_coding"
    t.integer "score_image_generation"
    t.integer "score_accuracy"
    t.integer "score_write_edit"
    t.integer "score_summarization"
    t.integer "score_research_fact_check"
    t.integer "score_meetings_transcription"
    t.integer "score_coding_speed"
    t.integer "score_coding_efficiency"
    t.integer "score_hallucination_resistance"
    t.integer "score_source_quality"
    t.integer "score_consistency"
    t.integer "score_translation_speed"
    t.integer "score_translation_accuracy"
    t.boolean "free_to_try"
    t.integer "write_edit_score"
    t.integer "summarisation_score"
    t.integer "research_fact_checking_score"
    t.integer "source_quality_score"
    t.integer "hallucination_resistance_score"
    t.integer "deep_research_score"
    t.integer "coding_speed_score"
    t.integer "coding_accuracy_score"
    t.integer "debugging_score"
    t.integer "agentic_coding_score"
    t.integer "consistency_score"
    t.integer "reasoning_score"
    t.integer "image_quality_score"
    t.integer "prompt_adherence_score"
    t.integer "text_rendering_score"
    t.integer "image_editing_score"
    t.integer "transcription_score"
    t.integer "meeting_summary_score"
    t.integer "follow_up_score"
    t.integer "translation_accuracy_score"
    t.integer "translation_speed_score"
    t.index ["tool_id", "name"], name: "index_model_variants_on_tool_id_and_name", unique: true
    t.index ["tool_id"], name: "index_model_variants_on_tool_id"
  end

  create_table "posts", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.text "excerpt"
    t.text "body"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["published_at"], name: "index_posts_on_published_at"
    t.index ["slug"], name: "index_posts_on_slug", unique: true
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "tool_id", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.string "byline"
    t.integer "rating"
    t.text "body"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_reviews_on_slug", unique: true
    t.index ["tool_id"], name: "index_reviews_on_tool_id"
  end

  create_table "tool_categories", force: :cascade do |t|
    t.bigint "tool_id", null: false
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_tool_categories_on_category_id"
    t.index ["tool_id", "category_id"], name: "index_tool_categories_on_tool_id_and_category_id", unique: true
    t.index ["tool_id"], name: "index_tool_categories_on_tool_id"
  end

  create_table "tools", force: :cascade do |t|
    t.string "name", null: false
    t.string "provider"
    t.string "website_url"
    t.string "status", default: "live", null: false
    t.date "last_verified"
    t.string "data_pricing_confidence"
    t.decimal "input_usd_per_m", precision: 12, scale: 4
    t.decimal "output_usd_per_m", precision: 12, scale: 4
    t.string "pricing_unit"
    t.decimal "price_low_usd", precision: 12, scale: 2
    t.decimal "price_high_usd", precision: 12, scale: 2
    t.integer "context_window"
    t.boolean "api_free_tier", default: false, null: false
    t.boolean "consumer_free_app", default: false, null: false
    t.string "data_retention", default: "unclear", null: false
    t.boolean "runs_locally", default: false, null: false
    t.string "privacy_label"
    t.string "price_label"
    t.string "ease_label"
    t.text "why_this_one"
    t.integer "ease_score"
    t.text "raw_pricing_text"
    t.text "raw_privacy_text"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "privacy_score"
    t.integer "score_text_generation"
    t.integer "score_email_writing"
    t.integer "score_logic"
    t.integer "score_coding"
    t.integer "score_image_generation"
    t.integer "score_accuracy"
    t.integer "score_prompt_effort"
    t.integer "score_interface"
    t.integer "score_security_certifications"
    t.boolean "web_available"
    t.boolean "mobile_available"
    t.boolean "desktop_available"
    t.string "data_location"
    t.string "trains_on_user_data"
    t.string "retains_user_data"
    t.integer "prompt_effort_score"
    t.integer "interface_score"
    t.integer "learning_curve_score"
    t.integer "integration_score"
    t.integer "data_retention_score"
    t.integer "training_on_user_data_score"
    t.integer "security_certifications_score"
    t.integer "privacy_controls_score"
    t.integer "enterprise_controls_score"
    t.integer "deployment_flexibility_score"
    t.integer "support_sla_score"
    t.boolean "has_web_search"
    t.boolean "shows_citations"
    t.boolean "has_file_uploads"
    t.boolean "has_image_uploads"
    t.boolean "has_voice_mode"
    t.boolean "supports_model_selection"
    t.boolean "has_image_generation"
    t.boolean "has_image_editing"
    t.boolean "has_video_generation"
    t.boolean "has_audio_generation"
    t.boolean "has_presentation_generation"
    t.boolean "has_coding_agent"
    t.boolean "has_code_execution"
    t.boolean "has_repository_access"
    t.boolean "has_deep_research"
    t.boolean "has_live_data_access"
    t.boolean "has_transcription"
    t.boolean "has_meeting_bot"
    t.boolean "has_action_items"
    t.boolean "has_api"
    t.boolean "has_mobile_app"
    t.boolean "has_desktop_app"
    t.boolean "has_browser_extension"
    t.boolean "has_calendar_integration"
    t.boolean "has_email_integration"
    t.boolean "has_workspace_integration"
    t.boolean "has_free_plan"
    t.boolean "has_paid_plan"
    t.boolean "has_team_plan"
    t.boolean "has_enterprise_plan"
    t.boolean "supports_sso"
    t.boolean "supports_scim"
    t.boolean "has_audit_logs"
    t.boolean "has_admin_controls"
    t.boolean "has_soc2"
    t.boolean "has_iso27001"
    t.boolean "has_dpa"
    t.boolean "gdpr_ready"
    t.boolean "hipaa_eligible"
    t.boolean "no_training_on_user_data"
    t.boolean "configurable_data_retention"
    t.index ["consumer_free_app"], name: "index_tools_on_consumer_free_app"
    t.index ["data_retention"], name: "index_tools_on_data_retention"
    t.index ["name"], name: "index_tools_on_name", unique: true
    t.index ["runs_locally"], name: "index_tools_on_runs_locally"
    t.index ["status"], name: "index_tools_on_status"
  end

  add_foreign_key "events", "tools", column: "clicked_tool_id"
  add_foreign_key "model_variants", "tools"
  add_foreign_key "reviews", "tools"
  add_foreign_key "tool_categories", "categories"
  add_foreign_key "tool_categories", "tools"
end
